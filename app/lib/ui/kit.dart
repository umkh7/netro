import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class C {
  static const bg = Color(0xFF000000);
  static const card = Color(0xFF151517);
  static const field = Color(0xFF1C1C1E);
  static const segOn = Color(0xFF3A3A3C);
  static const line = Color(0x12FFFFFF);
  static const text = Color(0xFFF2F2F5);
  static const gray = Color(0xFF8E8E93);
  static const chevron = Color(0xFF5A5A60);
  static const accent = Color(0xFF4C8DFF);
  static const green = Color(0xFF30D158);
  static const orange = Color(0xFFFF9F0A);
  static const red = Color(0xFFFF453A);
}

ThemeData netroTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: C.bg,
    colorScheme: const ColorScheme.dark(
      primary: C.accent,
      surface: C.bg,
      onSurface: C.text,
      error: C.red,
    ),
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: C.text, displayColor: C.text),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: C.field,
      contentTextStyle: TextStyle(color: C.text, fontSize: 14),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Color pingColor(int? p) {
  if (p == null) return C.gray;
  if (p >= 10000) return C.red;
  if (p < 80) return C.green;
  if (p < 140) return C.orange;
  return C.red;
}

String pingText(int? p) {
  if (p == null) return '';
  if (p >= 11000) return 'таймаут';
  if (p >= 10000) return 'ошибка';
  return '$p мс';
}

String bytesText(int b) {
  const u = ['Б', 'КБ', 'МБ', 'ГБ', 'ТБ'];
  double v = b.toDouble();
  var i = 0;
  while (v >= 1024 && i < u.length - 1) {
    v /= 1024;
    i++;
  }
  final s = v >= 100 || i == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return '${s.replaceAll('.', ',')} ${u[i]}';
}

String speedText(int bps) {
  final bits = bps * 8;
  if (bits < 1000) return '$bits бит/с';
  if (bits < 1000000) return '${(bits / 1000).toStringAsFixed(0)} Кбит/с';
  return '${(bits / 1000000).toStringAsFixed(1).replaceAll('.', ',')} Мбит/с';
}

String agoText(DateTime? t) {
  if (t == null) return 'никогда';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'только что';
  if (d.inMinutes < 60) return '${d.inMinutes} мин назад';
  if (d.inHours < 24) return '${d.inHours} ч назад';
  return '${d.inDays} дн назад';
}

String plural(int n, String one, String few, String many) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return one;
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
  return many;
}

const _months = [
  'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
];

String dateText(DateTime d) => '${d.day} ${_months[d.month - 1]}';

String daysLeftText(DateTime? expire) {
  if (expire == null) return 'Без срока';
  final left = expire.difference(DateTime.now());
  if (left.isNegative) return 'Истекла ${dateText(expire)}';
  final days = left.inHours ~/ 24;
  if (days == 0) return 'Истекает сегодня';
  return 'Осталось $days ${plural(days, 'день', 'дня', 'дней')} · до ${dateText(expire)}';
}

/// Флаг страны в кружке; без страны — значок глобуса.
class Flag extends StatelessWidget {
  final String code;
  final double size;
  const Flag(this.code, {super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final ring = BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0x1FFFFFFF)),
    );
    if (code.length != 2) {
      return Container(
        width: size,
        height: size,
        decoration: ring.copyWith(color: const Color(0xFF2C2C2E)),
        child: Icon(Icons.public, size: size * 0.6, color: const Color(0xFFC7C7CC)),
      );
    }
    return Container(
      width: size,
      height: size,
      foregroundDecoration: ring,
      child: CountryFlag.fromCountryCode(
        code,
        theme: ImageTheme(width: size, height: size, shape: const Circle()),
      ),
    );
  }
}

class NCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const NCard({super.key, required this.child, this.padding = EdgeInsets.zero, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.card,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class Chevron extends StatelessWidget {
  const Chevron({super.key});
  @override
  Widget build(BuildContext context) =>
      const Icon(Icons.chevron_right_rounded, color: C.chevron, size: 22);
}

class SectionLabel extends StatelessWidget {
  final String left;
  final String? right;
  const SectionLabel(this.left, {super.key, this.right});
  @override
  Widget build(BuildContext context) {
    const st = TextStyle(fontSize: 13, color: C.gray);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(children: [
        Expanded(child: Text(left, style: st, overflow: TextOverflow.ellipsis)),
        if (right != null) Text(right!, style: st),
      ]),
    );
  }
}

class LargeTitle extends StatelessWidget {
  final String text;
  final List<Widget> actions;
  final Widget? leading;
  const LargeTitle(this.text, {super.key, this.actions = const [], this.leading});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(children: [
        if (leading != null) ...[leading!, const SizedBox(width: 10)],
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
        ),
        ...actions,
      ]),
    );
  }
}

class IconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const IconAction(this.icon, this.tooltip, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        icon: Icon(icon, color: C.accent, size: 26),
      );
}

/// Сегментированный переключатель в стиле iOS.
class Segmented<T> extends StatelessWidget {
  final Map<T, String> items;
  final T value;
  final ValueChanged<T> onChanged;
  const Segmented({super.key, required this.items, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: C.field, borderRadius: BorderRadius.circular(9)),
      child: Row(
        children: items.entries.map((e) {
          final on = e.key == value;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? C.segOn : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(e.value,
                    style: TextStyle(
                        fontSize: 13, fontWeight: on ? FontWeight.w600 : FontWeight.w500)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class Hairline extends StatelessWidget {
  final double indent;
  const Hairline({super.key, this.indent = 0});
  @override
  Widget build(BuildContext context) =>
      Container(margin: EdgeInsets.only(left: indent), height: 1, color: C.line);
}

class Btn extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool primary;
  final bool busy;
  const Btn(this.text, {super.key, this.onTap, this.primary = false, this.busy = false});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: FilledButton(
        onPressed: busy ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: primary ? C.accent : C.field,
          foregroundColor: primary ? Colors.white : C.accent,
          disabledBackgroundColor: primary ? C.accent.withValues(alpha: 0.5) : C.field,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: busy
            ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(text),
      ),
    );
  }
}

class SubAvatar extends StatelessWidget {
  final String title;
  final double size;
  const SubAvatar(this.title, {super.key, this.size = 32});
  @override
  Widget build(BuildContext context) {
    // Если название начинается с эмодзи — показываем его, иначе первые буквы.
    final t = title.trim();
    final first = t.characters.isEmpty ? '?' : t.characters.first;
    final isEmoji = first.runes.any((r) => r > 0x2000);
    final label = isEmoji
        ? first
        : t.replaceAll(RegExp(r'[^A-Za-zА-Яа-я0-9]'), '').characters.take(2).toString().toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isEmoji ? const Color(0xFF2C2C2E) : C.accent,
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: isEmoji ? size * 0.5 : size * 0.36,
              fontWeight: FontWeight.w700,
              color: Colors.white)),
    );
  }
}

/// Название подписки без ведущего эмодзи (оно уже в аватарке).
String titleWithoutEmoji(String t) {
  final s = t.trim();
  if (s.isEmpty) return s;
  final first = s.characters.first;
  if (first.runes.any((r) => r > 0x2000)) return s.characters.skip(1).toString().trim();
  return s;
}

// ---------- Движение и отклик ----------

/// Плавный переход на новый экран (iOS-свайп назад работает).
Route<T> smoothRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: c,
          child: SlideTransition(
            position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(c),
            child: child,
          ),
        );
      },
    );

/// Кнопка, которая мягко «проседает» при нажатии.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.scale = 0.97});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              _set(false);
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _down ? 0.85 : 1,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Плавное появление содержимого (сдвиг снизу + проявление) с задержкой по порядку.
class Appear extends StatelessWidget {
  final Widget child;
  final int index;
  const Appear({super.key, required this.child, this.index = 0});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + index * 40),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: c),
      ),
      child: child,
    );
  }
}

// ---------- Строки списков (как в настройках iOS) ----------

class Group extends StatelessWidget {
  final List<Widget> children;
  final String? header;
  final String? footer;
  const Group({super.key, required this.children, this.header, this.footer});
  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) rows.add(const Hairline(indent: 56));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (header != null) SectionLabel(header!),
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(color: C.card, child: Column(children: rows)),
      ),
      if (footer != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(footer!, style: const TextStyle(fontSize: 13, height: 1.4, color: C.gray)),
        ),
      const SizedBox(height: 8),
    ]);
  }
}

class RowIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const RowIcon(this.icon, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: Colors.white),
      );
}

class NavRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  final bool chevron;
  const NavRow(
      {super.key,
      this.leading,
      required this.title,
      this.subtitle,
      this.value,
      this.trailing,
      this.onTap,
      this.titleColor,
      this.chevron = true});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(title, style: TextStyle(fontSize: 16, color: titleColor ?? C.text)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: C.gray, height: 1.3)),
                  ],
                ]),
              ),
              if (value != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(value!, style: const TextStyle(fontSize: 15, color: C.gray)),
                ),
              if (trailing != null) trailing!,
              if (trailing == null && onTap != null && chevron) const Chevron(),
            ]),
          ),
        ),
      ),
    );
  }
}

class SwitchRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const SwitchRow(
      {super.key, this.leading, required this.title, this.subtitle, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => NavRow(
        leading: leading,
        title: title,
        subtitle: subtitle,
        onTap: () => onChanged(!value),
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeTrackColor: C.green,
          activeThumbColor: Colors.white,
          inactiveTrackColor: const Color(0xFF39393D),
          inactiveThumbColor: Colors.white,
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      );
}

/// Нижняя выезжающая панель в стиле приложения.
Future<T?> showSheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111113),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => child,
    );

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
