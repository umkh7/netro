import 'dart:convert';

/// DNS-серверы на выбор. AdGuard заодно режет рекламу и трекеры.
class DnsOption {
  final String id, title, subtitle, ip;
  const DnsOption(this.id, this.title, this.subtitle, this.ip);
}

const dnsOptions = [
  DnsOption('cloudflare', 'Cloudflare', '1.1.1.1 · быстрый', '1.1.1.1'),
  DnsOption('google', 'Google', '8.8.8.8', '8.8.8.8'),
  DnsOption(
    'adguard',
    'AdGuard',
    '94.140.14.14 · без рекламы и трекеров',
    '94.140.14.14',
  ),
  DnsOption('quad9', 'Quad9', '9.9.9.9 · блок вредоносных сайтов', '9.9.9.9'),
];

DnsOption dnsById(String id) =>
    dnsOptions.firstWhere((d) => d.id == id, orElse: () => dnsOptions.first);

enum SortMode { list, ping, name }

/// Раздельное туннелирование на Android: все приложения / кроме выбранных / только выбранные.
enum SplitMode { off, exclude, include }

class Settings {
  bool autoConnect = false;
  bool lanDirect = true; // локальная сеть (роутер, принтер, ТВ) мимо VPN
  bool ruDirect = false; // сайты .ru / .рф / .su мимо VPN
  String dns = 'cloudflare';
  String pingUrl = 'https://cp.cloudflare.com/';
  int pingTimeout = 5;
  SortMode sort = SortMode.list;
  SplitMode split = SplitMode.off;
  List<String> splitApps = [];
  bool autoBest = false; // перед подключением выбирать сервер с лучшим пингом
  bool bypassOn = true; // исключения включены
  List<String> bypassDomains = []; // сайты мимо VPN (домены)

  /// Активные домены-исключения.
  List<String> get bypassActive => bypassOn ? bypassDomains : const [];

  Map<String, dynamic> toJson() => {
    'autoConnect': autoConnect,
    'lanDirect': lanDirect,
    'ruDirect': ruDirect,
    'dns': dns,
    'pingUrl': pingUrl,
    'pingTimeout': pingTimeout,
    'sort': sort.name,
    'split': split.name,
    'splitApps': splitApps,
    'autoBest': autoBest,
    'bypassOn': bypassOn,
    'bypassDomains': bypassDomains,
  };

  static Settings fromJson(String? raw) {
    final s = Settings();
    if (raw == null) return s;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      s.autoConnect = j['autoConnect'] as bool? ?? s.autoConnect;
      s.lanDirect = j['lanDirect'] as bool? ?? s.lanDirect;
      s.ruDirect = j['ruDirect'] as bool? ?? s.ruDirect;
      s.dns = j['dns'] as String? ?? s.dns;
      s.pingUrl = j['pingUrl'] as String? ?? s.pingUrl;
      s.pingTimeout = j['pingTimeout'] as int? ?? s.pingTimeout;
      s.sort = SortMode.values.firstWhere(
        (e) => e.name == j['sort'],
        orElse: () => SortMode.list,
      );
      s.split = SplitMode.values.firstWhere(
        (e) => e.name == j['split'],
        orElse: () => SplitMode.off,
      );
      s.splitApps = ((j['splitApps'] as List?) ?? []).cast<String>();
      s.autoBest = j['autoBest'] as bool? ?? s.autoBest;
      s.bypassOn = j['bypassOn'] as bool? ?? s.bypassOn;
      s.bypassDomains = ((j['bypassDomains'] as List?) ?? []).cast<String>();
    } catch (_) {}
    return s;
  }

  String encode() => jsonEncode(toJson());
}

/// «https://www.umkh7.com/test?x=1» → «umkh7.com». null — не похоже на сайт.
String? normalizeDomain(String input) {
  var t = input.trim().toLowerCase();
  if (t.isEmpty) return null;
  t = t.replaceFirst(RegExp(r'^[a-z][a-z0-9+.-]*://'), '');
  t = t.split(RegExp(r'[/?#]')).first;
  t = t.split('@').last;
  t = t.replaceFirst(RegExp(r':\d+$'), '');
  if (t.startsWith('*.')) t = t.substring(2);
  if (t.startsWith('www.')) t = t.substring(4);
  if (t.endsWith('.')) t = t.substring(0, t.length - 1);
  if (!RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+$').hasMatch(t)) {
    return null;
  }
  return t;
}

/// Готовые наборы сайтов для быстрого добавления.
const bypassPresets = <(String, List<String>)>[
  ('Госуслуги', ['gosuslugi.ru']),
  ('Ozon', ['ozon.ru', 'ozone.ru']),
  ('Wildberries', ['wildberries.ru', 'wb.ru', 'wbbasket.ru', 'wbstatic.net']),
  ('Сбербанк', ['sberbank.ru', 'sber.ru']),
  ('Т-Банк', ['tbank.ru', 'tinkoff.ru']),
  ('ВТБ', ['vtb.ru']),
  ('Альфа-Банк', ['alfabank.ru']),
  ('Яндекс', ['yandex.ru', 'ya.ru', 'yandex.net']),
  ('ВКонтакте', ['vk.com', 'vk.ru', 'userapi.com']),
  ('Авито', ['avito.ru', 'avito.st']),
  ('Кинопоиск', ['kinopoisk.ru']),
  ('Мир / НСПК', ['nspk.ru', 'mironline.ru']),
];
