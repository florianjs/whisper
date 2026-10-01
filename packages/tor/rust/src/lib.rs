// SPDX-FileCopyrightText: 2023 Foundation Devices Inc.
// SPDX-FileCopyrightText: 2024 Foundation Devices Inc.
//
// SPDX-License-Identifier: MIT

use crate::error::update_last_error;
use arti::proxy;
use arti_client::config::CfgPath;
use arti_client::config::pt::TransportConfigBuilder;
use arti_client::config::{BridgeConfigBuilder, PtTransportName};
use arti_client::{DormantMode, TorClient, TorClientConfig};
use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::Mutex;
use std::time::Duration;
use lazy_static::lazy_static;
use std::ffi::{c_char, c_void, CStr};
use std::{io, ptr};
use tokio::runtime::{Builder, Runtime};
use tokio::task::JoinHandle;
use tor_config::Listen;
use tor_rtcompat::tokio::TokioNativeTlsRuntime;
use tor_rtcompat::ToplevelBlockOn;

pub use crate::error::tor_last_error_message;
#[cfg(not(target_os = "windows"))]
pub use crate::util::tor_get_nofile_limit;
#[cfg(not(target_os = "windows"))]
pub use crate::util::tor_set_nofile_limit;

#[macro_use]
mod error;
mod util;

lazy_static! {
    static ref RUNTIME: io::Result<Runtime> = Builder::new_multi_thread().enable_all().build();
    /// Whisper: one client per state dir, kept for the process lifetime.
    /// Dropping a TorClient doesn't stop its background tasks (they hold
    /// clones), so it would keep the state-dir lock and the next client on
    /// that dir would fail. Instead clients are parked (dormant) and reused.
    static ref CLIENTS: Mutex<HashMap<String, TorClient<TokioNativeTlsRuntime>>> =
        Mutex::new(HashMap::new());
}

#[repr(C)]
pub struct Tor {
    client: *mut c_void,
    proxy: *mut c_void,
}

#[no_mangle]
pub unsafe extern "C" fn tor_start(
    socks_port: u16,
    state_dir: *const c_char,
    cache_dir: *const c_char,
) -> Tor {
    let err_ret = Tor {
        client: ptr::null_mut(),
        proxy: ptr::null_mut(),
    };

    let state_dir = unwrap_or_return!(CStr::from_ptr(state_dir).to_str(), err_ret);
    let cache_dir = unwrap_or_return!(CStr::from_ptr(cache_dir).to_str(), err_ret);

    let runtime = unwrap_or_return!(TokioNativeTlsRuntime::create(), err_ret);

    let mut cfg_builder = TorClientConfig::builder();
    cfg_builder
        .storage()
        .state_dir(CfgPath::new(state_dir.to_owned()))
        .cache_dir(CfgPath::new(cache_dir.to_owned()));
    cfg_builder.address_filter().allow_onion_addrs(true);
    cfg_builder
        .preemptive_circuits()
        .disable_at_threshold(1)
        .min_exit_circs_for_port(1)
        .initial_predicted_ports()
        .clear();

    let cfg = unwrap_or_return!(cfg_builder.build(), err_ret);

    let client = unwrap_or_return!(
        runtime.block_on(async {
            TorClient::with_runtime(runtime.clone())
                .config(cfg)
                .create_bootstrapped()
                .await
        }),
        err_ret
    );

    let proxy_handle_box = Box::new(start_proxy(socks_port, client.clone()));
    let client_box = Box::new(client.clone());

    Tor {
        client: Box::into_raw(client_box) as *mut c_void,
        proxy: Box::into_raw(proxy_handle_box) as *mut c_void,
    }
}

/// Whisper: starts Tor with an optional bridge configuration and a bounded
/// bootstrap. Unlike [tor_start], it never blocks forever on a censored
/// network: after `timeout_secs` it gives up (and frees everything), so the
/// caller can try the next rung of its ladder.
///
/// - `bridges`: bridge lines separated by '\n'; empty for a direct Tor start.
/// - `pt_protocol` / `pt_proxy`: an *unmanaged* pluggable transport already
///   listening locally (e.g. "snowflake" / "127.0.0.1:41234", run by
///   IPtProxy); empty when the bridges need none.
#[no_mangle]
pub unsafe extern "C" fn tor_start_with(
    socks_port: u16,
    state_dir: *const c_char,
    cache_dir: *const c_char,
    bridges: *const c_char,
    pt_protocol: *const c_char,
    pt_proxy: *const c_char,
    timeout_secs: u32,
) -> Tor {
    let err_ret = Tor {
        client: ptr::null_mut(),
        proxy: ptr::null_mut(),
    };

    let state_dir = unwrap_or_return!(CStr::from_ptr(state_dir).to_str(), err_ret);
    let cache_dir = unwrap_or_return!(CStr::from_ptr(cache_dir).to_str(), err_ret);
    let bridges = unwrap_or_return!(CStr::from_ptr(bridges).to_str(), err_ret);
    let pt_protocol = unwrap_or_return!(CStr::from_ptr(pt_protocol).to_str(), err_ret);
    let pt_proxy = unwrap_or_return!(CStr::from_ptr(pt_proxy).to_str(), err_ret);

    let mut cfg_builder = TorClientConfig::builder();
    cfg_builder
        .storage()
        .state_dir(CfgPath::new(state_dir.to_owned()))
        .cache_dir(CfgPath::new(cache_dir.to_owned()));
    cfg_builder.address_filter().allow_onion_addrs(true);
    cfg_builder
        .preemptive_circuits()
        .disable_at_threshold(1)
        .min_exit_circs_for_port(1)
        .initial_predicted_ports()
        .clear();

    for line in bridges.lines().map(str::trim).filter(|l| !l.is_empty()) {
        let bridge = unwrap_or_return!(line.parse::<BridgeConfigBuilder>(), err_ret);
        cfg_builder.bridges().bridges().push(bridge);
    }
    if !pt_protocol.is_empty() {
        let mut transport = TransportConfigBuilder::default();
        let name = unwrap_or_return!(pt_protocol.parse::<PtTransportName>(), err_ret);
        let addr = unwrap_or_return!(pt_proxy.parse::<SocketAddr>(), err_ret);
        transport.protocols(vec![name]).proxy_addr(addr);
        cfg_builder.bridges().transports().push(transport);
    }

    let cfg = unwrap_or_return!(cfg_builder.build(), err_ret);

    let existing = CLIENTS.lock().unwrap().get(state_dir).cloned();
    let client = match existing {
        Some(client) => {
            // Same rung again: wake it and apply the (possibly new PT port)
            // configuration.
            client.set_dormant(DormantMode::Normal);
            unwrap_or_return!(
                client.reconfigure(&cfg, arti_client::config::Reconfigure::WarnOnFailures),
                err_ret
            );
            client
        }
        None => {
            let runtime = unwrap_or_return!(TokioNativeTlsRuntime::create(), err_ret);
            let client = unwrap_or_return!(
                TorClient::with_runtime(runtime)
                    .config(cfg)
                    .create_unbootstrapped(),
                err_ret
            );
            CLIENTS
                .lock()
                .unwrap()
                .insert(state_dir.to_owned(), client.clone());
            client
        }
    };

    let bootstrapped = client.runtime().block_on(async {
        tokio::time::timeout(
            Duration::from_secs(u64::from(timeout_secs)),
            client.bootstrap(),
        )
        .await
    });
    let failed = match bootstrapped {
        Ok(Ok(())) => None,
        Ok(Err(e)) => Some(e.to_string()),
        Err(_) => Some("bootstrap timed out".to_owned()),
    };
    if let Some(reason) = failed {
        // Plain Tor: park it, so no recognisable Tor traffic continues once
        // the caller has moved on to a disguised rung. Disguised rungs keep
        // bootstrapping in the background (their traffic is disguised):
        // a slow first Snowflake bootstrap then finishes on the next try.
        if bridges.trim().is_empty() {
            client.set_dormant(DormantMode::Soft);
        }
        update_last_error(io::Error::other(reason));
        return err_ret;
    }

    let proxy_handle_box = Box::new(start_proxy(socks_port, client.clone()));
    let client_box = Box::new(client.clone());

    Tor {
        client: Box::into_raw(client_box) as *mut c_void,
        proxy: Box::into_raw(proxy_handle_box) as *mut c_void,
    }
}

/// Releases a handle returned by [tor_start_with] (after [tor_proxy_stop]).
/// The client itself stays registered, dormant, for reuse.
#[no_mangle]
pub unsafe extern "C" fn tor_client_free(client: *mut c_void) {
    if client.is_null() {
        return;
    }
    let client = Box::from_raw(client as *mut TorClient<TokioNativeTlsRuntime>);
    client.set_dormant(DormantMode::Soft);
}

#[no_mangle]
pub unsafe extern "C" fn tor_client_bootstrap(client: *mut c_void) -> bool {
    // Return false if client is null (not started)
    if client.is_null() {
        return false;
    }

    let client = Box::from_raw(client as *mut TorClient<TokioNativeTlsRuntime>);

    unwrap_or_return!(client.runtime().block_on(client.bootstrap()), false);
    true
}

#[no_mangle]
pub unsafe extern "C" fn tor_client_set_dormant(client: *mut c_void, soft_mode: bool) {
    // Return early if client is null (not started)
    if client.is_null() {
        return;
    }

    let client = Box::from_raw(client as *mut TorClient<TokioNativeTlsRuntime>);

    let dormant_mode = if soft_mode {
        DormantMode::Soft
    } else {
        DormantMode::Normal
    };
    client.set_dormant(dormant_mode);
    Box::leak(client);
}

#[no_mangle]
pub unsafe extern "C" fn tor_proxy_stop(proxy: *mut c_void) {
    // Return early if proxy is null (already stopped or never started)
    if proxy.is_null() {
        return;
    }

    let proxy = Box::from_raw(proxy as *mut JoinHandle<anyhow::Result<()>>);
    proxy.abort();
}

fn start_proxy(
    port: u16,
    client: TorClient<TokioNativeTlsRuntime>,
) -> JoinHandle<anyhow::Result<()>> {
    println!("Starting proxy!");
    let rt = RUNTIME.as_ref().unwrap();
    rt.spawn(proxy::run_proxy(
        client.runtime().clone(),
        client.clone(),
        Listen::new_localhost(port),
        None,
    ))
}

// Due to its simple signature this dummy function is the one added (unused) to iOS swift codebase to force Xcode to link the lib
#[no_mangle]
pub unsafe extern "C" fn tor_hello() {
    println!("HELLO THERE");
}
