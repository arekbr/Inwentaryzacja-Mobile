import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class ProcessedPhoto {
  final Uint8List bytes;
  final int width;
  final int height;
  final int sizeBytes;

  const ProcessedPhoto({
    required this.bytes,
    required this.width,
    required this.height,
    required this.sizeBytes,
  });
}

Future<ProcessedPhoto> resizeForUpload(
  String path, {
  int maxDim = 2048,
  int quality = 85,
}) async {
  final raw = await File(path).readAsBytes();
  final decoded = img.decodeImage(raw);
  if (decoded == null) {
    throw const FormatException('Nie udało się zdekodować obrazu.');
  }

  img.Image normalized = img.bakeOrientation(decoded);
  if (normalized.width > maxDim || normalized.height > maxDim) {
    final scale = maxDim / (normalized.width > normalized.height
        ? normalized.width
        : normalized.height);
    normalized = img.copyResize(
      normalized,
      width: (normalized.width * scale).round(),
      height: (normalized.height * scale).round(),
      interpolation: img.Interpolation.linear,
    );
  }

  final jpeg = img.encodeJpg(normalized, quality: quality);
  return ProcessedPhoto(
    bytes: Uint8List.fromList(jpeg),
    width: normalized.width,
    height: normalized.height,
    sizeBytes: jpeg.length,
  );
}
