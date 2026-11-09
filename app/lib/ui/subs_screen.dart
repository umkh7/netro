import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../models.dart';
import 'actions.dart';
import 'kit.dart';

class SubsScreen extends StatelessWidget {
  final AppState st;
  final VoidCallback openAdd;
  const SubsScreen({super.key, required this.st, required this.openAdd});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: C.accent,
      backgroundColor: C.field,
      onRefresh: st.refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          LargeTitle(
            'Подписки',
            actions: [IconAction(Icons.add_rounded, 'Добавить', openAdd)],
          ),
          const SizedBox(height: 8),
          if (st.subs.isEmpty) ...[
            const SizedBox(height: 50),
            const Appear(
              child: Icon(Icons.layers_outlined, size: 56, color: C.chevron),
            ),
            const SizedBox(height: 14),
            const Text(
              'Подписок пока нет',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Скопируйте ссылку в боте и нажмите «Добавить»',
              textAlign: TextAlign.center,
              style: TextStyle(color: C.gray),
            ),
            const SizedBox(height: 22),
            Btn('Добавить подписку', primary: true, onTap: openAdd),
          ],
          for (var i = 0; i < st.subs.length; i++) ...[
            Appear(
              index: i,
              child: _SubCard(st: st, sub: st.subs[i]),
            ),
            const SizedBox(height: 16),
          ],
          if (st.subs.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Потяните вниз, чтобы обновить все подписки',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: C.gray),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubCard extends StatelessWidget {
  final AppState st;
  final Subscription sub;
  const _SubCard({required this.st, required this.sub});

  Widget _row(String k, String v) => SizedBox(
    height: 44,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(k, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, color: C.gray),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final busy = st.refreshing.contains(sub.id);
    final expired = sub.expire != null && sub.expire!.isBefore(DateTime.now());
    final traffic = (sub.totalBytes ?? 0) > 0
        ? '${bytesText(sub.usedBytes ?? 0)} из ${bytesText(sub.totalBytes!)}'
        : (sub.usedBytes != null
              ? '${bytesText(sub.usedBytes!)} · без лимита'
              : 'без лимита');
    double? progress;
    if (sub.expire != null) {
      progress = (sub.expire!.difference(DateTime.now()).inHours / 24 / 30)
          .clamp(0.0, 1.0);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: C.card,
            child: Column(
              children: [
                InkWell(
                  onTap: () => showSubActions(context, st, sub),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    child: Row(
                      children: [
                        SubAvatar(sub.title, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titleWithoutEmoji(sub.title),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                sub.isManual
                                    ? '${sub.servers.length} ${plural(sub.servers.length, 'ключ', 'ключа', 'ключей')}'
                                    : (expired
                                          ? 'Истекла'
                                          : 'Активна · ${sub.host}'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: sub.isManual
                                      ? C.gray
                                      : (expired ? C.red : C.green),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.more_horiz_rounded, color: C.gray),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
                const Hairline(),
                if (!sub.isManual) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text('Срок', style: TextStyle(fontSize: 15)),
                            const Spacer(),
                            Text(
                              daysLeftText(sub.expire)
                                  .replaceFirst('Осталось ', ''),
                              style: const TextStyle(
                                fontSize: 15,
                                color: C.gray,
                              ),
                            ),
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
                      ],
                    ),
                  ),
                  const Hairline(),
                  _row('Трафик', traffic),
                  const Hairline(),
                  _row('Серверы', '${sub.servers.length}'),
                  const Hairline(),
                  _row('Обновлено', agoText(sub.updatedAt)),
                  const Hairline(),
                  SwitchRow(
                    title: 'Автообновление',
                    subtitle: 'Раз в час при запуске приложения',
                    value: sub.autoUpdate,
                    onChanged: (_) => st.toggleAuto(sub),
                  ),
                ] else
                  for (var i = 0; i < sub.servers.length; i++) ...[
                    NavRow(
                      leading: Flag(
                        sub.servers[i].country,
                        emoji: sub.servers[i].emoji,
                      ),
                      title: sub.servers[i].name,
                      subtitle: sub.servers[i].protocol,
                      onTap: () =>
                          showServerActions(context, st, sub.servers[i]),
                    ),
                    if (i < sub.servers.length - 1) const Hairline(indent: 56),
                  ],
              ],
            ),
          ),
        ),
        if (!sub.isManual) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Btn(
                  'Обновить',
                  busy: busy,
                  onTap: () => st.refresh(sub),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: sub.webPageUrl != null
                    ? Btn(
                        'Продлить',
                        primary: true,
                        onTap: () => launchUrl(
                          Uri.parse(sub.webPageUrl!),
                          mode: LaunchMode.externalApplication,
                        ),
                      )
                    : Btn(
                        'Действия',
                        onTap: () => showSubActions(context, st, sub),
                      ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
