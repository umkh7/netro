import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'core.dart';
import 'sub_service.dart';
import 'ui/add_screen.dart';
import 'ui/home_screen.dart';
import 'ui/kit.dart';
import 'ui/servers_screen.dart';
import 'ui/subs_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0E0E10),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  final st = AppState();
  await st.init();
  runApp(NetroApp(st: st));
}

class NetroApp extends StatelessWidget {
  final AppState st;
  const NetroApp({super.key, required this.st});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Netro',
        debugShowCheckedModeBanner: false,
        theme: netroTheme(),
        home: Shell(st: st),
      );
}

class Shell extends StatefulWidget {
  final AppState st;
  const Shell({super.key, required this.st});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription? _links;

  @override
  void initState() {
    super.initState();
    widget.st.addListener(_onChange);
    _initLinks();
  }

  /// netro://add/<ссылка> или netro://add?url=<ссылка> — кнопка «Добавить в Netro» на сайте.
  Future<void> _initLinks() async {
    final al = AppLinks();
    void handle(Uri u) {
      if (u.scheme != 'netro') return;
      String? url = u.queryParameters['url'];
      if (url == null && u.host == 'add') {
        final raw = u.toString();
        final i = raw.indexOf('add/');
        if (i >= 0) url = Uri.decodeComponent(raw.substring(i + 4));
      }
      if (url == null || url.isEmpty) return;
      widget.st.addFromText(url).then((s) {
        setState(() => _tab = 1);
        _toast('Добавлено: ${s.title}');
      }).catchError((e) {
        _toast('$e');
      });
    }

    try {
      final first = await al.getInitialLink();
      if (first != null) handle(first);
    } catch (_) {}
    _links = al.uriLinkStream.listen(handle, onError: (_) {});
  }

  void _toast(String t) =>
      _messenger.currentState?.showSnackBar(SnackBar(content: Text(t)));

  void _onChange() {
    final err = widget.st.lastError;
    if (err != null) {
      _toast(err);
      widget.st.lastError = null;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.st.removeListener(_onChange);
    _links?.cancel();
    super.dispose();
  }

  void _settings() async {
    final v = await Core.version();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: C.field,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Netro', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Версия $appVersion${v.isEmpty ? '' : ' · ядро Xray $v'}',
              style: const TextStyle(color: C.gray)),
          const SizedBox(height: 16),
          const Text(
            'Ключи доступа хранятся только на этом устройстве. '
            'Локальный прокси: SOCKS5 127.0.0.1:10808, HTTP 127.0.0.1:10809.',
            style: TextStyle(fontSize: 14, height: 1.45, color: C.gray),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.st;
    void go(int i) => setState(() => _tab = i);
    final pages = [
      HomeScreen(
        st: st,
        openServers: () => go(1),
        openSubs: () => go(2),
        openAdd: () => go(3),
        openSettings: _settings,
      ),
      ServersScreen(st: st, openAdd: () => go(3)),
      SubsScreen(st: st, openAdd: () => go(3)),
      AddScreen(st: st, onAdded: () => go(1)),
    ];
    return ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        body: SafeArea(bottom: false, child: IndexedStack(index: _tab, children: pages)),
        bottomNavigationBar: _TabBar(index: _tab, onTap: go),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _TabBar({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.power_settings_new_rounded, 'Подключение'),
      (Icons.public_rounded, 'Серверы'),
      (Icons.layers_outlined, 'Подписки'),
      (Icons.add_circle_outline_rounded, 'Добавить'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xF00E0E10),
        border: Border(top: BorderSide(color: C.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: InkResponse(
                  onTap: () => onTap(i),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(items[i].$1, size: 25, color: i == index ? C.accent : C.gray),
                    const SizedBox(height: 2),
                    Text(items[i].$2,
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w500, color: i == index ? C.accent : C.gray)),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
