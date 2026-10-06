import 'dart:typed_data';

import 'native_share_stub.dart'
    if (dart.library.js_interop) 'native_share_web.dart' as impl;

/// Outcome of asking the platform to share a file.
enum NativeShareResult {
  /// The OS share sheet opened and the user picked a target.
  shared,

  /// The share sheet opened and the user dismissed it. Nothing more to do —
  /// in particular, do not fall back to downloading the file.
  cancelled,

  /// This platform/browser cannot share files; the caller should fall back.
  unsupported,
}

/// Hands a file to the device's own share system.
///
/// On the web this is the Web Share API, which on a phone opens exactly the
/// sheet the user gets from any other app — WhatsApp, Gmail, Drive, Messages
/// and the rest. Desktop browsers mostly cannot share files, and report
/// [NativeShareResult.unsupported] so the caller can download instead.
///
/// On Android and iOS builds this reports unsupported, because there the
/// `printing` package already opens the real native share sheet.
class NativeShare {
  /// Whether this platform can put a file into the OS share sheet.
  static bool get isSupported => impl.isSupported;

  static Future<NativeShareResult> shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? title,
    String? text,
  }) {
    return impl.shareFile(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      title: title,
      text: text,
    );
  }
}
