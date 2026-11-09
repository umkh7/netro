import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

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
