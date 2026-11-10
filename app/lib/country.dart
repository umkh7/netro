/// Определение страны сервера по названию: флаг-эмодзи (🇳🇱) или слово.
class CountryGuess {
  final String code; // 'nl' или ''
  final String cleanName; // название без флага
  final String emoji; // флаг-эмодзи из названия (🇪🇺) — запасной значок
  const CountryGuess(this.code, this.cleanName, [this.emoji = '']);
}

const _names = <String, String>{
  'нидерланд': 'nl',
  'голланд': 'nl',
  'netherlands': 'nl',
  'amsterdam': 'nl',
  'амстердам': 'nl',
  'герман': 'de',
  'germany': 'de',
  'frankfurt': 'de',
  'франкфурт': 'de',
  'berlin': 'de',
  'финлянд': 'fi',
  'finland': 'fi',
  'helsinki': 'fi',
  'хельсинки': 'fi',
  'швеци': 'se',
  'sweden': 'se',
  'stockholm': 'se',
  'стокгольм': 'se',
  'турци': 'tr',
  'turkey': 'tr',
  'türkiye': 'tr',
  'istanbul': 'tr',
  'стамбул': 'tr',
  'сша': 'us',
  'usa': 'us',
  'united states': 'us',
  'америк': 'us',
  'нью-йорк': 'us',
  'new york': 'us',
  'росси': 'ru',
  'russia': 'ru',
  'москв': 'ru',
  'moscow': 'ru',
  'питер': 'ru',
  'санкт': 'ru',
  'казахстан': 'kz',
  'kazakhstan': 'kz',
  'алматы': 'kz',
  'astana': 'kz',
  'астана': 'kz',
  'франци': 'fr',
  'france': 'fr',
  'paris': 'fr',
  'париж': 'fr',
  'польш': 'pl',
  'poland': 'pl',
  'warsaw': 'pl',
  'варшав': 'pl',
  'великобритан': 'gb',
  'англи': 'gb',
  'united kingdom': 'gb',
  'london': 'gb',
  'лондон': 'gb',
  ' uk': 'gb',
  'латви': 'lv',
  'latvia': 'lv',
  'рига': 'lv',
  'riga': 'lv',
  'литв': 'lt',
  'lithuania': 'lt',
  'эстони': 'ee',
  'estonia': 'ee',
  'таллин': 'ee',
  'австри': 'at',
  'austria': 'at',
  'вена': 'at',
  'vienna': 'at',
  'швейцари': 'ch',
  'switzerland': 'ch',
  'цюрих': 'ch',
  'zurich': 'ch',
  'итали': 'it',
  'italy': 'it',
  'милан': 'it',
  'milan': 'it',
  'испани': 'es',
  'spain': 'es',
  'мадрид': 'es',
  'madrid': 'es',
  'португал': 'pt',
  'portugal': 'pt',
  'лиссабон': 'pt',
  'чехи': 'cz',
  'czech': 'cz',
  'прага': 'cz',
  'prague': 'cz',
  'сингапур': 'sg',
  'singapore': 'sg',
  'япони': 'jp',
  'japan': 'jp',
  'токио': 'jp',
  'tokyo': 'jp',
  'гонконг': 'hk',
  'hong kong': 'hk',
  'коре': 'kr',
  'korea': 'kr',
  'сеул': 'kr',
  'оаэ': 'ae',
  'эмират': 'ae',
  'uae': 'ae',
  'dubai': 'ae',
  'дубай': 'ae',
  'канад': 'ca',
  'canada': 'ca',
  'торонто': 'ca',
  'индонези': 'id',
  'indonesia': 'id',
  'бали': 'id',
  'грузи': 'ge',
  'georgia': 'ge',
  'тбилиси': 'ge',
  'армени': 'am',
  'armenia': 'am',
  'ереван': 'am',
  'украин': 'ua',
  'ukraine': 'ua',
  'молдов': 'md',
  'moldova': 'md',
  'румыни': 'ro',
  'romania': 'ro',
  'болгари': 'bg',
  'bulgaria': 'bg',
  'сербия': 'rs',
  'serbia': 'rs',
  'венгри': 'hu',
  'hungary': 'hu',
  'норвеги': 'no',
  'norway': 'no',
  'дани': 'dk',
  'denmark': 'dk',
  'ирланд': 'ie',
  'ireland': 'ie',
  'бельги': 'be',
  'belgium': 'be',
  'индия': 'in',
  'india': 'in',
  'бразили': 'br',
  'brazil': 'br',
  'австрали': 'au',
  'australia': 'au',
  'израил': 'il',
  'israel': 'il',
  'таиланд': 'th',
  'thailand': 'th',
  'вьетнам': 'vn',
  'vietnam': 'vn',
  'узбекистан': 'uz',
  'uzbekistan': 'uz',
  'беларус': 'by',
  'belarus': 'by',
};

CountryGuess guessCountry(String raw) {
  final runes = raw.runes.toList();
  String code = '';
  String emoji = '';
  final buf = StringBuffer();
  for (var i = 0; i < runes.length; i++) {
    final r = runes[i];
    final isRi = r >= 0x1F1E6 && r <= 0x1F1FF;
    if (isRi &&
        i + 1 < runes.length &&
        runes[i + 1] >= 0x1F1E6 &&
        runes[i + 1] <= 0x1F1FF) {
      if (code.isEmpty) {
        code = String.fromCharCodes([
          r - 0x1F1E6 + 97,
          runes[i + 1] - 0x1F1E6 + 97,
        ]);
        emoji = String.fromCharCodes([r, runes[i + 1]]);
      }
      i++;
      continue;
    }
    buf.writeCharCode(r);
  }
  var name = buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  name = name.replaceFirst(RegExp(r'^[|\-–—•·:,\s]+'), '').trim();
  if (name.isEmpty) name = raw.trim();
  if (code.isEmpty) {
    final low = ' ${name.toLowerCase()}';
    for (final e in _names.entries) {
      if (low.contains(e.key)) {
        code = e.value;
        break;
      }
    }
  }
  if (code == 'uk') code = 'gb';
  return CountryGuess(code, name, emoji);
}

/// Русские названия стран — для переименования сервера по реальной стране выхода.
const countryRu = <String, String>{
  'nl': 'Нидерланды',
  'de': 'Германия',
  'fi': 'Финляндия',
  'se': 'Швеция',
  'tr': 'Турция',
  'us': 'США',
  'ru': 'Россия',
  'kz': 'Казахстан',
  'fr': 'Франция',
  'pl': 'Польша',
  'gb': 'Великобритания',
  'lv': 'Латвия',
  'lt': 'Литва',
  'ee': 'Эстония',
  'at': 'Австрия',
  'ch': 'Швейцария',
  'it': 'Италия',
  'es': 'Испания',
  'pt': 'Португалия',
  'cz': 'Чехия',
  'sg': 'Сингапур',
  'jp': 'Япония',
  'hk': 'Гонконг',
  'kr': 'Корея',
  'ae': 'ОАЭ',
  'ca': 'Канада',
  'id': 'Индонезия',
  'ge': 'Грузия',
  'am': 'Армения',
  'ua': 'Украина',
  'md': 'Молдова',
  'ro': 'Румыния',
  'bg': 'Болгария',
  'rs': 'Сербия',
  'hu': 'Венгрия',
  'no': 'Норвегия',
  'dk': 'Дания',
  'ie': 'Ирландия',
  'be': 'Бельгия',
  'in': 'Индия',
  'br': 'Бразилия',
  'au': 'Австралия',
  'il': 'Израиль',
  'th': 'Таиланд',
  'vn': 'Вьетнам',
  'uz': 'Узбекистан',
  'by': 'Беларусь',
  'mk': 'Сев. Македония',
  'gr': 'Греция',
  'cy': 'Кипр',
  'lu': 'Люксембург',
  'is': 'Исландия',
  'my': 'Малайзия',
  'ph': 'Филиппины',
  'tw': 'Тайвань',
  'mx': 'Мексика',
  'ar': 'Аргентина',
  'za': 'ЮАР',
  'eg': 'Египет',
  'az': 'Азербайджан',
  'kg': 'Киргизия',
  'tj': 'Таджикистан',
  'tm': 'Туркменистан',
  'si': 'Словения',
  'sk': 'Словакия',
  'hr': 'Хорватия',
  'al': 'Албания',
  'me': 'Черногория',
};

/// Слова-регионы и «авто»-названия, которые тоже заменяются страной.
const _regionWords = [
  'северная македония',
  'north macedonia',
  'united states',
  'united kingdom',
  'hong kong',
  'new york',
  'европа',
  'europe',
  'евро',
  'мир',
  'world',
  'глобал',
  'global',
  'стелс',
  'stealth',
];

/// «Швеция LTE» + nl → «Нидерланды LTE»; «Европа LTE · 1» → «Нидерланды LTE · 1»;
/// «Авто LTE 🚀» → «Нидерланды · Авто LTE 🚀».
String renameForCountry(String name, String cc) {
  final ru = countryRu[cc];
  if (ru == null) return name;
  if (name.toLowerCase().contains(ru.toLowerCase())) return name;
  final low = name.toLowerCase();
  // 1) длинные названия («Северная Македония», «United States»)
  for (final w in _regionWords) {
    final i = low.indexOf(w);
    if (i >= 0 && w.length > 4 && !const ['мир', 'world'].contains(w)) {
      final end = _wordEnd(name, i + w.length);
      return _tidy(name.replaceRange(i, end, ru));
    }
  }
  // 2) первое слово, похожее на страну или город
  final words = RegExp(r'[\p{L}\-]+', unicode: true).allMatches(name);
  for (final m in words) {
    final wl = ' ${m.group(0)!.toLowerCase()}';
    final hit = _names.keys.any((k) => wl.contains(k) && k.trim().length >= 3);
    if (hit) return _tidy(name.replaceRange(m.start, m.end, ru));
  }
  return '$ru · $name';
}

int _wordEnd(String s, int i) {
  while (i < s.length && RegExp(r'[\p{L}]', unicode: true).hasMatch(s[i])) {
    i++;
  }
  return i;
}

String _tidy(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
