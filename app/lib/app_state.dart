import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config_builder.dart';
import 'core.dart';
import 'models.dart';
import 'settings.dart';
import 'sub_service.dart';

class AppState extends ChangeNotifier {
  List<Subscription> subs = [];
  String? selectedId;
  String? viewSubId; // вкладка на экране «Серверы»
  ConnMode mode = ConnMode.tun;
  ConnState conn = ConnState.off;
  DateTime? connectedAt;
  int downBps = 0, upBps = 0;
  bool pinging = false;
  final Set<String> refreshing = {};
  String? lastError;
  Settings settings = Settings();
  Map<String, dynamic>? ip; // IP и страна выхода после подключения
  bool ipLoading = false;
  int sessionDown = 0, sessionUp = 0;

  late SharedPreferences _p;
  StreamSubscription? _stateSub;
  Timer? _ticker;
  List<int>? _lastTotals;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    final raw = _p.getString('subs');
    if (raw != null) {
      try {
        subs = Subscription.decodeList(raw);
      } catch (_) {}
    }
    selectedId = _p.getString('selected');
    mode = _p.getString('mode') == 'proxy' ? ConnMode.proxy : ConnMode.tun;
    settings = Settings.fromJson(_p.getString('settings'));
    _stateSub = Core.states.listen(_onState);
    try {
      _onState(await Core.current());
    } catch (_) {}
    notifyListeners();
    // Автообновление подписок старше часа.
    for (final s in subs.where((s) => s.autoUpdate && !s.isManual)) {
      if (s.updatedAt == null ||
          DateTime.now().difference(s.updatedAt!).inMinutes > 60) {
        unawaited(refresh(s, silent: true));
      }
    }
    if (settings.autoConnect && conn == ConnState.off && selected != null) {
      unawaited(connect());
    }
  }

  Future<void> saveSettings() async {
    await _p.setString('settings', settings.encode());
    notifyListeners();
  }

  /// Изменение настроек, влияющих на конфиг: переподключаемся, если VPN включён.
  Future<void> applySettings() async {
    await saveSettings();
    if (conn == ConnState.on) {
      await Core.stop();
      await connect();
    }
  }

  Future<void> refreshIp() async {
    if (conn != ConnState.on) return;
    ipLoading = true;
    notifyListeners();
    ip = await Core.ipInfo();
    ipLoading = false;
    notifyListeners();
  }

  void _onState(ConnState s) {
    conn = s;
    if (s == ConnState.on) {
      final first = connectedAt == null;
      connectedAt ??= DateTime.now();
      _startTicker();
      if (first) {
        ip = null;
        Future.delayed(const Duration(milliseconds: 800), refreshIp);
      }
    } else {
      if (s != ConnState.connecting) {
        connectedAt = null;
        ip = null;
        sessionDown = sessionUp = 0;
      }
      _ticker?.cancel();
      _ticker = null;
      downBps = upBps = 0;
      _lastTotals = null;
    }
    notifyListeners();
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) async {
      final t = await Core.trafficTotals();
      if (t != null && _lastTotals != null) {
        downBps = (t[0] - _lastTotals![0]).clamp(0, 1 << 40);
        upBps = (t[1] - _lastTotals![1]).clamp(0, 1 << 40);
      }
      if (t != null) {
        sessionDown = t[0];
        sessionUp = t[1];
      }
      _lastTotals = t;
      notifyListeners();
    });
  }

  Future<void> _save() async {
    await _p.setString('subs', Subscription.encodeList(subs));
    if (selectedId != null) await _p.setString('selected', selectedId!);
    await _p.setString('mode', mode.name);
  }

  List<Server> get allServers => [for (final s in subs) ...s.servers];

  Server? get selected {
    for (final s in allServers) {
      if (s.id == selectedId) return s;
    }
    return allServers.isEmpty ? null : allServers.first;
  }

  Subscription? subOf(Server sv) {
    for (final s in subs) {
      if (s.servers.any((x) => x.id == sv.id)) return s;
    }
    return null;
  }

  Subscription? get mainSub =>
      subs.where((s) => !s.isManual).firstOrNull ?? subs.firstOrNull;

  Future<void> select(Server s) async {
    final wasOn = conn == ConnState.on || conn == ConnState.connecting;
    selectedId = s.id;
    notifyListeners();
    await _save();
    if (wasOn) {
      await Core.stop();
      await connect();
    }
  }

  Future<void> setMode(ConnMode m) async {
    if (m == mode) return;
    final wasOn = conn == ConnState.on;
    mode = m;
    notifyListeners();
    await _save();
    if (wasOn) {
      await Core.stop();
      await connect();
    }
  }

  Future<void> toggle() async {
    if (conn == ConnState.on || conn == ConnState.connecting) {
      await Core.stop();
    } else {
      await connect();
    }
  }

  Future<void> connect() async {
    if (settings.autoBest && conn == ConnState.off) {
      final sub = selected == null ? null : subOf(selected!);
      if (sub != null) {
        await pingSub(sub, quiet: true);
        final best = bestOf(sub);
        if (best != null) selectedId = best.id;
      }
    }
    final s = selected;
    if (s == null) {
      lastError = 'Сначала добавьте подписку';
      notifyListeners();
      return;
    }
    lastError = null;
    conn = ConnState.connecting;
    connectedAt = null;
    notifyListeners();
    try {
      // На iOS есть только туннель (NetworkExtension).
      final m = Platform.isIOS ? ConnMode.tun : mode;
      Core.setNativeOptions(
        dns: dnsById(settings.dns).ip,
        split: settings.split.name,
        apps: settings.splitApps,
      );
      await Core.start(buildXrayConfig(s, m, settings), m);
    } catch (e) {
      conn = ConnState.off;
      lastError = 'Не удалось подключиться: $e';
      notifyListeners();
    }
  }

  /// Добавление из текста: ссылка подписки или ключи.
  Future<Subscription> addFromText(String text) async {
    final t = normalizeInput(text);
    if (t.isEmpty) throw CoreError('Вставьте ссылку или ключ');
    if (isSubscriptionUrl(t)) {
      final exist = subs.where((s) => s.url == t).firstOrNull;
      if (exist != null) {
        await refresh(exist);
        return exist;
      }
      final id = newId();
      final r = await fetchSubscription(t, id);
      final sub = Subscription(
        id: id,
        title: r.title,
        url: t,
        servers: r.servers,
        updatedAt: DateTime.now(),
        expire: r.expire,
        usedBytes: r.used,
        totalBytes: r.total,
        supportUrl: r.supportUrl,
        webPageUrl: r.webPageUrl,
      );
      subs.add(sub);
      selectedId ??= sub.servers.first.id;
      viewSubId = sub.id;
      await _save();
      notifyListeners();
      return sub;
    }
    // Ключи → группа «Мои ключи».
    var manual = subs.where((s) => s.isManual).firstOrNull;
    final id = manual?.id ?? 'keys';
    final added = await parseServers(t, '$id-${newId()}');
    if (added.isEmpty) throw CoreError('Не удалось прочитать ключ');
    if (manual == null) {
      manual = Subscription(
        id: id,
        title: '🔑 Мои ключи',
        url: null,
        servers: [],
        updatedAt: DateTime.now(),
      );
      subs.add(manual);
    }
    manual.servers = [...manual.servers, ...added];
    selectedId ??= added.first.id;
    viewSubId = manual.id;
    await _save();
    notifyListeners();
    return manual;
  }

  Future<void> refresh(Subscription s, {bool silent = false}) async {
    if (s.isManual || refreshing.contains(s.id)) return;
    refreshing.add(s.id);
    notifyListeners();
    try {
      final r = await fetchSubscription(s.url!, s.id);
      final oldSel = selected;
      if (!s.customTitle) s.title = r.title;
      s
        ..servers = r.servers
        ..updatedAt = DateTime.now()
        ..expire = r.expire
        ..usedBytes = r.used
        ..totalBytes = r.total
        ..supportUrl = r.supportUrl
        ..webPageUrl = r.webPageUrl;
      // Сохраняем выбор по имени, если id поменялся.
      if (oldSel != null && !allServers.any((x) => x.id == selectedId)) {
        final same = s.servers.where((x) => x.name == oldSel.name).firstOrNull;
        selectedId = (same ?? s.servers.first).id;
      }
      await _save();
    } catch (e) {
      if (!silent) lastError = 'Не удалось обновить: $e';
    } finally {
      refreshing.remove(s.id);
      notifyListeners();
    }
  }

  Future<void> remove(Subscription s) async {
    subs.remove(s);
    if (!allServers.any((x) => x.id == selectedId))
      selectedId = allServers.firstOrNull?.id;
    if (viewSubId == s.id) viewSubId = null;
    await _save();
    notifyListeners();
  }

  Future<void> toggleAuto(Subscription s) async {
    s.autoUpdate = !s.autoUpdate;
    await _save();
    notifyListeners();
  }

  /// Пинг серверов подписки. Пока VPN включён, ядро занято — пинг недоступен.
  Future<void> pingSub(Subscription s, {bool quiet = false}) async {
    if (pinging) return;
    final busy = conn == ConnState.on || conn == ConnState.connecting;
    if (busy && quiet) return;
    pinging = true;
    notifyListeners();
    try {
      // Пока VPN включён, ядро занято (а на iPhone проверка шла бы через сам
      // туннель) — тогда меряем время соединения с сервером напрямую (TCP).
      final d = busy
          ? await Future.wait(
              s.servers.map(
                (e) => Core.tcpPing(e.outbound, timeout: settings.pingTimeout),
              ),
            )
          : await Core.ping(
              s.servers.map((e) => e.outbound).toList(),
              url: settings.pingUrl,
              timeout: settings.pingTimeout,
            );
      for (var i = 0; i < s.servers.length && i < d.length; i++) {
        s.servers[i].ping = d[i];
      }
      await _save();
    } finally {
      pinging = false;
      notifyListeners();
    }
  }

  /// Сервер с лучшим пингом в подписке (без ошибок).
  Server? bestOf(Subscription s) {
    final ok =
        s.servers.where((x) => x.ping != null && x.ping! < 10000).toList()
          ..sort((a, b) => a.ping!.compareTo(b.ping!));
    return ok.firstOrNull;
  }

  Future<void> selectBest(Subscription s) async {
    if (conn == ConnState.off) await pingSub(s);
    final b = bestOf(s);
    if (b == null) {
      lastError = conn == ConnState.off
          ? 'Ни один сервер не ответил'
          : 'Отключите VPN, чтобы проверить пинг';
      notifyListeners();
      return;
    }
    await select(b);
  }

  /// Серверы подписки в выбранном порядке.
  List<Server> sorted(Subscription s) {
    final l = [...s.servers];
    switch (settings.sort) {
      case SortMode.ping:
        l.sort((a, b) => (a.ping ?? 99999).compareTo(b.ping ?? 99999));
      case SortMode.name:
        l.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case SortMode.list:
        break;
    }
    return l;
  }

  Future<void> setSort(SortMode m) async {
    settings.sort = m;
    await saveSettings();
  }

  Future<void> removeServer(Server sv) async {
    final sub = subOf(sv);
    if (sub == null) return;
    sub.servers = sub.servers.where((x) => x.id != sv.id).toList();
    if (sub.isManual && sub.servers.isEmpty) subs.remove(sub);
    if (selectedId == sv.id) selectedId = allServers.firstOrNull?.id;
    await _save();
    notifyListeners();
  }

  Future<void> rename(Subscription s, String title) async {
    final t = title.trim();
    if (t.isEmpty) return;
    s.title = t;
    s.customTitle = true;
    await _save();
    notifyListeners();
  }

  Future<void> refreshAll() async {
    for (final s in subs.where((s) => !s.isManual)) {
      await refresh(s);
    }
  }

  void clearError() {
    lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }
}
