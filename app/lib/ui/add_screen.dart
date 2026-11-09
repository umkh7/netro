import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app_state.dart';
import 'kit.dart';

bool get canScanQr => Platform.isAndroid || Platform.isIOS;

class AddScreen extends StatefulWidget {
  final AppState st;
  final VoidCallback onAdded;
  const AddScreen({super.key, required this.st, required this.onAdded});
  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final _ctl = TextEditingController();
  bool _busy = false;

  Future<void> _add(String text) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final sub = await widget.st.addFromText(text);
      _ctl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Добавлено: ${sub.title} · ${sub.servers.length} '
              '${plural(sub.servers.length, 'сервер', 'сервера', 'серверов')}')));
      widget.onAdded();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text?.trim() ?? '';
    if (t.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Буфер обмена пуст')));
      }
      return;
    }
    await _add(t);
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _QrPage(), fullscreenDialog: true),
    );
    if (code != null && code.isNotEmpty) await _add(code);
  }

  Widget _action(IconData icon, Color bg, String text, VoidCallback onTap, {bool chevron = false}) {
    return InkWell(
      onTap: _busy ? null : onTap,
      child: SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
            if (chevron) const Chevron(),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const LargeTitle('Добавить'),
        const SizedBox(height: 10),
        NCard(
          child: Column(children: [
            _action(Icons.content_paste_rounded, C.accent, 'Вставить из буфера', _paste),
            if (canScanQr) ...[
              const Hairline(indent: 58),
              _action(Icons.qr_code_scanner_rounded, const Color(0xFF30A46C), 'Сканировать QR-код', _scan,
                  chevron: true),
            ],
          ]),
        ),
        const SectionLabel('Вручную'),
        NCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: TextField(
            controller: _ctl,
            minLines: 1,
            maxLines: 4,
            style: const TextStyle(fontSize: 16),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Ссылка подписки или ключ',
              hintStyle: TextStyle(color: C.gray),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            'Поддерживаются ссылки https:// и ключи vless, vmess, trojan, shadowsocks, hysteria2. '
            'Ключи хранятся только на этом устройстве.',
            style: TextStyle(fontSize: 13, height: 1.45, color: C.gray),
          ),
        ),
        const SizedBox(height: 16),
        Btn('Добавить', primary: true, busy: _busy, onTap: () => _add(_ctl.text)),
      ],
    );
  }
}

class _QrPage extends StatefulWidget {
  const _QrPage();
  @override
  State<_QrPage> createState() => _QrPageState();
}

class _QrPageState extends State<_QrPage> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('QR-код'),
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(children: [
        MobileScanner(
          onDetect: (cap) {
            if (_done) return;
            final v = cap.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
            if (v != null && v.isNotEmpty) {
              _done = true;
              Navigator.pop(context, v);
            }
          },
        ),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white, width: 3),
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 48,
          child: Text('Наведите камеру на QR-код',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Color(0xFFE5E5EA))),
        ),
      ]),
    );
  }
}
