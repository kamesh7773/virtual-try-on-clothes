import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// The shopper's snapshot, ready to show and to send.
///
/// Kept as JPEG bytes: the screens show them, and the upload sends them.
@immutable
class StylePhoto {
  final Uint8List bytes;

  const StylePhoto(this.bytes);

  /// The longest side the service is sent. It resizes to 1440 on its side
  /// anyway; a full camera frame is several megabytes over a mobile network
  /// for no better a result.
  static const int maxSide = 1440;

  static const int quality = 88;

  /// Decodes, straightens and shrinks a captured or picked image off the UI
  /// isolate. Null when the bytes are not an image this app can read.
  static Future<StylePhoto?> prepare(Uint8List source) async {
    final bytes = await compute(_prepare, source);
    return bytes == null ? null : StylePhoto(bytes);
  }
}

Uint8List? _prepare(Uint8List source) {
  final decoded = img.decodeImage(source);
  if (decoded == null) return null;

  // Phone cameras write the rotation into EXIF rather than the pixels; a
  // thumbnail drawn from the bytes shows the pixels.
  var image = img.bakeOrientation(decoded);

  final longest = image.width > image.height ? image.width : image.height;
  if (longest > StylePhoto.maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: StylePhoto.maxSide)
        : img.copyResize(image, height: StylePhoto.maxSide);
  }

  return img.encodeJpg(image, quality: StylePhoto.quality);
}

/// The server's handle on an uploaded [StylePhoto], and how long it lasts.
@immutable
class UploadedPhoto {
  final String id;
  final DateTime expiresAt;

  const UploadedPhoto({required this.id, required this.expiresAt});

  /// Whether the id can still be sent. Judged a little early: a look asked
  /// for in the last minute of the id's life would be refused mid-flight.
  bool isUsableAt(DateTime now) =>
      now.isBefore(expiresAt.subtract(const Duration(minutes: 1)));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UploadedPhoto && id == other.id && expiresAt == other.expiresAt;

  @override
  int get hashCode => Object.hash(id, expiresAt);
}
