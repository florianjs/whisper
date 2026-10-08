import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../data/message_store.dart';
import '../l10n/app_localizations.dart';
import '../logic/secure_platform.dart';
import '../models/message.dart';
import '../logic/auto_lock.dart';
import '../theme/tokens.dart';
import 'app_button.dart';
import 'ui.dart';

/// Gallery or camera, then [pickAndSendImage].
Future<void> attachImage(
  BuildContext context,
  Future<void> Function(({Uint8List bytes, int width, int height})) send,
) async {
  final l = AppLocalizations.of(context);
  final source = await showAppSheet<ImageSource>(
    context,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetAction(
            icon: Icons.photo_library_outlined,
            title: l.photoFromGallery,
            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
          ),
          SheetAction(
            icon: Icons.photo_camera_outlined,
            title: l.photoFromCamera,
            onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return;
  await pickAndSendImage(context, source, send);
}

/// Pick → anonymize → preview (exactly what will be sent) → [send].
Future<void> pickAndSendImage(
  BuildContext context,
  ImageSource source,
  Future<void> Function(({Uint8List bytes, int width, int height})) send,
) async {
  final l = AppLocalizations.of(context);
  final store = context.read<MessageStore>();
  final messenger = ScaffoldMessenger.of(context);
  final file = await AutoLock.suspendWhile(
    () => ImagePicker().pickImage(
      source: source,
      maxWidth: 2560,
      maxHeight: 2560,
      requestFullMetadata: false,
    ),
  );
  if (file == null || !context.mounted) return;
  final ({Uint8List bytes, int width, int height}) prepared;
  try {
    prepared = await store.prepareImage(await file.readAsBytes());
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.photoError)));
    return;
  }
  if (!context.mounted) return;
  final ok = await showAppSheet<bool>(
    context,
    scrollable: true,
    builder: (sheetContext) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.imagePreviewTitle, style: sheetContext.text.titleLarge),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.5,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Image.memory(prepared.bytes, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 14),
          NoticeCard(
            text: l.imageAnonymized,
            icon: Icons.verified_user_outlined,
            color: sheetContext.c.success,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: l.cancel,
                  variant: ButtonVariant.secondary,
                  onPressed: () => Navigator.pop(sheetContext, false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: l.imageSend,
                  icon: Icons.arrow_upward_rounded,
                  onPressed: () => Navigator.pop(sheetContext, true),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  if (ok == true) await send(prepared);
}

/// Image bubble content: the photo, or a placeholder with chunk progress.
class ChatImage extends StatelessWidget {
  const ChatImage({super.key, required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final store = context.watch<MessageStore>();
    final header = message.image!;
    final maxW = MediaQuery.sizeOf(context).width * 0.62;
    final aspect = header.width / header.height;
    final width = maxW;
    final height = (width / aspect).clamp(120.0, maxW * 1.4);
    final progress = store.imageProgress(message);
    // A 1:1 request: nothing rendered before I accept. Groups gate it on
    // their own (only accepted groups store photos).
    final pendingRequest =
        message.groupId == null &&
        !message.fromMe &&
        !store.isAccepted(message.peer);

    final c = context.c;
    Widget placeholder(Widget child) => Container(
      width: width,
      height: height,
      color: c.surface2,
      alignment: Alignment.center,
      child: child,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: pendingRequest
          ? placeholder(
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_outlined, color: c.faint, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      l.imagePendingRequest,
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall?.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
            )
          : FutureBuilder<Uint8List?>(
              future: store.imageFor(message),
              builder: (context, snap) {
                final bytes = snap.data;
                if (bytes == null) {
                  final p = progress;
                  return placeholder(
                    message.status == MessageStatus.receiving
                        ? _Progress(value: p == null ? null : p.$1 / p.$2)
                        : snap.connectionState == ConnectionState.done
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.broken_image_outlined,
                                color: c.faint,
                                size: 28,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l.imageUnavailable,
                                style: context.text.bodySmall?.copyWith(
                                  color: c.muted,
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  );
                }
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    PageRouteBuilder<void>(
                      opaque: false,
                      pageBuilder: (_, a, _) => FadeTransition(
                        opacity: a,
                        child: _Viewer(bytes: bytes),
                      ),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.memory(
                        bytes,
                        width: width,
                        height: height,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        cacheWidth:
                            (width * MediaQuery.devicePixelRatioOf(context))
                                .round(),
                      ),
                      if (progress != null)
                        Positioned.fill(
                          child: ColoredBox(
                            color: Colors.black38,
                            child: Center(
                              child: _Progress(
                                value: progress.$1 / progress.$2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.value});

  final double? value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 36,
    height: 36,
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: value ?? 0),
      duration: AppMotion.normal,
      builder: (context, v, _) => CircularProgressIndicator(
        value: value == null ? null : v,
        strokeWidth: 3,
        strokeCap: StrokeCap.round,
        color: context.c.accent,
        backgroundColor: Colors.white24,
      ),
    ),
  );
}

/// Full-screen, zoomable, screenshots blocked. No "save" action on purpose.
class _Viewer extends StatefulWidget {
  const _Viewer({required this.bytes});

  final Uint8List bytes;

  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> {
  @override
  void initState() {
    super.initState();
    SecurePlatform.acquireSecureScreen();
  }

  @override
  void dispose() {
    SecurePlatform.releaseSecureScreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: InteractiveViewer(
            maxScale: 5,
            child: Image.memory(widget.bytes, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
