import 'package:flutter_test/flutter_test.dart';
import 'package:netro/country.dart';
import 'package:netro/protocols.dart';
import 'package:netro/sub_service.dart';

void main() {
  test('ссылки: без https, внутри текста, happ://add', () {
    expect(normalizeInput('sub.umkh7.com/AbC123'), 'https://sub.umkh7.com/AbC123');
    expect(normalizeInput('Ваша подписка: https://sub.umkh7.com/AbC123. Удачи'), 'https://sub.umkh7.com/AbC123');
    expect(normalizeInput('happ://add/https%3A%2F%2Fsub.x.com%2Fq'), 'https://sub.x.com/q');
    expect(normalizeInput('netro://add?url=https%3A%2F%2Fsub.x.com%2Fq'), 'https://sub.x.com/q');
    expect(normalizeInput('vless://id@h:443?type=tcp#a'), 'vless://id@h:443?type=tcp#a');
  });

  test('флаг ЕС и эмодзи', () {
    final g = guessCountry('🇪🇺 Стелс · 4');
    expect(g.code, 'eu');
    expect(g.emoji, '🇪🇺');
    expect(g.cleanName, 'Стелс · 4');
  });

  test('Clash YAML', () {
    const y = '''
proxies:
  - {name: "🇳🇱 NL", type: vless, server: 1.2.3.4, port: 443, uuid: 11111111-1111-1111-1111-111111111111, tls: true, flow: xtls-rprx-vision, servername: www.microsoft.com, client-fingerprint: chrome, reality-opts: {public-key: PBK, short-id: ab}}
  - {name: SS, type: ss, server: s.example.com, port: 8388, cipher: aes-256-gcm, password: pw}
  - {name: HY, type: hysteria2, server: h.example.com, port: 443, password: pw, sni: h.example.com}
  - {name: WG, type: wireguard, server: 5.6.7.8, port: 51820, ip: 10.0.0.2, private-key: PRIV, public-key: PUB}
  - {name: T, type: tuic, server: t.example.com, port: 443}
''';
    final p = prepare(y);
    final lines = p.links.split('\n');
    expect(lines.length, 3);
    expect(lines[0], startsWith('vless://11111111-1111-1111-1111-111111111111@1.2.3.4:443?'));
    expect(lines[0], contains('security=reality'));
    expect(lines[0], contains('pbk=PBK'));
    expect(lines[1], startsWith('ss://'));
    expect(lines[2], startsWith('hysteria2://pw@h.example.com:443'));
    expect(p.outbounds.single['protocol'], 'wireguard');
    expect(p.skipped, 1);
  });

  test('sing-box JSON', () {
    const j = '{"outbounds":[{"type":"vless","tag":"A","server":"a.com","server_port":443,"uuid":"u","tls":{"enabled":true,"server_name":"a.com","reality":{"enabled":true,"public_key":"K","short_id":"s"}}},{"type":"direct","tag":"direct"}]}';
    final p = prepare(j);
    expect(p.links, startsWith('vless://u@a.com:443?'));
    expect(p.links, contains('security=reality'));
  });

  test('WireGuard ссылка и .conf', () {
    final a = prepare('wireguard://PRIV%3D@9.9.9.9:51820?publickey=PUB%3D&address=10.0.0.2/32&reserved=1,2,3#My%20WG');
    final ob = a.outbounds.single;
    expect(ob['tag'], 'My WG');
    expect((ob['settings'] as Map)['secretKey'], 'PRIV=');
    const conf = '[Interface]\nPrivateKey = PRIV\nAddress = 10.0.0.2/32\n\n[Peer]\nPublicKey = PUB\nEndpoint = 1.1.1.1:51820\n';
    expect(prepare(conf).outbounds.single['protocol'], 'wireguard');
  });
}
