import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Prepares listing photos before they reach Supabase Storage.
///
/// The goal is to keep phone photos sharp while preventing multi-megabyte
/// originals from becoming the normal network payload of the app.
class ListingImageService {
  static const int maxDimension = 1280;
  static const int jpegQuality = 82;

  static Uint8List compress(Uint8List input) {
    final decoded = img.decodeImage(input);
    if (decoded == null) return input;

    img.Image prepared = decoded;
    if (decoded.width > maxDimension || decoded.height > maxDimension) {
      prepared = img.copyResize(
        decoded,
        width: decoded.width >= decoded.height ? maxDimension : null,
        height: decoded.height > decoded.width ? maxDimension : null,
        interpolation: img.Interpolation.cubic,
      );
    }

    final encoded = img.encodeJpg(prepared, quality: jpegQuality);
    return Uint8List.fromList(encoded);
  }
}
