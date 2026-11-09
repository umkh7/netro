import 'dart:convert';
import 'dart:async';
import 'dart:io' show HandshakeException, Platform, SocketException;

import 'package:http/http.dart' as http;

import 'config_builder.dart';
import 'core.dart';
import 'country.dart';
import 'models.dart';

const appVersion = '1.1.0';

String get userAgent {
  final os = Platform.isAndroid
      ? 'Android'
      : Platform.isIOS
          ? 'iOS'
          : Platform.isWindows
              ? 'Windows'
              : Platform.operatingSystem;
  return 'Netro/$appVersion ($os)';
}

class SubFetchResult {
  final String title;
  final List<Server> servers;
  final DateTime? expire;
  final int? used;
  final int? total;
  final String? supportUrl;
  final String? webPageUrl;
  SubFetchResult(this.title, this.servers, this.expire, this.used, this.total, this.supportUrl,
      this.webPageUrl);
}

String _newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

/// Пытается раскрыть base64 (обычный или url-safe, с паддингом или без).
String _maybeBase64(String body) {
  final t = body.trim();
  if (t.contains('://') || t.startsWith('{') || t.startsWith('[')) return t;
  final compact = t.replaceAll(RegExp(r'\s'), '');
  if (!RegExp(r'^[A-Za-z0-9+/=_-]+$').hasMatch(compact)) return t;
  try {
    var s = compact.replaceAll('-', '+').replaceAll('_', '/');
    while (s.length % 4 != 0) {
      s += '=';
    }
    final out = utf8.decode(base64.decode(s), allowMalformed: true);
    if (out.contains('://') || out.trim().startsWith('{') || out.trim().startsWith('[')) {
      return out.trim();
    }
  } catch (_) {}
  return t;
}

String _decodeHeaderText(String? v) {
  if (v == null || v.isEmpty) return '';
  if (v.startsWith('base64:')) {
    try {
      return utf8.decode(base64.decode(v.substring(7).trim()), allowMalformed: true).trim();
    } catch (_) {
      return '';
    }
  }
  try {
    return Uri.decodeComponent(v).trim();
  } catch (_) {
    return v.trim();
  }
}

/// Старый формат vmess://base64(JSON) libXray не понимает —
/// переводим в современную ссылку VMessAEAD.
String _legacyVmessToAead(String line) {
  try {
    var b = line.substring(8).trim();
    b = b.replaceAll('-', '+').replaceAll('_', '/');
    while (b.length % 4 != 0) {
      b += '=';
    }
    final j = jsonDecode(utf8.decode(base64.decode(b))) as Map<String, dynamic>;
    String s(String k) => (j[k] ?? '').toString();
    final net = s('net').isEmpty ? 'tcp' : s('net');
    final q = <String, String>{
      'encryption': s('scy').isEmpty ? 'auto' : s('scy'),
      'type': net,
    };
    if (s('tls') == 'tls') {
      q['security'] = 'tls';
      if (s('sni').isNotEmpty) q['sni'] = s('sni');
      if (s('fp').isNotEmpty) q['fp'] = s('fp');
      if (s('alpn').isNotEmpty) q['alpn'] = s('alpn');
    }
    if (s('host').isNotEmpty) q['host'] = s('host');
    if (net == 'grpc') {
      if (s('path').isNotEmpty) q['serviceName'] = s('path');
    } else if (s('path').isNotEmpty) {
      q['path'] = s('path');
    }
    if (net == 'tcp' && s('type') == 'http') q['headerType'] = 'http';
    final host = s('add').contains(':') ? '[${s('add')}]' : s('add');
    final query = q.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value).replaceAll('+', '%20')}')
        .join('&');
    return 'vmess://${s('id')}@$host:${s('port')}?$query#${Uri.encodeComponent(s('ps'))}';
  } catch (_) {
    return line;
  }
}

String _normalizeLinks(String text) {
  final t = text.trim();
  if (t.startsWith('{') || t.startsWith('[')) return t;
  return t
      .split(RegExp(r'[\r\n]+'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .map((l) {
        if (l.startsWith('vmess://') && !l.substring(8).contains('@')) {
          return _legacyVmessToAead(l);
        }
        return l;
      })
      .join('\n');
}

Future<List<Server>> parseServers(String text, String idPrefix) async {
  final norm = _normalizeLinks(_maybeBase64(text));
  final obs = await Core.convertLinks(norm);
  final res = <Server>[];
  for (var i = 0; i < obs.length; i++) {
    final ob = obs[i];
    final tag = (ob['tag'] as String?)?.trim() ?? '';
    final g = guessCountry(tag.isEmpty ? 'Сервер ${i + 1}' : tag);
    res.add(Server(
      id: '$idPrefix-$i-${g.cleanName.hashCode.toRadixString(36)}',
      name: g.cleanName,
      country: g.code,
      protocol: protocolLabel(ob),
      outbound: ob,
    ));
  }
  return res;
}

/// Загрузка подписки. Ключи и содержимое ссылки никуда не отправляются.
Future<SubFetchResult> fetchSubscription(String url, String idPrefix) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) throw CoreError('Это не похоже на ссылку подписки');
  http.Response r;
  try {
    r = await http.get(uri, headers: {
      'User-Agent': userAgent,
      'Accept': '*/*',
    }).timeout(const Duration(seconds: 20));
  } on TimeoutException {
    throw CoreError('Сервер подписки не отвечает. Проверьте интернет и попробуйте ещё раз');
  } on SocketException {
    throw CoreError('Нет связи с ${uri.host}. Проверьте интернет или ссылку');
  } on HandshakeException {
    throw CoreError('Не удалось установить защищённое соединение с ${uri.host}');
  }
  if (r.statusCode == 404) {
    throw CoreError('Подписка не найдена. Проверьте ссылку — возможно, в ней опечатка');
  }
  if (r.statusCode == 401 || r.statusCode == 403) {
    throw CoreError('Подписка отключена или истекла (${r.statusCode})');
  }
  if (r.statusCode >= 500) {
    throw CoreError('Сервер подписки временно недоступен (${r.statusCode})');
  }
  if (r.statusCode >= 400) {
    throw CoreError('Сервер подписки ответил ошибкой ${r.statusCode}');
  }
  final body = utf8.decode(r.bodyBytes, allowMalformed: true);
  final servers = await parseServers(body, idPrefix);
  if (servers.isEmpty) throw CoreError('В подписке нет серверов');

  var title = _decodeHeaderText(r.headers['profile-title']);
  if (title.isEmpty) {
    final cd = r.headers['content-disposition'] ?? '';
    final m = RegExp(r'filename\*?=(?:UTF-8'')?"?([^";]+)"?').firstMatch(cd);
    if (m != null) title = _decodeHeaderText(m.group(1));
  }
  if (title.isEmpty) title = Uri.parse(url).host;

  DateTime? expire;
  int? used, total;
  final info = r.headers['subscription-userinfo'];
  if (info != null) {
    final kv = <String, int>{};
    for (final part in info.split(';')) {
      final p = part.split('=');
      if (p.length == 2) kv[p[0].trim()] = int.tryParse(p[1].trim()) ?? 0;
    }
    used = (kv['upload'] ?? 0) + (kv['download'] ?? 0);
    total = kv['total'];
    final e = kv['expire'] ?? 0;
    if (e > 0) expire = DateTime.fromMillisecondsSinceEpoch(e * 1000);
  }
  return SubFetchResult(
    title,
    servers,
    expire,
    used,
    total,
    _decodeHeaderText(r.headers['support-url']).isEmpty ? null : _decodeHeaderText(r.headers['support-url']),
    _decodeHeaderText(r.headers['profile-web-page-url']).isEmpty
        ? null
        : _decodeHeaderText(r.headers['profile-web-page-url']),
  );
}

/// Что ввёл человек: ссылка подписки (http/https) или ключи.
bool isSubscriptionUrl(String s) {
  final t = s.trim().toLowerCase();
  return (t.startsWith('https://') || t.startsWith('http://')) && !t.contains('\n');
}

String newId() => _newId();
