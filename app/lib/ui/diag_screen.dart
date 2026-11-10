import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../core.dart';
import '../models.dart';
import '../sub_service.dart' show appVersion;
import 'kit.dart';

/// «Диагностика»: проверяет по шагам, где теряется связь, и даёт скопировать отчёт.
class DiagPage extends StatefulWidget {
  final AppState st;
  const DiagPage({super.key, required this.st});
  @override
  State<DiagPage> createState() => _DiagPageState();
}

class _Row {
  final String title;
  String value = '…';
  bool? ok;
  _Row(this.title);
}

class _DiagPageState extends State<DiagPage> {
  final rows = <_Row>[];
  String log = '';
  bool running = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  _Row _add(String t) {
    final r = _Row(t);
    setState(() => rows.add(r));
    return r;
  }

  void _set(_Row r, String v, bool? ok) {
    if (!mounted) return;
    setState(() {
      r.value = v;
      r.ok = ok;
    });
  }

  Future<void> _run() async {
    if (running) return;
    setState(() {
      running = true;
      rows.clear();
      log = '';
    });
    final st = widget.st;
    final on = st.conn == ConnState.on;
    final s = st.selected;

    _set(
      _add('Устройство'),
      '${Platform.operatingSystem} ${Platform.operatingSystemVersion} · Netro $appVersion',
      null,
    );
    _set(_add('VPN'), on ? 'включён' : st.conn.name, on ? true : null);

    if (s == null) {
      _set(_add('Сервер'), 'не выбран', false);
    } else {
      final ep = Core.endpoint(s.outbound);
      _set(
        _add('Сервер'),
        '${s.name} · ${ep == null ? '?' : '${ep.$1}:${ep.$2}'}',
        null,
      );

      if (ep != null && InternetAddress.tryParse(ep.$1) == null) {
        final r = _add('DNS адреса сервера');
        final sw = Stopwatch()..start();
        try {
          final a = await InternetAddress.lookup(ep.$1)
              .timeout(const Duration(seconds: 6));
          _set(
            r,
            '${a.map((e) => e.address).take(2).join(', ')} · ${sw.elapsedMilliseconds} мс',
            a.isNotEmpty,
          );
        } catch (e) {
          _set(r, 'не найден: $e', false);
        }
      }

      final t = _add('Связь с сервером (TCP)');
      final ms = await Core.tcpPing(s.outbound, timeout: 5);
      _set(
        t,
        ms < 10000 ? '$ms мс' : (ms >= 11000 ? 'нет ответа' : 'ошибка'),
        ms < 10000,
      );

      final k = _add('Проверка ядром');
      if (on || st.conn == ConnState.connecting) {
        _set(k, 'пропущено — работает при выключенном VPN', null);
      } else {
        final res = await Core.pingDetail(
          s.outbound,
          url: st.settings.pingUrl,
          timeout: st.settings.pingTimeout,
        );
        _set(k, res, res.endsWith('мс'));
      }
    }

    if (on) {
      final h = _add('Интернет через VPN');
      final c = HttpClient()
        ..findProxy = ((_) => 'DIRECT')
        ..connectionTimeout = const Duration(seconds: 6);
      final sw = Stopwatch()..start();
      try {
        final rq = await c.getUrl(Uri.parse('https://cp.cloudflare.com/'));
        final rs = await rq.close().timeout(const Duration(seconds: 8));
        await rs.drain<void>();
        _set(
          h,
          'ответ ${rs.statusCode} · ${sw.elapsedMilliseconds} мс',
          rs.statusCode < 500,
        );
      } catch (e) {
        _set(h, 'нет связи: $e', false);
      } finally {
        c.close(force: true);
      }

      final i = _add('IP выхода');
      final ip = await Core.ipInfo();
      _set(
        i,
        ip == null ? 'не определён' : '${ip['ip']} · ${ip['country'] ?? ''}',
        ip != null,
      );

      if (Platform.isIOS) {
        final x = _add('VPN-расширение');
        final info = await Core.tunnelInfo();
        if (info == null) {
          _set(x, 'не отвечает', false);
        } else {
          _set(
            x,
            '${info['note'] ?? ''} · ↓${bytesText((info['rx'] as num?)?.toInt() ?? 0)} ↑${bytesText((info['tx'] as num?)?.toInt() ?? 0)}',
            true,
          );
          log = (info['log'] as String? ?? '').trim();
        }
      }
    }
    if (mounted) setState(() => running = false);
  }

  String get _report {
    final b = StringBuffer('Netro — диагностика\n');
    for (final r in rows) {
      b.writeln(
        '${r.ok == null ? '•' : (r.ok! ? '✓' : '✗')} ${r.title}: ${r.value}',
      );
    }
    if (log.isNotEmpty) b.writeln('\nЖурнал ядра:\n$log');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.bg,
        title: const Text('Диагностика'),
        actions: [
          IconButton(
            tooltip: 'Скопировать отчёт',
            onPressed: rows.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: _report));
                    toast(
                      context,
                      'Отчёт скопирован — отправьте его в поддержку',
                    );
                  },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Group(
            footer: running ? 'Проверяем…' : 'Если что-то не работает — скопируйте отчёт (кнопка вверху) и отправьте в поддержку.',
            children: [
              for (final r in rows)
                NavRow(
                  leading: Icon(
                    r.ok == null
                        ? Icons.circle_outlined
                        : (r.ok!
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded),
                    color: r.ok == null ? C.gray : (r.ok! ? C.green : C.red),
                    size: 22,
                  ),
                  title: r.title,
                  subtitle: r.value,
                ),
            ],
          ),
          if (log.isNotEmpty) ...[
            const SectionLabel('Журнал ядра'),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SelectableText(
                log,
                style: const TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 11,
                  color: C.gray,
                  height: 1.35,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Btn('Проверить ещё раз', busy: running, onTap: running ? null : _run),
        ],
      ),
    );
  }
}
