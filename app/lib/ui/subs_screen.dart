import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../models.dart';
import 'kit.dart';

class SubsScreen extends StatelessWidget {
  final AppState st;
  final VoidCallback openAdd;
  const SubsScreen({super.key, required this.st, required this.openAdd});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        LargeTitle('Подписки', actions: [IconAction(Icons.add_rounded, 'Добавить', openAdd)]),
        const SizedBox(height: 8),
        if (st.subs.isEmpty) ...[
          const SizedBox(height: 30),
          const Text('Подписок пока нет',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          Btn('Добавить подписку', primary: true, onTap: openAdd),
        ],
        for (final s in st.subs) ...[
          _SubCard(st: st, sub: s),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _SubCard extends StatelessWidget {
  final AppState st;
  final Subscription sub;
  const _SubCard({required this.st, required this.sub});

  Widget _row(String k, String v, {bool last = false}) => Column(children: [
        SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text(k, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(v,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, color: C.gray)),
              ),
            ]),
          ),
        ),
        if (!last) const Hairline(),
      ]);

  Future<void> _confirmRemove(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: C.field,
        title: const Text('Удалить подписку?'),
        content: Text('«${sub.title}» и её серверы пропадут из приложения.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Удалить', style: TextStyle(color: C.red))),
        ],
      ),
    );
    if (ok == true) await st.remove(sub);
  }

  @override
  Widget build(BuildContext context) {
    final busy = st.refreshing.contains(sub.id);
    final expired = sub.expire != null && sub.expire!.isBefore(DateTime.now());
    final traffic = (sub.totalBytes ?? 0) > 0
        ? '${bytesText(sub.usedBytes ?? 0)} из ${bytesText(sub.totalBytes!)}'
        : (sub.usedBytes != null ? '${bytesText(sub.usedBytes!)} · без лимита' : 'без лимита');
    double? progress;
    if (sub.expire != null) {
      progress = (sub.expire!.difference(DateTime.now()).inHours / 24 / 30).clamp(0.0, 1.0);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      NCard(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              SubAvatar(sub.title, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titleWithoutEmoji(sub.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    sub.isManual ? '${sub.servers.length} ${plural(sub.servers.length, 'ключ', 'ключа', 'ключей')}' : (expired ? 'Истекла' : 'Активна'),
                    style: TextStyle(fontSize: 13, color: sub.isManual ? C.gray : (expired ? C.red : C.green)),
                  ),
                ]),
              ),
              PopupMenuButton<String>(
                color: C.field,
                icon: const Icon(Icons.more_horiz_rounded, color: C.gray),
                onSelected: (v) async {
                  if (v == 'copy' && sub.url != null) {
                    await Clipboard.setData(ClipboardData(text: sub.url!));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Ссылка скопирована')));
                    }
                  }
                  if (v == 'del' && context.mounted) await _confirmRemove(context);
                },
                itemBuilder: (_) => [
                  if (!sub.isManual) const PopupMenuItem(value: 'copy', child: Text('Скопировать ссылку')),
                  const PopupMenuItem(value: 'del', child: Text('Удалить', style: TextStyle(color: C.red))),
                ],
              ),
            ]),
          ),
          const Hairline(),
          if (!sub.isManual) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(children: [
                Row(children: [
                  const Text('Срок', style: TextStyle(fontSize: 15)),
                  const Spacer(),
                  Text(daysLeftText(sub.expire).replaceFirst('Осталось ', ''),
                      style: const TextStyle(fontSize: 15, color: C.gray)),
                ]),
                if (progress != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: const Color(0xFF2A2A2E),
                        color: progress < 0.15 ? C.orange : C.accent),
                  ),
                ],
              ]),
            ),
            const Hairline(),
            _row('Трафик', traffic),
            _row('Серверы', '${sub.servers.length}'),
            _row('Обновлено', agoText(sub.updatedAt)),
            SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 10),
                child: Row(children: [
                  const Text('Автообновление', style: TextStyle(fontSize: 15)),
                  const Spacer(),
                  Switch(
                    value: sub.autoUpdate,
                    onChanged: (_) => st.toggleAuto(sub),
                    activeTrackColor: C.green,
                    activeThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFF39393D),
                    inactiveThumbColor: Colors.white,
                    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                  ),
                ]),
              ),
            ),
          ] else
            for (var i = 0; i < sub.servers.length; i++)
              _row(sub.servers[i].name, sub.servers[i].protocol, last: i == sub.servers.length - 1),
        ]),
      ),
      if (!sub.isManual) ...[
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Btn('Обновить', busy: busy, onTap: () => st.refresh(sub))),
          if (sub.webPageUrl != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Btn('Продлить',
                  primary: true,
                  onTap: () => launchUrl(Uri.parse(sub.webPageUrl!), mode: LaunchMode.externalApplication)),
            ),
          ],
        ]),
      ],
    ]);
  }
}
