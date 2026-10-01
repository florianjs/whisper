import 'package:flutter/services.dart';

import 'auto_lock.dart';

/// Android's document picker (Storage Access Framework): the user chooses
/// where a file goes or comes from; the app holds no storage permission.
abstract final class PlatformFiles {
  static const _channel = MethodChannel('whisper/files');

  /// False if the user cancelled.
  static Future<bool> save(String name, Uint8List bytes) async =>
      await AutoLock.suspendWhile(
        () =>
            _channel.invokeMethod<bool>('save', {'name': name, 'bytes': bytes}),
      ) ==
      true;

  /// Null if the user cancelled.
  static Future<Uint8List?> open() =>
      AutoLock.suspendWhile(() => _channel.invokeMethod<Uint8List>('open'));
}
