package com.florian.whisper

import android.content.Context
import android.content.pm.ApplicationInfo
import IPtProxy.Controller
import IPtProxy.IPtProxy
import IPtProxy.OnTransportEvents
import java.io.File

/**
 * Pluggable transports (Snowflake, obfs4, meek) from IPtProxy, run in-process.
 * Each one listens on a local SOCKS port that Arti uses as an *unmanaged*
 * transport. IPtProxy must only ever have one Controller: this object owns it.
 */
object PluggableTransports {
    private var controller: Controller? = null

    private fun controller(context: Context): Controller =
        controller ?: run {
            val dir = File(context.cacheDir, "pt").apply { mkdirs() }
            // Logging off in release: PT logs can contain bridge addresses.
            val debuggable = context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
            IPtProxy.newController(dir.absolutePath, debuggable, false, "INFO", object : OnTransportEvents {
                override fun connected(name: String?) {}
                override fun error(name: String?, e: Exception?) {}
                override fun stopped(name: String?, e: Exception?) {}
            }).also { controller = it }
        }

    /**
     * Starts [transport] ("snowflake", "obfs4", "meek_lite") and returns its
     * local SOCKS port. For Snowflake, [params] carries the broker / fronts /
     * ICE servers from the bridge line.
     */
    fun start(context: Context, transport: String, params: Map<String, String>): Long {
        val c = controller(context)
        if (transport == IPtProxy.Snowflake) {
            params["url"]?.let { c.snowflakeBrokerUrl = it }
            params["fronts"]?.let { c.snowflakeFrontDomains = it }
            params["ice"]?.let { c.snowflakeIceServers = it }
            params["ampcache"]?.let { c.snowflakeAmpCacheUrl = it }
        }
        // Idempotent: Arti clients are long-lived and keep the port they were
        // configured with, so a running transport is never restarted.
        val running = c.port(transport)
        if (running > 0) return running
        c.start(transport, "")
        return c.port(transport)
    }

    fun stop(transport: String) {
        controller?.stop(transport)
    }
}
