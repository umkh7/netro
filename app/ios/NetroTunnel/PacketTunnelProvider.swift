import LibXray
import NetworkExtension

/// VPN-расширение Netro: iOS отдаёт utun, Xray читает его по дескриптору (xray.tun.fd).
final class PacketTunnelProvider: NEPacketTunnelProvider {

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
        settings.dnsSettings = NEDNSSettings(servers: [dns])

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

    /// Поиск дескриптора utun, который iOS выдала расширению.
    private var tunFd: Int32? {
        var buf = [CChar](repeating: 0, count: Int(IFNAMSIZ))
        let utun = "utun".utf8CString.dropLast()
        return (0...1024).first { (fd: Int32) -> Bool in
            var len = socklen_t(buf.count)
            return getsockopt(fd, 2 /* SYSPROTO_CONTROL */, 2 /* UTUN_OPT_IFNAME */, &buf, &len) == 0
                && buf.starts(with: utun)
        }
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
