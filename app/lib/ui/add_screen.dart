import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app_state.dart';
import '../models.dart';
import 'kit.dart';

bool get canScanQr => Platform.isAndroid || Platform.isIOS;

/// Открыть панель добавления. Возвращает добавленную подписку (или null).
Future<Subscription?> showAddSheet(BuildContext context, AppState st) =>
    showSheet<Subscription>(context, AddPanel(st: st));

class AddPanel extends StatefulWidget {
  final AppState st;
  const AddPanel({super.key, required this.st});
  @override
  State<AddPanel> createState() => _AddPanelState();
}

class _AddPanelState extends State<AddPanel> {
  final _ctl = TextEditingController();
  bool _busy = false;
  bool _manual = false;
  String? _error;

  Future<void> _add(String text) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sub = await widget.st.addFromText(text);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.pop(context, sub);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text?.trim() ?? '';
    if (t.isEmpty) {
      setState(
        () => _error = 'В буфере обмена пусто. Скопируйте ссылку подписки и нажмите ещё раз',
      );
      return;
    }
    _ctl.text = t;
    await _add(t);
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const _QrPage(),
        fullscreenDialog: true,
      ),
    );
    if (code != null && code.isNotEmpty) {
      _ctl.text = code;
      await _add(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              'Добавить подписку',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 14),
            child: Text(
              'Ссылка из бота, ключ vless/vmess/trojan/ss или QR-код',
              style: TextStyle(fontSize: 14, color: C.gray),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _BigAction(
                  icon: Icons.content_paste_rounded,
                  color: C.accent,
                  title: 'Из буфера',
                  onTap: _busy ? null : _paste,
                ),
              ),
              if (canScanQr) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _BigAction(
                    icon: Icons.qr_code_scanner_rounded,
                    color: const Color(0xFF30A46C),
                    title: 'QR-код',
                    onTap: _busy ? null : _scan,
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Expanded(
                child: _BigAction(
                  icon: Icons.keyboard_rounded,
                  color: const Color(0xFF8E5CF7),
                  title: 'Вручную',
                  onTap: _busy
                      ? null
                      : () => setState(() => _manual = !_manual),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: !_manual
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: C.card,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: TextField(
                            controller: _ctl,
                            autofocus: true,
                            minLines: 1,
                            maxLines: 4,
                            autocorrect: false,
                            enableSuggestions: false,
                            textCapitalization: TextCapitalization.none,
                            keyboardType: TextInputType.url,
                            style: const TextStyle(fontSize: 15),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'https://… или vless://…',
                              hintStyle: TextStyle(color: C.gray),
                            ),
                            onSubmitted: _add,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Btn(
                          'Добавить',
                          primary: true,
                          busy: _busy,
                          onTap: () => _add(_ctl.text),
                        ),
                      ],
                    ),
                  ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _error == null
                ? (_busy && !_manual
                      ? const Padding(
                          key: ValueKey('busy'),
                          padding: EdgeInsets.only(top: 18),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox(key: ValueKey('none')))
                : Container(
                    key: ValueKey(_error),
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: C.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: C.red.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: C.red,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(fontSize: 14, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 14, 4, 0),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 15, color: C.gray),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ключи хранятся только на этом устройстве',
                    style: TextStyle(fontSize: 12.5, color: C.gray),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BigAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback? onTap;
  const _BigAction({
    required this.icon,
    required this.color,
    required this.title,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RowIcon(icon, color),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
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
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (cap) {
              if (_done) return;
              final v = cap.barcodes
                  .map((b) => b.rawValue)
                  .whereType<String>()
                  .firstOrNull;
              if (v != null && v.isNotEmpty) {
                _done = true;
                HapticFeedback.mediumImpact();
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
            child: Text(
              'Наведите камеру на QR-код',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Color(0xFFE5E5EA)),
            ),
          ),
        ],
      ),
    );
  }
}
