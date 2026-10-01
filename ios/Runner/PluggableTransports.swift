import Foundation
import IPtProxy

/// Pluggable transports (Snowflake, obfs4, meek) from IPtProxy, run
/// in-process (iOS side of PluggableTransports.kt). Each one listens on a
/// local SOCKS port that Arti uses as an *unmanaged* transport. IPtProxy must
/// only ever have one Controller: this type owns it.
enum PluggableTransports {
  private static let lock = NSLock()
  private static var controller: IPtProxyController?

  private final class Events: NSObject, IPtProxyOnTransportEventsProtocol {
    func connected(_ name: String?) {}
    func error(_ name: String?, error: Error?) {}
    func stopped(_ name: String?, error: Error?) {}
  }

  private static func shared() throws -> IPtProxyController {
    if let controller { return controller }
    let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("pt", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    #if DEBUG
      let logging = true
    #else
      // PT logs can contain bridge addresses.
      let logging = false
    #endif
    guard let c = IPtProxyNewController(dir.path, logging, false, "INFO", Events()) else {
      throw NSError(domain: "whisper.pt", code: 1)
    }
    controller = c
    return c
  }

  /// Starts [transport] ("snowflake", "obfs4", "meek_lite") and returns its
  /// local SOCKS port. For Snowflake, [params] carries the broker / fronts /
  /// ICE servers from the bridge line.
  static func start(_ transport: String, params: [String: String]) throws -> Int {
    lock.lock()
    defer { lock.unlock() }
    let c = try shared()
    if transport == IPtProxySnowflake {
      if let url = params["url"] { c.snowflakeBrokerUrl = url }
      if let fronts = params["fronts"] { c.snowflakeFrontDomains = fronts }
      if let ice = params["ice"] { c.snowflakeIceServers = ice }
      if let amp = params["ampcache"] { c.snowflakeAmpCacheUrl = amp }
    }
    // Idempotent: Arti clients are long-lived and keep the port they were
    // configured with, so a running transport is never restarted.
    let running = c.port(transport)
    if running > 0 { return running }
    try c.start(transport, proxy: "")
    return c.port(transport)
  }

  static func stop(_ transport: String) {
    lock.lock()
    defer { lock.unlock() }
    controller?.stop(transport)
  }
}
