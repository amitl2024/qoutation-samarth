import 'dart:typed_data';

import 'native_share.dart';

/// Android, iOS and desktop builds: the `printing` package already opens the
/// real native share sheet there, so this reports unsupported and the caller
/// falls back to it.
bool get isSupported => false;

Future<NativeShareResult> shareFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  String? title,
  String? text,
}) async =>
    NativeShareResult.unsupported;
