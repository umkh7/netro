import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config_builder.dart';
import 'core.dart';
import 'models.dart';
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
    _stateSub = Core.states.listen(_onState);
    try {
      _onState(await Core.current());
    } catch (_) {}
    notifyListeners();
    // Автообновление подписок старше часа.
    for (final s in subs.where((s) => s.autoUpdate && !s.isManual)) {
      if (s.updatedAt == null || DateTime.now().difference(s.updatedAt!).inMinutes > 60) {
        unawaited(refresh(s, silent: true));
      }
    }
  }

  void _onState(ConnState s) {
    conn = s;
    if (s == ConnState.on) {
      connectedAt ??= DateTime.now();
      _startTicker();
    } else {
      if (s != ConnState.connecting) connectedAt = null;
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

  Subscription? get mainSub => subs.where((s) => !s.isManual).firstOrNull ?? subs.firstOrNull;

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
      await Core.start(buildXrayConfig(s, m), m);
    } catch (e) {
      conn = ConnState.off;
      lastError = 'Не удалось подключиться: $e';
      notifyListeners();
    }
  }

  /// Добавление из текста: ссылка подписки или ключи.
  Future<Subscription> addFromText(String text) async {
    final t = text.trim();
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
      manual = Subscription(id: id, title: '🔑 Мои ключи', url: null, servers: [], updatedAt: DateTime.now());
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
      s
        ..title = r.title
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
    if (!allServers.any((x) => x.id == selectedId)) selectedId = allServers.firstOrNull?.id;
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
  Future<void> pingSub(Subscription s) async {
    if (pinging) return;
    if (conn == ConnState.on || conn == ConnState.connecting) {
      lastError = 'Отключите VPN, чтобы проверить пинг';
      notifyListeners();
      return;
    }
    pinging = true;
    notifyListeners();
    try {
      final d = await Core.ping(s.servers.map((e) => e.outbound).toList());
      for (var i = 0; i < s.servers.length && i < d.length; i++) {
        s.servers[i].ping = d[i];
      }
      await _save();
    } finally {
      pinging = false;
      notifyListeners();
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
