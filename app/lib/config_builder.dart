import 'dart:io' show Platform;

import 'core.dart';
import 'models.dart';

const socksPort = 10808;
const httpPort = 10809;

const _privateNets = [
  '10.0.0.0/8',
  '172.16.0.0/12',
  '192.168.0.0/16',
  '127.0.0.0/8',
  '169.254.0.0/16',
  '100.64.0.0/10',
  'fc00::/7',
  'fe80::/10',
];

/// Полный конфиг Xray для выбранного сервера.
/// TUN-режим: inbound «tun» (fd добавляет Android/iOS), плюс локальные SOCKS/HTTP.
/// Прокси-режим: только локальные SOCKS/HTTP (на Windows — системный прокси).
Map<String, dynamic> buildXrayConfig(Server server, ConnMode mode) {
  final proxy = Map<String, dynamic>.from(server.outbound)..['tag'] = 'proxy';
  final sniff = {
    'enabled': true,
    'destOverride': ['http', 'tls', 'quic'],
    'routeOnly': true,
  };
  return {
    'log': {'loglevel': 'warning'},
    'stats': {},
    'policy': {
      'system': {'statsOutboundUplink': true, 'statsOutboundDownlink': true},
    },
    'metrics': {'listen': '127.0.0.1:${Core.metricsPort}'},
    'inbounds': [
      if (mode == ConnMode.tun)
        {
          'tag': 'tun',
          'protocol': 'tun',
          'settings': Platform.isWindows
              ? {
                  'name': 'Netro',
                  'mtu': 1500,
                  'gateway': ['172.19.0.1/30', 'fdfe:dcba:9876::1/126'],
                  'dns': ['1.1.1.1'],
                  'autoSystemRoutingTable': ['0.0.0.0/0', '::/0'],
                  'autoSystemWfpBlockLeak': ['dns', 'misconfigtun'],
                }
              : {'mtu': 1500},
          'sniffing': sniff,
        },
      {
        'tag': 'socks',
        'listen': '127.0.0.1',
        'port': socksPort,
        'protocol': 'socks',
        'settings': {'udp': true},
        'sniffing': sniff,
      },
      {
        'tag': 'http',
        'listen': '127.0.0.1',
        'port': httpPort,
        'protocol': 'http',
        'sniffing': sniff,
      },
    ],
    'outbounds': [
      proxy,
      {'tag': 'direct', 'protocol': 'freedom'},
      {'tag': 'block', 'protocol': 'blackhole'},
    ],
    'routing': {
      'domainStrategy': 'AsIs',
      'rules': [
        {'type': 'field', 'ip': _privateNets, 'outboundTag': 'direct'},
      ],
    },
  };
}

/// «VLESS · Reality», «Trojan · TLS», «VMess · WebSocket».
String protocolLabel(Map<String, dynamic> ob) {
  final p = (ob['protocol'] as String? ?? '').toLowerCase();
  final name = switch (p) {
    'vless' => 'VLESS',
    'vmess' => 'VMess',
    'trojan' => 'Trojan',
    'shadowsocks' => 'Shadowsocks',
    'hysteria' || 'hysteria2' => 'Hysteria2',
    'socks' => 'SOCKS',
    'wireguard' => 'WireGuard',
    _ => p.toUpperCase(),
  };
  final ss = (ob['streamSettings'] as Map?) ?? {};
  final sec = (ss['security'] as String? ?? '').toLowerCase();
  final net = (ss['network'] as String? ?? '').toLowerCase();
  final netName = switch (net) {
    'ws' || 'websocket' => 'WebSocket',
    'grpc' || 'gun' => 'gRPC',
    'xhttp' || 'splithttp' => 'XHTTP',
    'httpupgrade' => 'HTTPUpgrade',
    'kcp' || 'mkcp' => 'mKCP',
    _ => '',
  };
  if (sec == 'reality') return '$name · Reality';
  if (netName.isNotEmpty) return '$name · $netName';
  if (sec == 'tls') return '$name · TLS';
  return name;
}
