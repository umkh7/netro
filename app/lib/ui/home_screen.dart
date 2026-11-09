import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'kit.dart';

class HomeScreen extends StatefulWidget {
  final AppState st;
  final VoidCallback openServers, openSubs, openAdd, openSettings;
  const HomeScreen(
      {super.key,
      required this.st,
      required this.openServers,
      required this.openSubs,
      required this.openAdd,
      required this.openSettings});

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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        LargeTitle('Netro', leading: Image.asset('assets/netro_glyph.png', width: 30, height: 30), actions: [
          IconAction(Icons.add_rounded, 'Добавить', widget.openAdd),
          IconAction(Icons.settings_outlined, 'Настройки', widget.openSettings),
        ]),
        const SizedBox(height: 10),
        if (sub == null)
          NCard(
            onTap: widget.openAdd,
            padding: const EdgeInsets.all(16),
            child: const Row(children: [
              Icon(Icons.add_circle_outline_rounded, color: C.accent),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Добавьте подписку', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(height: 2),
                  Text('Ссылка, ключ или QR-код', style: TextStyle(fontSize: 13, color: C.gray)),
                ]),
              ),
              Chevron(),
            ]),
          )
        else
          _SubSummary(sub: sub, onTap: widget.openSubs),
        SizedBox(
          height: 270,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            _PowerButton(on: on, connecting: ing, onTap: st.toggle),
            const SizedBox(height: 20),
            Row(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? C.green : (ing ? C.orange : C.chevron),
                ),
              ),
              const SizedBox(width: 8),
              Text(on ? 'Подключено' : (ing ? 'Подключение…' : 'Не подключено'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            Text(on ? _elapsed() : 'Нажмите, чтобы подключиться',
                style: const TextStyle(
                    fontSize: 13, color: C.gray, fontFeatures: [FontFeature.tabularFigures()])),
          ]),
        ),
        if (!Platform.isIOS)
          Segmented<ConnMode>(
          items: {ConnMode.tun: 'Туннель (VPN)', ConnMode.proxy: Platform.isWindows ? 'Системный прокси' : 'Только прокси'},
          value: st.mode,
          onChanged: st.setMode,
        ),
        const SizedBox(height: 14),
        if (sel != null)
          NCard(
            onTap: widget.openServers,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Flag(sel.country, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(sel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('${st.subOf(sel)?.title ?? ''} · ${sel.protocol}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: C.gray)),
                ]),
              ),
              if (sel.ping != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(pingText(sel.ping),
                      style: TextStyle(fontSize: 14, color: pingColor(sel.ping))),
                ),
              const Chevron(),
            ]),
          ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _Speed(Icons.south_rounded, on ? speedText(st.downBps) : '0 бит/с'),
          _Speed(Icons.north_rounded, on ? speedText(st.upBps) : '0 бит/с'),
        ]),
      ],
    );
  }
}

class _Speed extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Speed(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 15, color: C.gray),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                fontSize: 13, color: C.gray, fontFeatures: [FontFeature.tabularFigures()])),
      ]);
}

class _SubSummary extends StatelessWidget {
  final Subscription sub;
  final VoidCallback onTap;
  const _SubSummary({required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    double? progress;
    if (sub.expire != null) {
      final left = sub.expire!.difference(DateTime.now()).inHours / 24;
      progress = (left / 30).clamp(0.0, 1.0);
    }
    final traffic = (sub.totalBytes ?? 0) > 0
        ? '${bytesText(sub.usedBytes ?? 0)} из ${bytesText(sub.totalBytes!)}'
        : 'безлимит';
    return NCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SubAvatar(sub.title),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titleWithoutEmoji(sub.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 1),
              Text(daysLeftText(sub.expire), style: const TextStyle(fontSize: 13, color: C.gray)),
            ]),
          ),
          const Chevron(),
        ]),
        if (progress != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: const Color(0xFF2A2A2E),
              color: progress < 0.15 ? C.orange : C.accent,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Row(children: [
            Text('Трафик: $traffic', style: const TextStyle(fontSize: 12, color: C.gray)),
            const Spacer(),
            Text('${sub.servers.length} ${plural(sub.servers.length, 'сервер', 'сервера', 'серверов')}',
                style: const TextStyle(fontSize: 12, color: C.gray)),
          ]),
        ),
      ]),
    );
  }
}

class _PowerButton extends StatefulWidget {
  final bool on, connecting;
  final VoidCallback onTap;
  const _PowerButton({required this.on, required this.connecting, required this.onTap});
  @override
  State<_PowerButton> createState() => _PowerButtonState();
}

class _PowerButtonState extends State<_PowerButton> with SingleTickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(covariant _PowerButton old) {
    super.didUpdateWidget(old);
    if (widget.connecting) {
      _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.on;
    return Semantics(
      button: true,
      label: on ? 'Отключить' : 'Подключить',
      child: SizedBox(
        width: 164,
        height: 164,
        child: Stack(alignment: Alignment.center, children: [
          if (widget.connecting)
            RotationTransition(
              turns: _spin,
              child: const SizedBox(
                width: 164,
                height: 164,
                child: CircularProgressIndicator(value: 0.25, strokeWidth: 3, color: C.accent),
              ),
            ),
          GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? C.green.withValues(alpha: 0.10) : C.card,
                border: Border.all(color: on ? C.green : const Color(0xFF2C2C2E), width: 3),
              ),
              child: Icon(Icons.power_settings_new_rounded,
                  size: 58, color: on ? C.green : (widget.connecting ? C.accent : C.text)),
            ),
          ),
        ]),
      ),
    );
  }
}
