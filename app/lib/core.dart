import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'config_builder.dart' show httpPort;
import 'core_windows.dart' as win;
import 'models.dart';

/// Мост к нативному ядру Xray (libXray) и VPN-сервису платформы.
class Core {
  static const _ch = MethodChannel('netro/core');
  static const _ev = EventChannel('netro/state');

  static Stream<ConnState>? _states;

  static bool get _isWin => Platform.isWindows;
  static final _winStates = StreamController<ConnState>.broadcast();
  static ConnState _winState = ConnState.off;
  static void _setWin(ConnState s) {
    _winState = s;
    _winStates.add(s);
  }

  static Stream<ConnState> get states => _isWin
      ? _winStates.stream
      : _states ??= _ev
            .receiveBroadcastStream()
            .map(
              (e) => switch (e as String) {
                'connecting' => ConnState.connecting,
                'on' => ConnState.on,
                'error' => ConnState.error,
                _ => ConnState.off,
              },
            )
            .asBroadcastStream();

  static Future<Map<String, dynamic>> _invoke(
    String method,
    Map<String, dynamic> payload,
  ) async {
    final req = jsonEncode({
      'apiVersion': 3,
      'method': method,
      'payload': payload,
    });
    final res = _isWin
        ? await win.winInvoke(req)
        : await _ch.invokeMethod<String>('invoke', req);
    final m = jsonDecode(res ?? '{}') as Map<String, dynamic>;
    if (m['success'] != true) {
      throw CoreError((m['error'] as String?) ?? 'Ошибка ядра');
    }
    return (m['data'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// Ссылки vless/vmess/trojan/ss/hy2 (или Xray JSON) → outbounds.
  static Future<List<Map<String, dynamic>>> convertLinks(String text) async {
    final d = await _invoke('convertShareLinksToXrayJson', {'text': text});
    return ((d['outbounds'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Пинг пачками по 5 (ограничение libXray). Возвращает мс; 10000/11000 — ошибка.
  static Future<List<int>> ping(
    List<Map<String, dynamic>> outbounds, {
    String url = 'https://cp.cloudflare.com/',
    int timeout = 5,
  }) async {
    final out = <int>[];
    for (var i = 0; i < outbounds.length; i += 5) {
      final chunk = outbounds.sublist(
        i,
        i + 5 > outbounds.length ? outbounds.length : i + 5,
      );
      final cfgs = chunk.map((o) {
        final ob = Map<String, dynamic>.from(o)..['tag'] = 'proxy';
        return {
          'xrayJson': jsonEncode({
            'outbounds': [ob],
          }),
        };
      }).toList();
      try {
        final d = await _invoke('pingBatch', {
          'configs': cfgs,
          'timeout': timeout,
          'url': url,
        });
        for (final r in (d['results'] as List? ?? [])) {
          out.add(((r as Map)['delay'] as num?)?.toInt() ?? 10000);
        }
      } catch (_) {
        out.addAll(List.filled(chunk.length, 10000));
      }
    }
    return out;
  }

  static Future<String> version() async {
    try {
      final d = await _invoke('xrayVersion', {});
      return (d['version'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Запуск. [config] — полный конфиг Xray без env (fd добавляет платформа).
  /// Ключ-ссылка (vless://…) для одного сервера — чтобы поделиться или показать QR.
  static Future<String?> shareLink(Map<String, dynamic> outbound) async {
    try {
      final d = await _invoke('convertXrayJsonToShareLinks', {
        'xrayJson': jsonEncode({
          'outbounds': [outbound],
        }),
      });
      final l = (d['links'] as String?)?.trim();
      return (l == null || l.isEmpty) ? null : l.split('\n').first;
    } catch (_) {
      return null;
    }
  }

  /// Android: установленные приложения для раздельного туннелирования.
  static Future<List<AppInfo>> installedApps() async {
    if (!Platform.isAndroid) return [];
    final r = await _ch.invokeMethod<List>('apps');
    return (r ?? [])
        .map(
          (e) => AppInfo(
            (e as Map)['pkg'] as String,
            e['name'] as String,
            e['system'] == true,
          ),
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// IP и страна выхода. На телефоне весь трафик и так идёт через VPN —
  /// спрашиваем напрямую (несколько сервисов сразу, кто ответит первым).
  /// На Windows в режиме прокси — через локальный прокси Netro.
  static Future<Map<String, dynamic>?> ipInfo() async {
    final viaProxy = _isWin && _winMode == ConnMode.proxy;
    Future<Map<String, dynamic>?> one(
      String url,
      Map<String, dynamic>? Function(Map<String, dynamic>) map,
    ) async {
      final c = HttpClient()
        ..findProxy = ((_) => viaProxy ? 'PROXY 127.0.0.1:$httpPort' : 'DIRECT')
        ..connectionTimeout = const Duration(seconds: 6);
      try {
        final rq = await c.getUrl(Uri.parse(url));
        rq.headers.set('User-Agent', 'Netro');
        final rs = await rq.close().timeout(const Duration(seconds: 8));
        final j = jsonDecode(
          await rs.transform(utf8.decoder).join(),
        ) as Map<String, dynamic>;
        return map(j);
      } catch (_) {
        return null;
      } finally {
        c.close(force: true);
      }
    }

    final tries = [
      one(
        'https://ipwho.is/?fields=ip,country,country_code,city,connection',
        (j) => j['ip'] == null ? null : j,
      ),
      one(
        'https://api.ip.sb/geoip',
        (j) => j['ip'] == null
            ? null
            : {
                'ip': j['ip'],
                'country': j['country'],
                'country_code': j['country_code'],
                'city': j['city'],
                'connection': {'isp': j['isp'] ?? j['organization']},
              },
      ),
      one(
        'https://ipapi.co/json/',
        (j) => j['ip'] == null
            ? null
            : {
                'ip': j['ip'],
                'country': j['country_name'],
                'country_code': j['country_code'],
                'city': j['city'],
                'connection': {'isp': j['org']},
              },
      ),
    ];
    final done = Completer<Map<String, dynamic>?>();
    var left = tries.length;
    for (final t in tries) {
      t.then((v) {
        if (v != null && !done.isCompleted) done.complete(v);
        if (--left == 0 && !done.isCompleted) done.complete(null);
      });
    }
    return done.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => null,
    );
  }

  /// iOS: сведения от VPN-расширения — счётчики utun и журнал ядра.
  static Future<Map<String, dynamic>?> tunnelInfo() async {
    if (!Platform.isIOS) return null;
    try {
      final r = await _ch.invokeMethod<String>('tunnel');
      if (r == null) return null;
      return jsonDecode(r) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Подробный пинг одного сервера — для диагностики (с текстом ошибки ядра).
  static Future<String> pingDetail(
    Map<String, dynamic> outbound, {
    String url = 'https://cp.cloudflare.com/',
    int timeout = 5,
  }) async {
    try {
      final ob = Map<String, dynamic>.from(outbound)..['tag'] = 'proxy';
      final d = await _invoke('pingBatch', {
        'configs': [
          {
            'xrayJson': jsonEncode({
              'outbounds': [ob],
            }),
          },
        ],
        'timeout': timeout,
        'url': url,
      });
      final r = ((d['results'] as List?) ?? []).firstOrNull as Map?;
      if (r == null) return 'нет ответа';
      final delay = (r['delay'] as num?)?.toInt() ?? 10000;
      if (delay < 10000) return '$delay мс';
      return '${delay >= 11000 ? 'таймаут' : 'ошибка'}: ${r['error'] ?? ''}';
    } catch (e) {
      return 'ошибка: $e';
    }
  }

  /// Адрес и порт сервера из outbound — для TCP-проверки.
  static (String, int)? endpoint(Map<String, dynamic> ob) {
    final s = (ob['settings'] as Map?) ?? {};
    Map? first(String k) {
      final l = s[k];
      return (l is List && l.isNotEmpty && l.first is Map)
          ? l.first as Map
          : null;
    }

    final m = first('vnext') ?? first('servers') ?? first('peers') ?? s;
    var host = (m['address'] ?? m['endpoint'] ?? '').toString();
    var port = (m['port'] as num?)?.toInt() ?? 0;
    if (port == 0 && host.contains(':')) {
      final i = host.lastIndexOf(':');
      port = int.tryParse(host.substring(i + 1)) ?? 0;
      host = host.substring(0, i).replaceAll('[', '').replaceAll(']', '');
    }
    if (host.isEmpty || port == 0) return null;
    return (host, port);
  }

  /// Время TCP-соединения с сервером, мс (11000 — не ответил).
  static Future<int> tcpPing(Map<String, dynamic> ob, {int timeout = 5}) async {
    final ep = endpoint(ob);
    if (ep == null) return 10000;
    final sw = Stopwatch()..start();
    try {
      final s = await Socket.connect(
        ep.$1,
        ep.$2,
        timeout: Duration(seconds: timeout),
      );
      sw.stop();
      s.destroy();
      return sw.elapsedMilliseconds.clamp(1, 9999);
    } on SocketException catch (e) {
      return (e.osError == null && sw.elapsed.inSeconds >= timeout)
          ? 11000
          : 10000;
    } catch (_) {
      return 11000;
    }
  }

  static Map<String, dynamic> _nativeExtra = {};

  /// Параметры для нативной части: DNS, раздельное туннелирование (Android).
  static void setNativeOptions({
    required String dns,
    required String split,
    required List<String> apps,
  }) {
    _nativeExtra = {'dns': dns, 'split': split, 'apps': apps};
  }

  static Future<void> start(Map<String, dynamic> config, ConnMode mode) async {
    if (_isWin) {
      _setWin(ConnState.connecting);
      try {
        await _invoke('runXray', {'xrayJson': jsonEncode(config)});
        if (mode == ConnMode.proxy)
          await win.setSystemProxy('127.0.0.1:$httpPort');
        _winMode = mode;
        _setWin(ConnState.on);
      } catch (e) {
        _setWin(ConnState.off);
        rethrow;
      }
      return;
    }
    await _ch.invokeMethod('start', {
      ..._nativeExtra,
      'config': jsonEncode(config),
      'mode': mode.name,
    });
  }

  static ConnMode? _winMode;

  static Future<void> stop() async {
    if (_isWin) {
      if (_winMode == ConnMode.proxy) await win.clearSystemProxy();
      _winMode = null;
      try {
        await _invoke('stopXray', {});
      } catch (_) {}
      _setWin(ConnState.off);
      return;
    }
    await _ch.invokeMethod('stop');
  }

  /// Windows: снять наш прокси, если приложение закрылось аварийно.
  static Future<void> cleanupStaleProxy() async {
    if (!_isWin) return;
    try {
      if (await win.ourProxyIsSet('127.0.0.1:$httpPort'))
        await win.clearSystemProxy();
    } catch (_) {}
  }

  static Future<ConnState> current() async {
    if (_isWin) return _winState;
    final s = await _ch.invokeMethod<String>('state');
    return switch (s) {
      'on' => ConnState.on,
      'connecting' => ConnState.connecting,
      _ => ConnState.off,
    };
  }

  /// Счётчики трафика outbound «proxy»: [скачано, отдано] байт с запуска.
  /// Берутся из встроенного сервера метрик Xray на 127.0.0.1:[metricsPort].
  static Future<List<int>?> trafficTotals() async {
    if (Platform.isIOS) {
      final t = await tunnelInfo();
      if (t == null) return null;
      return [(t['rx'] as num?)?.toInt() ?? 0, (t['tx'] as num?)?.toInt() ?? 0];
    }
    try {
      final c = await HttpClientLite.get(
        'http://127.0.0.1:$metricsPort/debug/vars',
      );
      final j = jsonDecode(c) as Map<String, dynamic>;
      final p = (((j['stats'] as Map?)?['outbound'] as Map?)?['proxy'] as Map?);
      if (p == null) return null;
      return [
        (p['downlink'] as num?)?.toInt() ?? 0,
        (p['uplink'] as num?)?.toInt() ?? 0,
      ];
    } catch (_) {
      return null;
    }
  }

  static const metricsPort = 10813;
}

class AppInfo {
  final String pkg, name;
  final bool system;
  AppInfo(this.pkg, this.name, this.system);
}

class HttpClientLite {
  static Future<String> get(String url) async {
    final c = HttpClient()
      ..findProxy = ((_) => 'DIRECT')
      ..connectionTimeout = const Duration(seconds: 2);
    try {
      final rq = await c.getUrl(Uri.parse(url));
      final rs = await rq.close().timeout(const Duration(seconds: 2));
      return await rs.transform(utf8.decoder).join();
    } finally {
      c.close(force: true);
    }
  }
}

class CoreError implements Exception {
  final String message;
  CoreError(this.message);
  @override
  String toString() => message;
}
