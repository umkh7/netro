import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../settings.dart';
import 'kit.dart';
import 'settings_screen.dart' show AppsPage;

/// Вкладка «Исключения»: сайты (и на Android — приложения), которые идут мимо VPN.
class BypassScreen extends StatefulWidget {
  final AppState st;
  const BypassScreen({super.key, required this.st});
  @override
  State<BypassScreen> createState() => _BypassScreenState();
}

class _BypassScreenState extends State<BypassScreen> {
  final _ctl = TextEditingController();
  final _focus = FocusNode();
  Timer? _apply;
  String? _err;

  Settings get s => widget.st.settings;

  /// Несколько правок подряд → одно переподключение.
  void _changed() {
    setState(() {});
    widget.st.saveSettings();
    _apply?.cancel();
    _apply = Timer(const Duration(milliseconds: 1200), widget.st.applySettings);
  }

  @override
  void dispose() {
    if (_apply?.isActive ?? false) {
      _apply!.cancel();
      widget.st.applySettings();
    }
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    final parts = _ctl.text
        .split(RegExp(r'[\s,;]+'))
        .where((e) => e.isNotEmpty);
    final ok = <String>[];
    for (final p in parts) {
      final d = normalizeDomain(p);
      if (d == null) {
        setState(
          () => _err =
              'Не похоже на адрес сайта: $p\nПример: umkh7.com или https://umkh7.com/test',
        );
        return;
      }
      ok.add(d);
    }
    if (ok.isEmpty) return;
    var added = 0;
    for (final d in ok) {
      if (!s.bypassDomains.contains(d)) {
        s.bypassDomains.insert(0, d);
        added++;
      }
    }
    _ctl.clear();
    _err = null;
    HapticFeedback.lightImpact();
    _changed();
    if (added == 0) toast(context, 'Уже в списке');
  }

  bool _presetOn((String, List<String>) p) =>
      p.$2.every(s.bypassDomains.contains);

  void _togglePreset((String, List<String>) p) {
    HapticFeedback.selectionClick();
    if (_presetOn(p)) {
      s.bypassDomains.removeWhere(p.$2.contains);
    } else {
      for (final d in p.$2.reversed) {
        if (!s.bypassDomains.contains(d)) s.bypassDomains.insert(0, d);
      }
    }
    _changed();
  }

  void _remove(String d) {
    s.bypassDomains.remove(d);
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final on = s.bypassOn;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        const LargeTitle('Исключения'),
        const SizedBox(height: 4),
        Appear(
          child: Group(
            footer:
                'VPN остаётся включённым, но эти сайты открываются напрямую, '
                'без VPN. Исключается весь сайт: все его страницы и поддомены — '
                'umkh7.com включает umkh7.com/test и m.umkh7.com.',
            children: [
              SwitchRow(
                leading: const RowIcon(Icons.alt_route_rounded, C.green),
                title: 'Сайты мимо VPN',
                subtitle: on
                    ? '${s.bypassDomains.length} ${plural(s.bypassDomains.length, 'сайт', 'сайта', 'сайтов')} в списке'
                    : 'Выключено — весь трафик через VPN',
                value: on,
                onChanged: (v) {
                  s.bypassOn = v;
                  _changed();
                },
              ),
            ],
          ),
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: on ? 1 : .45,
          child: IgnorePointer(
            ignoring: !on,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Appear(index: 1, child: _input()),
                Appear(index: 2, child: _presets()),
                Appear(index: 3, child: _list()),
              ],
            ),
          ),
        ),
        Appear(index: 4, child: _apps(context)),
      ],
    );
  }

  Widget _input() => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctl,
                focusNode: _focus,
                keyboardType: TextInputType.url,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
                onChanged: (_) {
                  if (_err != null) setState(() => _err = null);
                },
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'ozon.ru или ссылка',
                  hintStyle: const TextStyle(color: C.gray),
                  prefixIcon: const Icon(
                    Icons.language_rounded,
                    color: C.gray,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: C.card,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Pressable(
              onTap: _add,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: C.accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Добавить',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _err == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    _err!,
                    style: const TextStyle(color: C.red, fontSize: 13),
                  ),
                ),
        ),
      ],
    ),
  );

  Widget _presets() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionLabel('Быстро добавить'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final p in bypassPresets)
            Pressable(
              onTap: () => _togglePreset(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _presetOn(p)
                      ? C.accent.withValues(alpha: .18)
                      : C.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _presetOn(p) ? C.accent : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        _presetOn(p) ? Icons.check_rounded : Icons.add_rounded,
                        key: ValueKey(_presetOn(p)),
                        size: 16,
                        color: _presetOn(p) ? C.accent : C.gray,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(p.$1, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 14),
    ],
  );

  Widget _list() {
    final list = s.bypassDomains;
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Text(
          'Список пуст. Добавьте сайт выше или выберите готовый.',
          textAlign: TextAlign.center,
          style: TextStyle(color: C.gray, fontSize: 13.5),
        ),
      );
    }
    return Group(
      header: 'Мимо VPN · ${list.length}',
      footer: 'Смахните влево или нажмите ✕, чтобы убрать сайт.',
      children: [
        for (final d in list)
          Dismissible(
            key: ValueKey('bp-$d'),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => _remove(d),
            background: Container(
              color: C.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete_outline_rounded),
            ),
            child: NavRow(
              leading: _Favicon(d),
              title: d,
              subtitle: 'и все страницы сайта',
              trailing: IconButton(
                onPressed: () => _remove(d),
                icon: const Icon(Icons.close_rounded, color: C.gray, size: 20),
              ),
            ),
          ),
      ],
    );
  }

  Widget _apps(BuildContext context) {
    if (Platform.isAndroid) {
      return Group(
        header: 'Приложения',
        footer:
            'Выбранные приложения работают без VPN (например, банк), '
            'остальные — через VPN.',
        children: [
          NavRow(
            leading: const RowIcon(Icons.apps_rounded, Color(0xFF8E5CF7)),
            title: 'Приложения мимо VPN',
            value: switch (s.split) {
              SplitMode.off => 'Нет',
              SplitMode.exclude => '${s.splitApps.length}',
              SplitMode.include => 'Только ${s.splitApps.length}',
            },
            onTap: () async {
              await Navigator.of(context)
                  .push(smoothRoute(AppsPage(st: widget.st)));
              if (mounted) setState(() {});
            },
          ),
        ],
      );
    }
    return Group(
      header: 'Приложения',
      children: [
        NavRow(
          leading: const RowIcon(Icons.info_outline_rounded, Color(0xFF636366)),
          title: Platform.isIOS
              ? 'На iPhone нельзя выбрать приложения'
              : 'Выбор приложений — только на Android',
          subtitle: Platform.isIOS
              ? 'Apple не даёт VPN-приложениям пропускать отдельные приложения. '
                    'Добавьте сайты этих сервисов выше — эффект тот же.'
              : 'Добавьте сайты нужных сервисов выше.',
        ),
      ],
    );
  }
}

/// Буква сайта в цветном кружке.
class _Favicon extends StatelessWidget {
  final String domain;
  const _Favicon(this.domain);
  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFF4C8DFF),
      Color(0xFF30D158),
      Color(0xFFFF9F0A),
      Color(0xFFBF5AF2),
      Color(0xFF64D2FF),
      Color(0xFFFF375F),
    ];
    final c = colors[domain.codeUnits.fold(0, (a, b) => a + b) % colors.length];
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.withValues(alpha: .2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        domain[0].toUpperCase(),
        style: TextStyle(color: c, fontWeight: FontWeight.w700),
      ),
    );
  }
}
