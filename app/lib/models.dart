import 'dart:convert';

/// Один сервер (outbound Xray) внутри подписки.
class Server {
  final String id; // стабильный id внутри приложения
  final String name; // имя без флага
  final String country; // ISO-код страны в нижнем регистре или ''
  final String protocol; // «VLESS · Reality»
  final String emoji; // флаг-эмодзи из названия (запасной значок)
  final Map<String, dynamic> outbound; // готовый outbound для Xray
  int? ping; // мс; null — не проверяли; >=10000 — ошибка

  Server({
    required this.id,
    required this.name,
    required this.country,
    required this.protocol,
    required this.outbound,
    this.ping,
    this.emoji = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'country': country,
    'protocol': protocol,
    'outbound': outbound,
    'ping': ping,
    'emoji': emoji,
  };

  factory Server.fromJson(Map<String, dynamic> j) => Server(
    id: j['id'] as String,
    name: j['name'] as String,
    country: (j['country'] as String?) ?? '',
    protocol: (j['protocol'] as String?) ?? '',
    outbound: Map<String, dynamic>.from(j['outbound'] as Map),
    ping: j['ping'] as int?,
    emoji: (j['emoji'] as String?) ?? '',
  );
}

/// Подписка (ссылка https://…) или группа ключей, добавленных вручную.
class Subscription {
  final String id;
  String title; // как пришло от сервиса, вместе с эмодзи
  final String? url; // null — ручные ключи
  List<Server> servers;
  DateTime? updatedAt;
  DateTime? expire; // из заголовка subscription-userinfo
  int? usedBytes;
  int? totalBytes; // 0 или null — без лимита
  bool autoUpdate;
  bool
  customTitle; // переименована вручную — не перезаписывать названием с сервера
  String? supportUrl;
  String? webPageUrl;

  Subscription({
    required this.id,
    required this.title,
    required this.url,
    required this.servers,
    this.updatedAt,
    this.expire,
    this.usedBytes,
    this.totalBytes,
    this.autoUpdate = true,
    this.customTitle = false,
    this.supportUrl,
    this.webPageUrl,
  });

  bool get isManual => url == null;

  /// Домен подписки — единственное, что когда-либо может уйти наружу.
  String get host {
    if (url == null) return '';
    return Uri.tryParse(url!)?.host ?? '';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'url': url,
    'servers': servers.map((s) => s.toJson()).toList(),
    'updatedAt': updatedAt?.toIso8601String(),
    'expire': expire?.toIso8601String(),
    'usedBytes': usedBytes,
    'totalBytes': totalBytes,
    'autoUpdate': autoUpdate,
    'customTitle': customTitle,
    'supportUrl': supportUrl,
    'webPageUrl': webPageUrl,
  };

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
    id: j['id'] as String,
    title: j['title'] as String,
    url: j['url'] as String?,
    servers: ((j['servers'] as List?) ?? [])
        .map((e) => Server.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    updatedAt: j['updatedAt'] == null
        ? null
        : DateTime.tryParse(j['updatedAt']),
    expire: j['expire'] == null ? null : DateTime.tryParse(j['expire']),
    usedBytes: j['usedBytes'] as int?,
    totalBytes: j['totalBytes'] as int?,
    autoUpdate: (j['autoUpdate'] as bool?) ?? true,
    customTitle: (j['customTitle'] as bool?) ?? false,
    supportUrl: j['supportUrl'] as String?,
    webPageUrl: j['webPageUrl'] as String?,
  );

  static String encodeList(List<Subscription> l) =>
      jsonEncode(l.map((s) => s.toJson()).toList());

  static List<Subscription> decodeList(String s) => (jsonDecode(s) as List)
      .map((e) => Subscription.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

enum ConnMode { tun, proxy }

enum ConnState { off, connecting, on, error }
