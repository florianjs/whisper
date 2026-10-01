import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import '../l10n/app_localizations.dart';
import '../logic/auto_lock.dart';
import '../logic/contact_code.dart';
import '../theme/tokens.dart';

/// Scans a Whisper contact QR code with ZXing (on-device, no Google ML Kit,
/// nothing leaves the phone). Pops with the parsed [ContactCode].
Future<ContactCode?> scanContactCode(BuildContext context) =>
    scanCode(context, parseContactCode);

/// Scans a QR code and pops with [parse]'s result once it accepts one.
Future<T?> scanCode<T extends Object>(
  BuildContext context,
  T? Function(String) parse,
) => AutoLock.suspendWhile(
  () => Navigator.of(
    context,
  ).push<T>(MaterialPageRoute(builder: (_) => ScanScreen<T>(parse: parse))),
);

class ScanScreen<T extends Object> extends StatefulWidget {
  const ScanScreen({super.key, required this.parse});

  final T? Function(String) parse;

  @override
  State<ScanScreen<T>> createState() => _ScanScreenState<T>();
}

class _ScanScreenState<T extends Object> extends State<ScanScreen<T>> {
  bool _done = false;
  String? _error;

  void _onScan(Code code) {
    if (_done) return;
    final text = code.text;
    final parsed = text == null ? null : widget.parse(text);
    if (parsed == null) {
      setState(() => _error = AppLocalizations.of(context).scanInvalid);
      return;
    }
    _done = true;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.c;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(l.scanQr, style: const TextStyle(color: Colors.white)),
      ),
      body: Stack(
        children: [
          ReaderWidget(
            onScan: _onScan,
            codeFormat: Format.qrCode,
            // Gallery import would need storage access: not offered.
            showGallery: false,
            showToggleCamera: false,
            tryHarder: true,
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: SafeArea(
              top: false,
              child: Center(
                child: AnimatedSwitcher(
                  duration: AppMotion.normal,
                  child: Container(
                    key: ValueKey(_error),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: _error == null
                            ? Colors.white.withValues(alpha: 0.15)
                            : c.danger.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _error == null
                              ? Icons.qr_code_scanner_rounded
                              : Icons.error_outline_rounded,
                          color: _error == null ? Colors.white : c.danger,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _error ?? l.scanHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _error == null ? Colors.white : c.danger,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
