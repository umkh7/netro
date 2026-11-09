import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'app_state.dart';
import 'core.dart';
import 'ui/add_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/home_screen.dart';
import 'ui/kit.dart';
import 'ui/servers_screen.dart';
import 'ui/subs_screen.dart';

/// Ссылка netro://… из командной строки (Windows открывает так из браузера).
String? startupLink;

void main(List<String> args) async {
  startupLink = args.where((a) => a.startsWith('netro://')).firstOrNull;
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0E0E10),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    await Core.cleanupStaleProxy();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(440, 860),
        minimumSize: Size(380, 640),
        center: true,
        title: 'Netro',
        backgroundColor: Colors.black,
      ),
      () async {
        await windowManager.setPreventClose(true);
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
  final st = AppState();
  await st.init();
  if (Platform.isWindows) windowManager.addListener(_CloseGuard());
  runApp(NetroApp(st: st));
}

/// Windows: перед закрытием окна выключаем ядро и системный прокси,
/// иначе интернет останется направленным на несуществующий прокси.
class _CloseGuard with WindowListener {
  @override
  void onWindowClose() async {
    try {
      await Core.stop().timeout(const Duration(seconds: 3));
    } catch (_) {}
    await windowManager.destroy();
  }
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
        if (mounted) setState(() => _tab = 1);
        _toast('Добавлено: ${s.title}');
      }).catchError((e) {
        _toast('$e');
      });
    }

    if (startupLink != null) {
      final u = Uri.tryParse(startupLink!);
      if (u != null) handle(u);
    }
    if (Platform.isWindows) return; // на Windows ссылка приходит аргументом запуска
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

  Future<void> _openAdd() async {
    final sub = await showAddSheet(context, widget.st);
    if (sub != null && mounted) {
      setState(() => _tab = 1);
      _toast('Добавлено: ${sub.title} · ${sub.servers.length} '
          '${plural(sub.servers.length, 'сервер', 'сервера', 'серверов')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.st;
    void go(int i) => setState(() => _tab = i);
    final pages = [
      HomeScreen(st: st, openServers: () => go(1), openSubs: () => go(2), openAdd: _openAdd),
      ServersScreen(st: st, openAdd: _openAdd),
      SubsScreen(st: st, openAdd: _openAdd),
      SettingsScreen(st: st),
    ];
    return ScaffoldMessenger(
      key: _messenger,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Stack(children: [
            for (var i = 0; i < pages.length; i++)
              _FadeTab(active: i == _tab, child: pages[i]),
          ]),
        ),
        bottomNavigationBar: _TabBar(index: _tab, onTap: (i) {
          if (i != _tab) HapticFeedback.selectionClick();
          go(i);
        }),
      ),
    );
  }
}

/// Плавная смена вкладок: активная проявляется с лёгким сдвигом, остальные гаснут.
/// Состояние вкладок (прокрутка, поиск) сохраняется.
class _FadeTab extends StatelessWidget {
  final bool active;
  final Widget child;
  const _FadeTab({required this.active, required this.child});
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !active,
      child: TickerMode(
        enabled: active,
        child: AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: Duration(milliseconds: active ? 260 : 140),
          curve: Curves.easeOut,
          child: AnimatedSlide(
            offset: active ? Offset.zero : const Offset(0, 0.015),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: child,
          ),
        ),
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
      (Icons.tune_rounded, 'Настройки'),
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
                    AnimatedScale(
                      scale: i == index ? 1.08 : 1,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      child: Icon(items[i].$1, size: 25, color: i == index ? C.accent : C.gray),
                    ),
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
