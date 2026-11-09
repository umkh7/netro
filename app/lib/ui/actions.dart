import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../core.dart';
import '../models.dart';
import 'kit.dart';

/// Долгое нажатие на сервер.
Future<void> showServerActions(
  BuildContext context,
  AppState st,
  Server sv,
) async {
  final sub = st.subOf(sv);
  await showSheet(
    context,
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flag(sv.country, size: 40, emoji: sv.emoji),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sv.name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${sub?.title ?? ''} · ${sv.protocol}',
                      style: const TextStyle(fontSize: 13, color: C.gray),
                    ),
                  ],
                ),
              ),
              if (sv.ping != null)
                Text(
                  pingText(sv.ping),
                  style: TextStyle(color: pingColor(sv.ping)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Group(
            children: [
              NavRow(
                leading: const RowIcon(
                  Icons.power_settings_new_rounded,
                  C.green,
                ),
                title: 'Подключиться',
                chevron: false,
                onTap: () async {
                  Navigator.pop(context);
                  await st.select(sv);
                  if (st.conn == ConnState.off) await st.connect();
                },
              ),
              NavRow(
                leading: const RowIcon(Icons.copy_rounded, C.accent),
                title: 'Скопировать ключ',
                subtitle: 'Ссылка vless://… для другого приложения',
                chevron: false,
                onTap: () async {
                  final l = await Core.shareLink(sv.outbound);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  if (l == null) {
                    toast(context, 'Этот сервер нельзя выгрузить ссылкой');
                    return;
                  }
                  await Clipboard.setData(ClipboardData(text: l));
                  if (context.mounted) toast(context, 'Ключ скопирован');
                },
              ),
              NavRow(
                leading: const RowIcon(
                  Icons.qr_code_2_rounded,
                  Color(0xFF8E5CF7),
                ),
                title: 'Показать QR-код',
                chevron: false,
                onTap: () async {
                  final l = await Core.shareLink(sv.outbound);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  if (l == null) {
                    toast(context, 'Этот сервер нельзя выгрузить ссылкой');
                    return;
                  }
                  Navigator.of(context).push(
                    smoothRoute(
                      QrShowPage(title: sv.name, data: l, secret: true),
                    ),
                  );
                },
              ),
              if (sub?.isManual == true)
                NavRow(
                  leading: const RowIcon(Icons.delete_outline_rounded, C.red),
                  title: 'Удалить ключ',
                  titleColor: C.red,
                  chevron: false,
                  onTap: () async {
                    Navigator.pop(context);
                    await st.removeServer(sv);
                  },
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Действия с подпиской.
Future<void> showSubActions(
  BuildContext context,
  AppState st,
  Subscription sub,
) async {
  await showSheet(
    context,
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              sub.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          Group(
            children: [
              if (!sub.isManual)
                NavRow(
                  leading: const RowIcon(Icons.refresh_rounded, C.accent),
                  title: 'Обновить',
                  chevron: false,
                  onTap: () {
                    Navigator.pop(context);
                    st.refresh(sub);
                  },
                ),
              NavRow(
                leading: const RowIcon(Icons.bolt_rounded, C.orange),
                title: 'Выбрать самый быстрый сервер',
                chevron: false,
                onTap: () {
                  Navigator.pop(context);
                  st.selectBest(sub);
                },
              ),
              NavRow(
                leading: const RowIcon(Icons.edit_outlined, Color(0xFF636366)),
                title: 'Переименовать',
                chevron: false,
                onTap: () async {
                  Navigator.pop(context);
                  final t = await _askText(
                    context,
                    'Название подписки',
                    sub.title,
                  );
                  if (t != null) await st.rename(sub, t);
                },
              ),
              if (!sub.isManual) ...[
                NavRow(
                  leading: const RowIcon(Icons.link_rounded, Color(0xFF0A84FF)),
                  title: 'Скопировать ссылку',
                  chevron: false,
                  onTap: () async {
                    Navigator.pop(context);
                    await Clipboard.setData(ClipboardData(text: sub.url!));
                    if (context.mounted) toast(context, 'Ссылка скопирована');
                  },
                ),
                NavRow(
                  leading: const RowIcon(
                    Icons.qr_code_2_rounded,
                    Color(0xFF8E5CF7),
                  ),
                  title: 'QR-код подписки',
                  subtitle: 'Отсканировать на другом устройстве',
                  chevron: false,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      smoothRoute(
                        QrShowPage(
                          title: sub.title,
                          data: sub.url!,
                          secret: true,
                        ),
                      ),
                    );
                  },
                ),
              ],
              if (sub.webPageUrl != null)
                NavRow(
                  leading: const RowIcon(Icons.open_in_new_rounded, C.green),
                  title: 'Сайт сервиса · продлить',
                  chevron: false,
                  onTap: () {
                    Navigator.pop(context);
                    launchUrl(
                      Uri.parse(sub.webPageUrl!),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
              if (sub.supportUrl != null)
                NavRow(
                  leading: const RowIcon(
                    Icons.support_agent_rounded,
                    Color(0xFF30B0C7),
                  ),
                  title: 'Поддержка',
                  chevron: false,
                  onTap: () {
                    Navigator.pop(context);
                    launchUrl(
                      Uri.parse(sub.supportUrl!),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
              NavRow(
                leading: const RowIcon(Icons.delete_outline_rounded, C.red),
                title: 'Удалить',
                titleColor: C.red,
                chevron: false,
                onTap: () async {
                  Navigator.pop(context);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      backgroundColor: C.field,
                      title: const Text('Удалить подписку?'),
                      content: Text(
                        '«${sub.title}» и её серверы пропадут из приложения.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Отмена'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text(
                            'Удалить',
                            style: TextStyle(color: C.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) await st.remove(sub);
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<String?> _askText(BuildContext context, String title, String initial) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      backgroundColor: C.field,
      title: Text(title),
      content: TextField(controller: c, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(d, c.text),
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
}

/// QR-код ключа или подписки.
class QrShowPage extends StatelessWidget {
  final String title, data;
  final bool secret;
  const QrShowPage({
    super.key,
    required this.title,
    required this.data,
    this.secret = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.bg,
        title: Text(title, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Appear(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: QrImageView(
                  data: data,
                  version: QrVersions.auto,
                  gapless: true,
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (secret)
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: C.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Это ваш ключ доступа. Не показывайте его посторонним — по нему подключаются к VPN.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: C.gray,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 18),
            Btn(
              'Скопировать',
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: data));
                if (context.mounted) toast(context, 'Скопировано');
              },
            ),
          ],
        ),
      ),
    );
  }
}
