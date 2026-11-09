import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'actions.dart';
import 'kit.dart';

class HomeScreen extends StatefulWidget {
  final AppState st;
  final VoidCallback openServers, openSubs, openAdd;
  const HomeScreen({
    super.key,
    required this.st,
    required this.openServers,
    required this.openSubs,
    required this.openAdd,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.st.conn == ConnState.on && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String _elapsed() {
    final t = widget.st.connectedAt;
    if (t == null) return '00:00:00';
    final d = DateTime.now().difference(t);
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.inHours)}:${p(d.inMinutes % 60)}:${p(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.st;
    final sel = st.selected;
    final sub = st.mainSub;
    final on = st.conn == ConnState.on;
    final ing = st.conn == ConnState.connecting;

    return Stack(
      children: [
        // Мягкое свечение за кнопкой: синее — выключено, зелёное — подключено.
        Positioned(
          top: 120,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              height: 360,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.62,
                  colors: [
                    (on ? C.green : (ing ? C.orange : C.accent)).withValues(
                      alpha: on ? 0.20 : 0.12,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            LargeTitle(
              'Netro',
              actions: [
                IconAction(Icons.add_rounded, 'Добавить', widget.openAdd),
              ],
            ),
            const SizedBox(height: 10),
            Appear(
              child: sub == null
                  ? Pressable(
                      onTap: widget.openAdd,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: C.card,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            RowIcon(Icons.add_rounded, C.accent),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Добавьте подписку',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Ссылка из бота, ключ или QR-код',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: C.gray,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Chevron(),
                          ],
                        ),
                      ),
                    )
                  : _SubSummary(
                      sub: sub,
                      onTap: widget.openSubs,
                      onLong: () => showSubActions(context, st, sub),
                    ),
            ),
            SizedBox(
              height: 262,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PowerButton(on: on, connecting: ing, onTap: st.toggle),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Row(
                      key: ValueKey(st.conn),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: on ? C.green : (ing ? C.orange : C.chevron),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          on
                              ? 'Подключено'
                              : (ing ? 'Подключение…' : 'Не подключено'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    on ? _elapsed() : 'Нажмите, чтобы подключиться',
                    style: const TextStyle(
                      fontSize: 13,
                      color: C.gray,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: on
                  ? _IpCard(st: st)
                  : const SizedBox(width: double.infinity),
            ),
            if (!Platform.isIOS) ...[
              Segmented<ConnMode>(
                items: {
                  ConnMode.tun: 'Туннель (VPN)',
                  ConnMode.proxy: Platform.isWindows
                      ? 'Системный прокси'
                      : 'Только прокси',
                },
                value: st.mode,
                onChanged: st.setMode,
              ),
              const SizedBox(height: 14),
            ],
            if (sel != null)
              Pressable(
                onTap: widget.openServers,
                onLongPress: () => showServerActions(context, st, sel),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: C.card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Flag(
                          sel.country,
                          size: 34,
                          emoji: sel.emoji,
                          key: ValueKey(sel.id),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sel.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${st.subOf(sel)?.title ?? ''} · ${sel.protocol}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: C.gray,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (sel.ping != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            pingText(sel.ping),
                            style: TextStyle(
                              fontSize: 14,
                              color: pingColor(sel.ping),
                            ),
                          ),
                        ),
                      const Chevron(),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    Icons.south_rounded,
                    'Загрузка',
                    on ? speedText(st.downBps) : '—',
                    on ? bytesText(st.sessionDown) : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Stat(
                    Icons.north_rounded,
                    'Отдача',
                    on ? speedText(st.upBps) : '—',
                    on ? bytesText(st.sessionUp) : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _IpCard extends StatelessWidget {
  final AppState st;
  const _IpCard({required this.st});
  @override
  Widget build(BuildContext context) {
    final ip = st.ip;
    final code = (ip?['country_code'] as String?)?.toLowerCase() ?? '';
    final place = [
      ip?['city'],
      ip?['country'],
    ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Pressable(
        onTap: st.refreshIp,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: C.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.green.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              st.ipLoading || ip == null
                  ? const SizedBox(
                      width: 26,
                      height: 26,
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Flag(code, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ip == null
                          ? (st.ipLoading
                                ? 'Проверяю IP…'
                                : 'IP не определён — нажмите')
                          : '${ip['ip']}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (place.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Ваш IP сейчас: $place',
                        style: const TextStyle(fontSize: 12.5, color: C.gray),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.refresh_rounded, color: C.gray, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final String? total;
  const _Stat(this.icon, this.label, this.value, this.total);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: C.gray),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: C.gray)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        if (total != null) ...[
          const SizedBox(height: 2),
          Text(
            'за сессию $total',
            style: const TextStyle(fontSize: 11.5, color: C.gray),
          ),
        ],
      ],
    ),
  );
}

class _SubSummary extends StatelessWidget {
  final Subscription sub;
  final VoidCallback onTap, onLong;
  const _SubSummary({
    required this.sub,
    required this.onTap,
    required this.onLong,
  });

  @override
  Widget build(BuildContext context) {
    double? progress;
    if (sub.expire != null &&
        sub.expire!.difference(DateTime.now()).inDays <= 3650) {
      final left = sub.expire!.difference(DateTime.now()).inHours / 24;
      progress = (left / 30).clamp(0.0, 1.0);
    }
    final traffic = (sub.totalBytes ?? 0) > 0
        ? '${bytesText(sub.usedBytes ?? 0)} из ${bytesText(sub.totalBytes!)}'
        : 'безлимит';
    return Pressable(
      onTap: onTap,
      onLongPress: onLong,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SubAvatar(sub.title),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleWithoutEmoji(sub.title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        daysLeftText(sub.expire),
                        style: const TextStyle(fontSize: 13, color: C.gray),
                      ),
                    ],
                  ),
                ),
                const Chevron(),
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 4,
                    backgroundColor: const Color(0xFF2A2A2E),
                    color: progress! < 0.15 ? C.orange : C.accent,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                children: [
                  Text(
                    'Трафик: $traffic',
                    style: const TextStyle(fontSize: 12, color: C.gray),
                  ),
                  const Spacer(),
                  Text(
                    '${sub.servers.length} ${plural(sub.servers.length, 'сервер', 'сервера', 'серверов')}',
                    style: const TextStyle(fontSize: 12, color: C.gray),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PowerButton extends StatefulWidget {
  final bool on, connecting;
  final VoidCallback onTap;
  const _PowerButton({
    required this.on,
    required this.connecting,
    required this.onTap,
  });
  @override
  State<_PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<_PowerButton>
    with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    if (widget.connecting) {
      _spin.repeat();
    } else {
      _spin.stop();
    }
    if (widget.on) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant _PowerButton old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.on;
    return Semantics(
      button: true,
      label: on ? 'Отключить' : 'Подключить',
      child: SizedBox(
        width: 190,
        height: 190,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (on)
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, _) {
                  final t = _pulse.value;
                  return Container(
                    width: 150 + 40 * t,
                    height: 150 + 40 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: C.green.withValues(alpha: 0.35 * (1 - t)),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
            if (widget.connecting)
              RotationTransition(
                turns: _spin,
                child: const SizedBox(
                  width: 164,
                  height: 164,
                  child: CircularProgressIndicator(
                    value: 0.25,
                    strokeWidth: 3,
                    color: C.accent,
                  ),
                ),
              ),
            Pressable(
              onTap: widget.onTap,
              scale: 0.94,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? C.green.withValues(alpha: 0.10) : C.card,
                  border: Border.all(
                    color: on ? C.green : const Color(0xFF2C2C2E),
                    width: 3,
                  ),
                  boxShadow: on
                      ? [
                          BoxShadow(
                            color: C.green.withValues(alpha: 0.25),
                            blurRadius: 30,
                          ),
                        ]
                      : const [],
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  size: 58,
                  color: on ? C.green : (widget.connecting ? C.accent : C.text),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
