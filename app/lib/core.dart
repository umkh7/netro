import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'models.dart';

/// Мост к нативному ядру Xray (libXray) и VPN-сервису платформы.
class Core {
  static const _ch = MethodChannel('netro/core');
  static const _ev = EventChannel('netro/state');

  static Stream<ConnState>? _states;

  static Stream<ConnState> get states => _states ??= _ev
      .receiveBroadcastStream()
      .map((e) => switch (e as String) {
            'connecting' => ConnState.connecting,
            'on' => ConnState.on,
            'error' => ConnState.error,
            _ => ConnState.off,
          })
      .asBroadcastStream();

  static Future<Map<String, dynamic>> _invoke(String method, Map<String, dynamic> payload) async {
    final req = jsonEncode({'apiVersion': 3, 'method': method, 'payload': payload});
    final res = await _ch.invokeMethod<String>('invoke', req);
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
  static Future<List<int>> ping(List<Map<String, dynamic>> outbounds) async {
    final out = <int>[];
    for (var i = 0; i < outbounds.length; i += 5) {
      final chunk = outbounds.sublist(i, i + 5 > outbounds.length ? outbounds.length : i + 5);
      final cfgs = chunk.map((o) {
        final ob = Map<String, dynamic>.from(o)..['tag'] = 'proxy';
        return {'xrayJson': jsonEncode({'outbounds': [ob]})};
      }).toList();
      try {
        final d = await _invoke('pingBatch', {
          'configs': cfgs,
          'timeout': 5,
          'url': 'https://cp.cloudflare.com/',
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
  static Future<void> start(Map<String, dynamic> config, ConnMode mode) async {
    await _ch.invokeMethod('start', {
      'config': jsonEncode(config),
      'mode': mode.name,
    });
  }

  static Future<void> stop() => _ch.invokeMethod('stop');

  static Future<ConnState> current() async {
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
    try {
      final c = await HttpClientLite.get('http://127.0.0.1:$metricsPort/debug/vars');
      final j = jsonDecode(c) as Map<String, dynamic>;
      final p = (((j['stats'] as Map?)?['outbound'] as Map?)?['proxy'] as Map?);
      if (p == null) return null;
      return [(p['downlink'] as num?)?.toInt() ?? 0, (p['uplink'] as num?)?.toInt() ?? 0];
    } catch (_) {
      return null;
    }
  }

  static const metricsPort = 10813;
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
