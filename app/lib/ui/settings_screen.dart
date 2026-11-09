import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core.dart';
import '../settings.dart';
import '../sub_service.dart' show appVersion;
import 'kit.dart';

const _pingUrls = {
  'https://cp.cloudflare.com/': 'Cloudflare',
  'https://www.gstatic.com/generate_204': 'Google',
  'https://captive.apple.com/': 'Apple',
};

class SettingsScreen extends StatelessWidget {
  final AppState st;
  const SettingsScreen({super.key, required this.st});

  @override
  Widget build(BuildContext context) {
    final s = st.settings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        const LargeTitle('Настройки'),
        const SizedBox(height: 4),
        Appear(
          child: Group(
            header: 'Подключение',
            children: [
              SwitchRow(
                leading: const RowIcon(Icons.play_arrow_rounded, C.green),
                title: 'Подключаться при запуске',
                value: s.autoConnect,
                onChanged: (v) {
                  s.autoConnect = v;
                  st.saveSettings();
                },
              ),
              SwitchRow(
                leading: const RowIcon(Icons.bolt_rounded, C.orange),
                title: 'Выбирать самый быстрый сервер',
                subtitle: 'Перед подключением проверять пинг',
                value: s.autoBest,
                onChanged: (v) {
                  s.autoBest = v;
                  st.saveSettings();
                },
              ),
            ],
          ),
        ),
        Appear(
          index: 1,
          child: Group(
            header: 'Маршрутизация',
            footer: 'Изменения применяются сразу — VPN переподключится сам.',
            children: [
              SwitchRow(
                leading: const RowIcon(
                  Icons.router_outlined,
                  Color(0xFF30B0C7),
                ),
                title: 'Локальная сеть напрямую',
                subtitle: 'Роутер, принтер, телевизор — мимо VPN',
                value: s.lanDirect,
                onChanged: (v) {
                  s.lanDirect = v;
                  st.applySettings();
                },
              ),
              SwitchRow(
                leading: const RowIcon(Icons.language_rounded, C.red),
                title: 'Сайты .ru и .рф напрямую',
                subtitle: 'Госуслуги, банки и маркетплейсы — без VPN',
                value: s.ruDirect,
                onChanged: (v) {
                  s.ruDirect = v;
                  st.applySettings();
                },
              ),
              NavRow(
                leading: const RowIcon(Icons.dns_outlined, C.accent),
                title: 'DNS',
                value: dnsById(s.dns).title,
                onTap: () =>
                    Navigator.of(context).push(smoothRoute(_DnsPage(st: st))),
              ),
              if (Platform.isAndroid)
                NavRow(
                  leading: const RowIcon(Icons.apps_rounded, Color(0xFF8E5CF7)),
                  title: 'Приложения через VPN',
                  value: switch (s.split) {
                    SplitMode.off => 'Все',
                    SplitMode.exclude => 'Кроме ${s.splitApps.length}',
                    SplitMode.include => 'Только ${s.splitApps.length}',
                  },
                  onTap: () =>
                      Navigator.of(context)
                          .push(smoothRoute(_AppsPage(st: st))),
                ),
            ],
          ),
        ),
        Appear(
          index: 2,
          child: Group(
            header: 'Проверка пинга',
            children: [
              NavRow(
                leading: const RowIcon(Icons.speed_rounded, Color(0xFF34C759)),
                title: 'Адрес проверки',
                value: _pingUrls[s.pingUrl] ?? 'Свой',
                onTap: () async {
                  final v = await showSheet<String>(
                    context,
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Group(
                        children: [
                          for (final e in _pingUrls.entries)
                            NavRow(
                              title: e.value,
                              subtitle: e.key,
                              chevron: false,
                              trailing: s.pingUrl == e.key
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: C.accent,
                                    )
                                  : const SizedBox.shrink(),
                              onTap: () => Navigator.pop(context, e.key),
                            ),
                        ],
                      ),
                    ),
                  );
                  if (v != null) {
                    s.pingUrl = v;
                    st.saveSettings();
                  }
                },
              ),
              NavRow(
                leading: const RowIcon(Icons.timer_outlined, Color(0xFF636366)),
                title: 'Тайм-аут',
                value: '${s.pingTimeout} с',
                onTap: () {
                  s.pingTimeout = s.pingTimeout >= 10 ? 3 : s.pingTimeout + 1;
                  st.saveSettings();
                },
              ),
            ],
          ),
        ),
        Appear(
          index: 3,
          child: Group(
            header: 'О приложении',
            children: [
              FutureBuilder<String>(
                future: Core.version(),
                builder: (_, v) => NavRow(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/netro_glyph.png',
                      width: 30,
                      height: 30,
                    ),
                  ),
                  title: 'Netro $appVersion',
                  subtitle: v.data == null || v.data!.isEmpty
                      ? 'Ядро Xray'
                      : 'Ядро Xray ${v.data}',
                ),
              ),
              NavRow(
                leading: const RowIcon(Icons.lan_outlined, Color(0xFF636366)),
                title: 'Локальный прокси',
                subtitle: 'SOCKS5 127.0.0.1:10808 · HTTP 127.0.0.1:10809',
              ),
              NavRow(
                leading: const RowIcon(
                  Icons.description_outlined,
                  Color(0xFF636366),
                ),
                title: 'Лицензии',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Netro',
                  applicationVersion: appVersion,
                  applicationLegalese:
                      'Ядро: Xray-core (MPL-2.0), libXray (MIT).',
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text(
            'Ключи доступа хранятся только на этом устройстве.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: C.gray),
          ),
        ),
      ],
    );
  }
}

class _DnsPage extends StatefulWidget {
  final AppState st;
  const _DnsPage({required this.st});
  @override
  State<_DnsPage> createState() => _DnsPageState();
}

class _DnsPageState extends State<_DnsPage> {
  @override
  Widget build(BuildContext context) {
    final s = widget.st.settings;
    return Scaffold(
      appBar: AppBar(backgroundColor: C.bg, title: const Text('DNS')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Group(
            footer: 'DNS переводит адреса сайтов в IP. AdGuard дополнительно убирает рекламу и трекеры во всех приложениях.',
            children: [
              for (final d in dnsOptions)
                NavRow(
                  title: d.title,
                  subtitle: d.subtitle,
                  chevron: false,
                  trailing: AnimatedScale(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    scale: s.dns == d.id ? 1 : 0,
                    child: const Icon(Icons.check_rounded, color: C.accent),
                  ),
                  onTap: () {
                    setState(() => s.dns = d.id);
                    widget.st.applySettings();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppsPage extends StatefulWidget {
  final AppState st;
  const _AppsPage({required this.st});
  @override
  State<_AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends State<_AppsPage> {
  List<AppInfo>? _apps;
  String _q = '';
  bool _system = false;

  @override
  void initState() {
    super.initState();
    Core.installedApps().then((a) {
      if (mounted) setState(() => _apps = a);
    });
  }

  @override
  void dispose() {
    widget.st.applySettings();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.st.settings;
    final apps = (_apps ?? [])
        .where((a) => _system || !a.system || s.splitApps.contains(a.pkg))
        .where(
          (a) => _q.isEmpty || a.name.toLowerCase().contains(_q.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.bg,
        title: const Text('Приложения через VPN'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _system = !_system),
            child: Text(_system ? 'Скрыть системные' : 'Системные'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Segmented<SplitMode>(
            items: const {
              SplitMode.off: 'Все',
              SplitMode.exclude: 'Кроме выбранных',
              SplitMode.include: 'Только выбранные',
            },
            value: s.split,
            onChanged: (v) => setState(() => s.split = v),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 12),
            child: Text(
              switch (s.split) {
                SplitMode.off => 'Весь трафик телефона идёт через VPN.',
                SplitMode.exclude => 'Отмеченные приложения будут работать без VPN (например, банк).',
                SplitMode.include =>
                  'Через VPN пойдут только отмеченные приложения.',
              },
              style: const TextStyle(fontSize: 13, color: C.gray, height: 1.4),
            ),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: s.split == SplitMode.off ? 0.4 : 1,
            child: IgnorePointer(
              ignoring: s.split == SplitMode.off,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _q = v),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Поиск приложения',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: C.gray,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: C.field,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_apps == null)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    )
                  else
                    Group(
                      children: [
                        for (final a in apps)
                          NavRow(
                            title: a.name,
                            subtitle: a.pkg,
                            chevron: false,
                            trailing: Checkbox(
                              value: s.splitApps.contains(a.pkg),
                              activeColor: C.accent,
                              onChanged: (v) => setState(() {
                                v == true
                                    ? s.splitApps.add(a.pkg)
                                    : s.splitApps.remove(a.pkg);
                              }),
                            ),
                            onTap: () => setState(() {
                              s.splitApps.contains(a.pkg)
                                  ? s.splitApps.remove(a.pkg)
                                  : s.splitApps.add(a.pkg);
                            }),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
