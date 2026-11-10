import LibXray
import NetworkExtension

/// VPN-расширение Netro: iOS отдаёт utun, Xray читает его по дескриптору (xray.tun.fd).
final class PacketTunnelProvider: NEPacketTunnelProvider {

    /// Имя интерфейса utun (для счётчиков трафика) и путь к журналу ядра.
    private var ifName = ""
    private static let logPath = NSTemporaryDirectory() + "netro-xray.log"
    private var startNote = ""

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard
            let proto = protocolConfiguration as? NETunnelProviderProtocol,
            let raw = proto.providerConfiguration?["config"] as? String,
            var config = try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any]
        else {
            completionHandler(NetroError("Нет конфигурации"))
            return
        }

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.mtu = 1500
        let v4 = NEIPv4Settings(addresses: ["172.19.0.1"], subnetMasks: ["255.255.255.252"])
        v4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = v4
        let v6 = NEIPv6Settings(addresses: ["fdfe:dcba:9876::1"], networkPrefixLengths: [126])
        v6.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = v6
        let dns = proto.providerConfiguration?["dns"] as? String ?? "1.1.1.1"
        let dnsSettings = NEDNSSettings(servers: [dns])
        dnsSettings.matchDomains = [""]   // все DNS-запросы — через туннель
        settings.dnsSettings = dnsSettings

        // Журнал ядра — в файл, чтобы приложение могло показать его в «Диагностике».
        try? "".write(toFile: Self.logPath, atomically: true, encoding: .utf8)
        var log = config["log"] as? [String: Any] ?? [:]
        log["loglevel"] = "warning"
        log["error"] = Self.logPath
        config["log"] = log

        setTunnelNetworkSettings(settings) { [weak self] err in
            guard let self else { return }
            if let err { completionHandler(err); return }
            guard let fd = self.tunFd else {
                completionHandler(NetroError("Не найден TUN"))
                return
            }
            var env = config["env"] as? [String: Any] ?? [:]
            env["xray.tun.fd"] = String(fd)
            config["env"] = env
            guard
                let data = try? JSONSerialization.data(withJSONObject: config),
                let json = String(data: data, encoding: .utf8)
            else {
                completionHandler(NetroError("Ошибка конфигурации"))
                return
            }
            let res = Self.invoke("runXray", ["xrayJson": json])
            if res["success"] as? Bool == true {
                self.startNote = "ядро запущено, tun fd=\(fd) (\(self.ifName))"
                completionHandler(nil)
            } else {
                completionHandler(NetroError(res["error"] as? String ?? "Ядро не запустилось"))
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        _ = Self.invoke("stopXray", [:])
        completionHandler()
    }

    /// Сообщения от приложения: счётчики трафика и журнал ядра.
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        let (rx, tx) = Self.counters(ifName)
        var log = (try? String(contentsOfFile: Self.logPath, encoding: .utf8)) ?? ""
        if log.count > 6000 { log = String(log.suffix(6000)) }
        let out: [String: Any] = ["rx": rx, "tx": tx, "if": ifName, "note": startNote, "log": log]
        completionHandler?(try? JSONSerialization.data(withJSONObject: out))
    }

    /// Поиск дескриптора utun, который iOS выдала расширению.
    private var tunFd: Int32? {
        var buf = [CChar](repeating: 0, count: Int(IFNAMSIZ))
        let utun = "utun".utf8CString.dropLast()
        let fd = (0...1024).first { (fd: Int32) -> Bool in
            var len = socklen_t(buf.count)
            return getsockopt(fd, 2 /* SYSPROTO_CONTROL */, 2 /* UTUN_OPT_IFNAME */, &buf, &len) == 0
                && buf.starts(with: utun)
        }
        if fd != nil { ifName = String(cString: buf) }
        return fd
    }

    /// Байты интерфейса: ibytes — то, что ядро отдало устройству (скачано), obytes — отдано.
    private static func counters(_ name: String) -> (Int64, Int64) {
        guard !name.isEmpty else { return (0, 0) }
        var rx: Int64 = 0, tx: Int64 = 0
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return (0, 0) }
        defer { freeifaddrs(head) }
        var p: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = p {
            let ifa = cur.pointee
            if let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK),
               String(cString: ifa.ifa_name) == name, let raw = ifa.ifa_data {
                let d = raw.assumingMemoryBound(to: if_data.self).pointee
                rx = Int64(d.ifi_ibytes)
                tx = Int64(d.ifi_obytes)
            }
            p = ifa.ifa_next
        }
        return (rx, tx)
    }

    static func invoke(_ method: String, _ payload: [String: Any]) -> [String: Any] {
        let req: [String: Any] = ["apiVersion": 3, "method": method, "payload": payload]
        guard
            let data = try? JSONSerialization.data(withJSONObject: req),
            let s = String(data: data, encoding: .utf8)
        else { return ["success": false] }
        let out = LibXrayInvoke(s)
        return (try? JSONSerialization.jsonObject(with: Data(out.utf8)) as? [String: Any]) ?? ["success": false]
    }
}

struct NetroError: LocalizedError {
    let message: String
    init(_ m: String) { message = m }
    var errorDescription: String? { message }
}
