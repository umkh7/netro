import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../settings.dart';
import 'actions.dart';
import 'kit.dart';

class ServersScreen extends StatefulWidget {
  final AppState st;
  final VoidCallback openAdd;
  const ServersScreen({super.key, required this.st, required this.openAdd});
  @override
  State<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends State<ServersScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final st = widget.st;
    if (st.subs.isEmpty) {
      return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        const LargeTitle('Серверы'),
        const SizedBox(height: 60),
        const Appear(child: Icon(Icons.public_rounded, size: 56, color: C.chevron)),
        const SizedBox(height: 14),
        const Text('Пока нет серверов',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text('Добавьте подписку из бота — серверы появятся здесь',
            textAlign: TextAlign.center, style: TextStyle(color: C.gray)),
        const SizedBox(height: 22),
        Btn('Добавить подписку', primary: true, onTap: widget.openAdd),
      ]);
    }

    final cur = st.subs.firstWhere((s) => s.id == st.viewSubId, orElse: () {
      final sel = st.selected;
      return (sel != null ? st.subOf(sel) : null) ?? st.subs.first;
    });
    final q = _q.toLowerCase();
    final list = st.sorted(cur).where((s) => q.isEmpty || s.name.toLowerCase().contains(q)).toList();
    final best = st.bestOf(cur);

    return RefreshIndicator(
      color: C.accent,
      backgroundColor: C.field,
      onRefresh: () => cur.isManual ? st.pingSub(cur) : st.refresh(cur),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          LargeTitle('Серверы', actions: [
            PopupMenuButton<SortMode>(
              tooltip: 'Сортировка',
              color: C.field,
              icon: const Icon(Icons.sort_rounded, color: C.accent),
              initialValue: st.settings.sort,
              onSelected: st.setSort,
              itemBuilder: (_) => const [
                PopupMenuItem(value: SortMode.list, child: Text('Как в подписке')),
                PopupMenuItem(value: SortMode.ping, child: Text('По пингу')),
                PopupMenuItem(value: SortMode.name, child: Text('По названию')),
              ],
            ),
            IconAction(Icons.add_rounded, 'Добавить', widget.openAdd),
          ]),
          const SizedBox(height: 8),
          TextField(
            onChanged: (v) => setState(() => _q = v),
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Поиск по странам',
              hintStyle: const TextStyle(color: C.gray),
              prefixIcon: const Icon(Icons.search_rounded, color: C.gray, size: 20),
              filled: true,
              fillColor: C.field,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: st.subs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = st.subs[i];
                final on = s.id == cur.id;
                return Pressable(
                  onTap: () => setState(() => st.viewSubId = s.id),
                  onLongPress: () => showSubActions(context, st, s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? C.text : C.field,
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Row(children: [
                      Text(s.title,
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600, color: on ? Colors.black : C.text)),
                      const SizedBox(width: 6),
                      Text('${s.servers.length}',
                          style: TextStyle(
                              fontSize: 12, color: (on ? Colors.black : C.text).withValues(alpha: 0.55))),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _ActionChip(
                icon: Icons.speed_rounded,
                label: st.pinging ? 'Проверяю…' : 'Проверить пинг',
                busy: st.pinging,
                onTap: st.pinging ? null : () => st.pingSub(cur),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionChip(
                icon: Icons.bolt_rounded,
                label: best == null ? 'Самый быстрый' : 'Быстрый: ${best.name}',
                color: C.orange,
                onTap: st.pinging ? null : () => st.selectBest(cur),
              ),
            ),
          ]),
          SectionLabel(cur.isManual ? 'Добавлены вручную' : cur.host,
              right: cur.isManual ? null : 'обновлено ${agoText(cur.updatedAt)}'),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a), child: c),
            ),
            child: ClipRRect(
              key: ValueKey('${cur.id}-${st.settings.sort.name}-$q'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                color: C.card,
                child: Column(children: [
                  for (var i = 0; i < list.length; i++) ...[
                    _ServerRow(
                      s: list[i],
                      selected: list[i].id == st.selected?.id,
                      best: best?.id == list[i].id,
                      onTap: () => st.select(list[i]),
                      onLong: () => showServerActions(context, st, list[i]),
                    ),
                    if (i < list.length - 1) const Hairline(indent: 56),
                  ],
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('Ничего не найдено', style: TextStyle(color: C.gray)),
                    ),
                ]),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text('Удерживайте сервер — копировать ключ, QR-код, подключиться',
                style: TextStyle(fontSize: 12.5, color: C.gray)),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final bool busy;
  const _ActionChip({required this.icon, required this.label, this.onTap, this.color = C.accent, this.busy = false});
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            busy
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                : Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      );
}

class _ServerRow extends StatelessWidget {
  final Server s;
  final bool selected, best;
  final VoidCallback onTap, onLong;
  const _ServerRow(
      {required this.s, required this.selected, required this.best, required this.onTap, required this.onLong});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? C.accent.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLong,
        child: SizedBox(
          height: 62,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Flag(s.country),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(s.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
                      ),
                      if (best) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.bolt_rounded, size: 15, color: C.orange),
                      ],
                    ]),
                    const SizedBox(height: 1),
                    Text(s.protocol, style: const TextStyle(fontSize: 12, color: C.gray)),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: s.ping == null
                    ? const SizedBox.shrink()
                    : Text(pingText(s.ping),
                        key: ValueKey(s.ping),
                        style: TextStyle(
                            fontSize: 14,
                            color: pingColor(s.ping),
                            fontFeatures: const [FontFeature.tabularFigures()])),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 20,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  scale: selected ? 1 : 0,
                  child: const Icon(Icons.check_rounded, color: C.accent, size: 22),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
