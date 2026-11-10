// Рендер экранов в PNG для превью (не входит в приложение).
// Запуск: flutter test test/screens_preview_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netro/app_state.dart';
import 'package:netro/models.dart';
import 'package:netro/ui/bypass_screen.dart';
import 'package:netro/ui/home_screen.dart';
import 'package:netro/ui/kit.dart';
import 'package:netro/ui/servers_screen.dart';
import 'package:netro/ui/settings_screen.dart';
import 'package:netro/ui/subs_screen.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.view(File(f).readAsBytesSync().buffer)));
  }
  await l.load();
}

Server _s(String id, String name, String cc, String proto, int? ping) =>
    Server(id: id, name: name, country: cc, protocol: proto, outbound: const {}, ping: ping, emoji: cc == 'eu' ? '🇪🇺' : '');

AppState _demo({bool on = false}) {
  final st = AppState();
  st.subs = [
    Subscription(
      id: 'u7',
      title: '⚡ U7 VPN',
      url: 'https://sub.umkh7.com/demo',
      servers: [
        _s('u7-auto', 'Авто LTE 🚀', 'eu', 'VLESS · Reality', 41),
        _s('u7-se2', 'Швеция LTE', 'se', 'VLESS · TLS', 58),
        _s('u7-gb', 'Англия LTE', 'gb', 'VLESS · TLS', 66),
        _s('u7-eu1', 'Европа LTE · 1', 'eu', 'VLESS · Reality', 52),
        _s('u7-eu2', 'Европа LTE · 2', 'eu', 'VLESS · Reality', 49),
        _s('u7-eu3', 'Европа LTE · 3', 'eu', 'VLESS · Reality', 57),
        _s('u7-nl', 'Нидерланды', 'nl', 'VLESS · Reality', 48),
        _s('u7-de', 'Германия', 'de', 'VLESS · Reality', 54),
        _s('u7-fi', 'Финляндия', 'fi', 'VLESS · XHTTP', 39),
        _s('u7-se', 'Швеция', 'se', 'Trojan · TLS', 71),
        _s('u7-tr', 'Турция', 'tr', 'VMess · WebSocket', 96),
        _s('u7-us', 'США', 'us', 'Shadowsocks', 162),
        _s('u7-ru', 'Россия LTE', 'ru', 'VLESS · Reality', 63),
        for (var i = 1; i <= 16; i++) _s('u7-st$i', 'Стелс · $i', 'eu', 'VLESS · Reality', 40 + i * 3),
      ],
      updatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      expire: DateTime.now().add(const Duration(days: 24)),
      usedBytes: 15 * 1024 * 1024 * 1024,
      totalBytes: 0,
      webPageUrl: 'https://vpn.umkh7.com',
    ),
    Subscription(id: 'keys', title: '🔑 Мои ключи', url: null, servers: [_s('k-1', 'Мой сервер', 'nl', 'VLESS · Reality', 44)]),
  ];
  st.selectedId = 'u7-nl';
  if (on) {
    st.conn = ConnState.on;
    st.connectedAt = DateTime.now().subtract(const Duration(minutes: 12, seconds: 34));
    st.downBps = 6200000;
    st.upBps = 1580000;
    st.sessionDown = 412 * 1024 * 1024;
    st.sessionUp = 38 * 1024 * 1024;
    st.ip = {'ip': '185.212.47.18', 'country': 'Netherlands', 'country_code': 'NL', 'city': 'Amsterdam'};
  }
  return st;
}

Widget _wrap(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: netroTheme().copyWith(
        textTheme: netroTheme().textTheme.apply(fontFamily: 'Inter'),
      ),
      home: Scaffold(body: SafeArea(child: child)),
    );

void main() {
  setUpAll(() async {
    const fonts = '/usr/share/fonts/opentype/inter';
    await _font('Inter', ['$fonts/Inter-Regular.otf', '$fonts/Inter-Medium.otf', '$fonts/Inter-SemiBold.otf', '$fonts/Inter-Bold.otf']);
    await _font('MaterialIcons', ['/home/claude/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  });

  Future<void> shot(WidgetTester t, String name, Widget w) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    await t.pumpWidget(_wrap(w));
    await t.pump(const Duration(seconds: 2));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));
  }

  testWidgets('home off', (t) async => shot(t, '1-home', HomeScreen(st: _demo(), openServers: () {}, openSubs: () {}, openAdd: () {})));
  testWidgets('home on', (t) async => shot(t, '2-home-on', HomeScreen(st: _demo(on: true), openServers: () {}, openSubs: () {}, openAdd: () {})));
  testWidgets('servers', (t) async => shot(t, '3-servers', ServersScreen(st: _demo(), openAdd: () {})));
  testWidgets('subs', (t) async => shot(t, '4-subs', SubsScreen(st: _demo(), openAdd: () {})));
  testWidgets('settings', (t) async => shot(t, '5-settings', SettingsScreen(st: _demo())));
  testWidgets('bypass', (t) async {
    final st = _demo();
    st.settings.bypassDomains = ['umkh7.com', 'gosuslugi.ru', 'ozon.ru', 'ozone.ru'];
    await shot(t, '6-bypass', BypassScreen(st: st));
  });
}
