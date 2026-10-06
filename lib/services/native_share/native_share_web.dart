import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'native_share.dart';

JSObject get _navigator => web.window.navigator as JSObject;

/// `navigator.share` exists on phones and on Safari; `canShare` arrived with
/// file sharing. Both must be present before we try.
bool get isSupported {
  try {
    return _navigator.has('share') && _navigator.has('canShare');
  } catch (_) {
    return false;
  }
}

/// Opens the device's own share sheet with [bytes] attached as a file.
Future<NativeShareResult> shareFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  String? title,
  String? text,
}) async {
  if (!isSupported) return NativeShareResult.unsupported;

  try {
    final blob = web.Blob(
      <JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final file = web.File(
      <JSAny>[blob].toJS,
      fileName,
      web.FilePropertyBag(type: mimeType),
    );

    final data = JSObject();
    data['files'] = <JSAny>[file].toJS;
    if (title != null) data['title'] = title.toJS;
    if (text != null) data['text'] = text.toJS;

    // Browsers that can share links but not files return false here.
    final canShare = _navigator.callMethod<JSBoolean>('canShare'.toJS, data);
    if (!canShare.toDart) return NativeShareResult.unsupported;

    await _navigator.callMethod<JSPromise<JSAny?>>('share'.toJS, data).toDart;
    return NativeShareResult.shared;
  } catch (e) {
    // Dismissing the sheet rejects the promise with an AbortError. That is the
    // user saying no, not a failure — don't fall back to a download.
    if (e.toString().contains('AbortError')) {
      return NativeShareResult.cancelled;
    }
    return NativeShareResult.unsupported;
  }
}
