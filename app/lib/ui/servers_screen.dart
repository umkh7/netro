import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
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
        const SizedBox(height: 40),
        const Icon(Icons.public_off_rounded, size: 48, color: C.chevron),
        const SizedBox(height: 12),
        const Text('Пока нет серверов',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Добавьте подписку или ключ',
            textAlign: TextAlign.center, style: TextStyle(color: C.gray)),
        const SizedBox(height: 20),
        Btn('Добавить', primary: true, onTap: widget.openAdd),
      ]);
    }

    final cur = st.subs.firstWhere((s) => s.id == st.viewSubId,
        orElse: () {
          final sel = st.selected;
          return (sel != null ? st.subOf(sel) : null) ?? st.subs.first;
        });
    final q = _q.toLowerCase();
    final list = cur.servers.where((s) => q.isEmpty || s.name.toLowerCase().contains(q)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        LargeTitle('Серверы', actions: [
          TextButton(
            onPressed: st.pinging ? null : () => st.pingSub(cur),
            child: st.pinging
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.accent))
                : const Text('Пинг', style: TextStyle(fontSize: 16, color: C.accent)),
          ),
        ]),
        const SizedBox(height: 8),
        TextField(
          onChanged: (v) => setState(() => _q = v),
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Поиск',
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
              return GestureDetector(
                onTap: () => setState(() => st.viewSubId = s.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
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
                        style: TextStyle(fontSize: 12, color: (on ? Colors.black : C.text).withValues(alpha: 0.55))),
                  ]),
                ),
              );
            },
          ),
        ),
        SectionLabel(cur.isManual ? 'Добавлены вручную' : cur.host,
            right: cur.isManual ? null : 'обновлено ${agoText(cur.updatedAt)}'),
        NCard(
          child: Column(children: [
            for (var i = 0; i < list.length; i++) ...[
              _ServerRow(
                s: list[i],
                selected: list[i].id == st.selected?.id,
                onTap: () => st.select(list[i]),
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
      ],
    );
  }
}

class _ServerRow extends StatelessWidget {
  final Server s;
  final bool selected;
  final VoidCallback onTap;
  const _ServerRow({required this.s, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 60,
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
                  Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 1),
                  Text(s.protocol, style: const TextStyle(fontSize: 12, color: C.gray)),
                ],
              ),
            ),
            if (s.ping != null)
              Text(pingText(s.ping),
                  style: TextStyle(
                      fontSize: 14,
                      color: pingColor(s.ping),
                      fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(width: 10),
            SizedBox(
              width: 20,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: selected ? 1 : 0,
                child: const Icon(Icons.check_rounded, color: C.accent, size: 22),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
