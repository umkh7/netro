import Flutter
import LibXray
import NetworkExtension

/// Мост Flutter ↔ ядро Xray и VPN-расширение NetroTunnel.
final class NetroCore: NSObject, FlutterStreamHandler {
  private static let tunnelBundleId = (Bundle.main.bundleIdentifier ?? "pro.netro.netro") + ".tunnel"
  private var sink: FlutterEventSink?
  private var manager: NETunnelProviderManager?
  private let io = DispatchQueue(label: "netro.core", qos: .userInitiated, attributes: .concurrent)

  static func register(with registrar: FlutterPluginRegistrar) {
    let core = NetroCore()
    let methods = FlutterMethodChannel(name: "netro/core", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(name: "netro/state", binaryMessenger: registrar.messenger())
    events.setStreamHandler(core)
    methods.setMethodCallHandler { call, result in core.handle(call, result) }
    objc_setAssociatedObject(registrar, "netro.core", core, .OBJC_ASSOCIATION_RETAIN)
    NotificationCenter.default.addObserver(
      core, selector: #selector(statusChanged), name: .NEVPNStatusDidChange, object: nil)
    core.loadManager { _ in core.emit() }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case "invoke":
      let req = call.arguments as? String ?? "{}"
      io.async {
        let out = LibXrayInvoke(req)
        DispatchQueue.main.async { result(out) }
      }
    case "start":
      let args = call.arguments as? [String: Any] ?? [:]
      let config = args["config"] as? String ?? "{}"
      let dns = args["dns"] as? String ?? "1.1.1.1"
      start(config: config, dns: dns, result)
    case "stop":
      manager?.connection.stopVPNTunnel()
      result(nil)
    case "state":
      result(stateName)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func loadManager(_ done: @escaping (NETunnelProviderManager?) -> Void) {
    NETunnelProviderManager.loadAllFromPreferences { [weak self] list, _ in
      let m = list?.first ?? NETunnelProviderManager()
      self?.manager = m
      done(m)
    }
  }

  private func start(config: String, dns: String, _ result: @escaping FlutterResult) {
    loadManager { [weak self] m in
      guard let self, let m else { result(FlutterError(code: "vpn", message: "VPN недоступен", details: nil)); return }
      let proto = NETunnelProviderProtocol()
      proto.providerBundleIdentifier = Self.tunnelBundleId
      proto.serverAddress = "Netro"
      proto.providerConfiguration = ["config": config, "dns": dns]
      m.protocolConfiguration = proto
      m.localizedDescription = "Netro"
      m.isEnabled = true
      m.saveToPreferences { err in
        if let err {
          DispatchQueue.main.async {
            result(FlutterError(code: "vpn", message: err.localizedDescription, details: nil))
          }
          return
        }
        m.loadFromPreferences { _ in
          do {
            try m.connection.startVPNTunnel()
            DispatchQueue.main.async { result(nil) }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "vpn", message: error.localizedDescription, details: nil))
            }
          }
        }
      }
    }
  }

  private var stateName: String {
    switch manager?.connection.status ?? .invalid {
    case .connected: return "on"
    case .connecting, .reasserting: return "connecting"
    default: return "off"
    }
  }

  @objc private func statusChanged() { emit() }

  private func emit() {
    DispatchQueue.main.async { self.sink?(self.stateName) }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    emit()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }
}
