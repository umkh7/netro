// Дополнительные форматы, которые libXray не понимает сам:
// WireGuard (ссылки и .conf), подписки Clash/Mihomo (YAML) и sing-box (JSON), socks5://.
// Всё приводится либо к стандартным ссылкам (их разбирает libXray), либо сразу к outbound Xray.
import 'dart:convert';

import 'package:yaml/yaml.dart';

class Prepared {
  final String links; // ссылки построчно — для libXray
  final List<Map<String, dynamic>>
  outbounds; // готовые outbound (WireGuard и т.п.)
  final int
  skipped; // протоколы, которых нет в ядре Xray (TUIC, Naive, AnyTLS…)
  Prepared(this.links, this.outbounds, this.skipped);
}

String _q(Map<String, String> m) => m.entries
    .where((e) => e.value.isNotEmpty)
    .map(
      (e) =>
          '${e.key}=${Uri.encodeQueryComponent(e.value).replaceAll('+', '%20')}',
    )
    .join('&');

String _host(String h) => h.contains(':') && !h.startsWith('[') ? '[$h]' : h;

String _s(dynamic v) => v == null ? '' : '$v';

Prepared prepare(String text) {
  final t = text.trim();
  // WireGuard .conf
  if (t.contains('[Interface]') && t.contains('[Peer]')) {
    final ob = _wgConf(t);
    return Prepared('', ob == null ? [] : [ob], ob == null ? 1 : 0);
  }
  // sing-box / Xray JSON
  if (t.startsWith('{') || t.startsWith('[')) {
    try {
      final j = jsonDecode(t);
      final obs = j is Map ? j['outbounds'] : null;
      if (obs is List && obs.any((o) => o is Map && o['type'] != null)) {
        return _fromSingBox(obs.cast<dynamic>());
      }
    } catch (_) {}
    return Prepared(t, [], 0); // обычный Xray JSON — отдаём ядру как есть
  }
  // Clash / Mihomo YAML
  if (RegExp(r'^\s*proxies\s*:', multiLine: true).hasMatch(t)) {
    try {
      final y = loadYaml(t);
      final proxies = (y is YamlMap ? y['proxies'] : null);
      if (proxies is YamlList) return _fromClash(proxies.toList());
    } catch (_) {}
  }
  // Построчно: wireguard:// и socks5:// — сами, остальное — ядру
  final links = <String>[];
  final obs = <Map<String, dynamic>>[];
  for (var l in t.split(RegExp(r'[\r\n]+'))) {
    l = l.trim();
    if (l.isEmpty) continue;
    if (l.startsWith('wireguard://') || l.startsWith('wg://')) {
      final ob = _wgLink(l);
      if (ob != null) obs.add(ob);
      continue;
    }
    if (l.startsWith('socks5://')) l = 'socks://${l.substring(9)}';
    links.add(l);
  }
  return Prepared(links.join('\n'), obs, 0);
}

// ---------- WireGuard ----------

Map<String, dynamic> _wgOutbound({
  required String name,
  required String privateKey,
  required String publicKey,
  required String endpoint,
  required List<String> address,
  String preShared = '',
  int mtu = 1420,
  List<int>? reserved,
}) => {
  'tag': name,
  'protocol': 'wireguard',
  'settings': {
    'secretKey': privateKey,
    'address': address,
    'mtu': mtu,
    if (reserved != null && reserved.length == 3) 'reserved': reserved,
    'peers': [
      {
        'publicKey': publicKey,
        if (preShared.isNotEmpty) 'preSharedKey': preShared,
        'endpoint': endpoint,
        'allowedIPs': ['0.0.0.0/0', '::/0'],
      },
    ],
  },
};

Map<String, dynamic>? _wgLink(String l) {
  try {
    final u = Uri.parse(l.replaceFirst('wg://', 'wireguard://'));
    final q = u.queryParameters;
    final pk = Uri.decodeComponent(u.userInfo);
    final pub = q['publickey'] ?? q['publicKey'] ?? q['peer_public_key'] ?? '';
    if (pk.isEmpty || pub.isEmpty || u.host.isEmpty) return null;
    final addr = (q['address'] ?? q['ip'] ?? '10.0.0.2/32')
        .split(',')
        .map((e) => e.trim())
        .toList();
    final res = (q['reserved'] ?? '')
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
    return _wgOutbound(
      name: u.fragment.isEmpty
          ? 'WireGuard ${u.host}'
          : Uri.decodeComponent(u.fragment),
      privateKey: pk,
      publicKey: pub,
      preShared: q['presharedkey'] ?? q['preSharedKey'] ?? '',
      endpoint: '${_host(u.host)}:${u.hasPort ? u.port : 51820}',
      address: addr,
      mtu: int.tryParse(q['mtu'] ?? '') ?? 1420,
      reserved: res,
    );
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? _wgConf(String t) {
  String get(String key) {
    final m = RegExp(
      '^\\s*$key\\s*=\\s*(.+)\$',
      multiLine: true,
      caseSensitive: false,
    ).firstMatch(t);
    return m?.group(1)?.trim() ?? '';
  }

  final pk = get('PrivateKey'), pub = get('PublicKey'), ep = get('Endpoint');
  if (pk.isEmpty || pub.isEmpty || ep.isEmpty) return null;
  return _wgOutbound(
    name: 'WireGuard ${ep.split(':').first}',
    privateKey: pk,
    publicKey: pub,
    preShared: get('PresharedKey'),
    endpoint: ep,
    address: get('Address')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(),
    mtu: int.tryParse(get('MTU')) ?? 1420,
  );
}

// ---------- Clash / Mihomo ----------

Prepared _fromClash(List<dynamic> proxies) {
  final links = <String>[];
  final obs = <Map<String, dynamic>>[];
  var skipped = 0;
  for (final raw in proxies) {
    if (raw is! Map) continue;
    final p = Map<String, dynamic>.from(raw);
    final type = _s(p['type']).toLowerCase();
    final name = _s(p['name']);
    final server = _host(_s(p['server']));
    final port = _s(p['port']);
    final frag = Uri.encodeComponent(name);
    final net = _s(p['network']).isEmpty ? 'tcp' : _s(p['network']);
    final ws = (p['ws-opts'] as Map?) ?? {};
    final grpc = (p['grpc-opts'] as Map?) ?? {};
    final reality = (p['reality-opts'] as Map?) ?? {};
    final wsHost = _s(((ws['headers'] as Map?) ?? {})['Host']);
    final sni = _s(p['servername'] ?? p['sni']);
    final fp = _s(p['client-fingerprint']);
    final alpn = (p['alpn'] is List)
        ? (p['alpn'] as List).join(',')
        : _s(p['alpn']);
    Map<String, String> transport() => {
      'type': net,
      if (net == 'ws') 'path': _s(ws['path']),
      if (net == 'ws') 'host': wsHost,
      if (net == 'grpc') 'serviceName': _s(grpc['grpc-service-name']),
    };
    switch (type) {
      case 'vless':
        final sec = reality.isNotEmpty
            ? 'reality'
            : (p['tls'] == true ? 'tls' : 'none');
        links.add(
          'vless://${p['uuid']}@$server:$port?${_q({'encryption': 'none', 'security': sec, 'flow': _s(p['flow']), 'sni': sni, 'fp': fp, 'alpn': alpn, 'pbk': _s(reality['public-key']), 'sid': _s(reality['short-id']), ...transport()})}#$frag',
        );
      case 'vmess':
        links.add(
          'vmess://${p['uuid']}@$server:$port?${_q({'encryption': _s(p['cipher']).isEmpty ? 'auto' : _s(p['cipher']), 'security': p['tls'] == true ? 'tls' : 'none', 'sni': sni, 'fp': fp, 'alpn': alpn, ...transport()})}#$frag',
        );
      case 'trojan':
        links.add(
          'trojan://${Uri.encodeComponent(_s(p['password']))}@$server:$port?${_q({'security': reality.isNotEmpty ? 'reality' : 'tls', 'sni': sni, 'fp': fp, 'alpn': alpn, 'pbk': _s(reality['public-key']), 'sid': _s(reality['short-id']), ...transport()})}#$frag',
        );
      case 'ss':
        final ui = base64Url
            .encode(utf8.encode('${p['cipher']}:${p['password']}'))
            .replaceAll('=', '');
        links.add('ss://$ui@$server:$port#$frag');
      case 'hysteria2':
      case 'hy2':
        links.add(
          'hysteria2://${Uri.encodeComponent(_s(p['password']))}@$server:$port?${_q({'sni': sni, 'alpn': alpn, 'obfs': _s(p['obfs']), 'obfs-password': _s(p['obfs-password'])})}#$frag',
        );
      case 'socks5':
        final auth = _s(p['username']).isEmpty
            ? ''
            : '${base64Url.encode(utf8.encode('${p['username']}:${p['password']}')).replaceAll('=', '')}@';
        links.add('socks://$auth$server:$port#$frag');
      case 'wireguard':
        final ip = [_s(p['ip']), _s(p['ipv6'])]
            .where((e) => e.isNotEmpty)
            .map(
              (e) =>
                  e.contains('/') ? e : (e.contains(':') ? '$e/128' : '$e/32'),
            )
            .toList();
        obs.add(
          _wgOutbound(
            name: name,
            privateKey: _s(p['private-key']),
            publicKey: _s(p['public-key']),
            preShared: _s(p['pre-shared-key']),
            endpoint: '$server:$port',
            address: ip.isEmpty ? ['10.0.0.2/32'] : ip,
            mtu: int.tryParse(_s(p['mtu'])) ?? 1420,
            reserved: (p['reserved'] is List)
                ? (p['reserved'] as List)
                      .map((e) => int.tryParse('$e') ?? 0)
                      .toList()
                : null,
          ),
        );
      default:
        skipped++;
    }
  }
  return Prepared(links.join('\n'), obs, skipped);
}

// ---------- sing-box ----------

Prepared _fromSingBox(List<dynamic> outbounds) {
  final links = <String>[];
  final obs = <Map<String, dynamic>>[];
  var skipped = 0;
  for (final raw in outbounds) {
    if (raw is! Map) continue;
    final o = Map<String, dynamic>.from(raw);
    final type = _s(o['type']);
    if (const {'direct', 'block', 'dns', 'selector', 'urltest'}.contains(type))
      continue;
    final name = _s(o['tag']);
    final server = _host(_s(o['server']));
    final port = _s(o['server_port']);
    final frag = Uri.encodeComponent(name);
    final tls = (o['tls'] as Map?) ?? {};
    final reality = (tls['reality'] as Map?) ?? {};
    final utls = (tls['utls'] as Map?) ?? {};
    final tr = (o['transport'] as Map?) ?? {};
    final trType = _s(tr['type']);
    final alpn = (tls['alpn'] is List) ? (tls['alpn'] as List).join(',') : '';
    final common = <String, String>{
      'security': reality['enabled'] == true
          ? 'reality'
          : (tls['enabled'] == true ? 'tls' : 'none'),
      'sni': _s(tls['server_name']),
      'fp': _s(utls['fingerprint']),
      'alpn': alpn,
      'pbk': _s(reality['public_key']),
      'sid': _s(reality['short_id']),
      'type': trType.isEmpty ? 'tcp' : (trType == 'http' ? 'tcp' : trType),
      if (trType == 'ws') 'path': _s(tr['path']),
      if (trType == 'ws') 'host': _s(((tr['headers'] as Map?) ?? {})['Host']),
      if (trType == 'grpc') 'serviceName': _s(tr['service_name']),
      if (trType == 'httpupgrade') 'path': _s(tr['path']),
      if (trType == 'httpupgrade') 'host': _s(tr['host']),
    };
    switch (type) {
      case 'vless':
        links.add(
          'vless://${o['uuid']}@$server:$port?${_q({'encryption': 'none', 'flow': _s(o['flow']), ...common})}#$frag',
        );
      case 'vmess':
        links.add(
          'vmess://${o['uuid']}@$server:$port?${_q({'encryption': _s(o['security']).isEmpty ? 'auto' : _s(o['security']), ...common})}#$frag',
        );
      case 'trojan':
        links.add(
          'trojan://${Uri.encodeComponent(_s(o['password']))}@$server:$port?${_q(common)}#$frag',
        );
      case 'shadowsocks':
        final ui = base64Url
            .encode(utf8.encode('${o['method']}:${o['password']}'))
            .replaceAll('=', '');
        links.add('ss://$ui@$server:$port#$frag');
      case 'hysteria2':
        final obfs = (o['obfs'] as Map?) ?? {};
        links.add(
          'hysteria2://${Uri.encodeComponent(_s(o['password']))}@$server:$port?${_q({'sni': _s(tls['server_name']), 'alpn': alpn, 'obfs': _s(obfs['type']), 'obfs-password': _s(obfs['password'])})}#$frag',
        );
      case 'socks':
        links.add('socks://$server:$port#$frag');
      case 'wireguard':
        final peers = (o['peers'] as List?) ?? [];
        final peer = peers.isNotEmpty
            ? Map<String, dynamic>.from(peers.first as Map)
            : <String, dynamic>{};
        obs.add(
          _wgOutbound(
            name: name,
            privateKey: _s(o['private_key']),
            publicKey: _s(peer['public_key'] ?? o['peer_public_key']),
            preShared: _s(peer['pre_shared_key'] ?? o['pre_shared_key']),
            endpoint:
                '${_host(_s(peer['server'] ?? o['server']))}:${_s(peer['server_port'] ?? o['server_port'])}',
            address: ((o['local_address'] as List?) ?? ['10.0.0.2/32'])
                .map((e) => '$e')
                .toList(),
            mtu: int.tryParse(_s(o['mtu'])) ?? 1420,
          ),
        );
      default:
        skipped++;
    }
  }
  return Prepared(links.join('\n'), obs, skipped);
}
