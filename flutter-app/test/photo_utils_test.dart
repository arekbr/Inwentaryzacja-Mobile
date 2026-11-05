import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mobile/photo/photo_utils.dart';

void main() {
  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('photo_utils_test'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  Future<String> writePhotoWithLocation({int size = 32}) async {
    final image = img.Image(width: size, height: size);
    image.exif.gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');
    image.exif.imageIfd.imageDescription = 'test';
    final bytes = img.encodeJpg(image);
    expect(
      img.decodeJpg(Uint8List.fromList(bytes))!.exif.gpsIfd.isEmpty,
      isFalse,
      reason: 'próbka musi zawierać GPS, inaczej test niczego nie dowodzi',
    );
    final file = File('${tempDir.path}/photo.jpg')..writeAsBytesSync(bytes);
    return file.path;
  }

  test('wysyłane zdjęcie nie zawiera metadanych EXIF, w tym GPS', () async {
    final processed = await resizeForUpload(await writePhotoWithLocation());

    final sent = img.decodeJpg(processed.bytes)!;
    expect(sent.exif.gpsIfd.isEmpty, isTrue);
    expect(sent.exif.imageIfd.isEmpty, isTrue);
  });

  test('skalowanie także usuwa metadane', () async {
    final processed = await resizeForUpload(
      await writePhotoWithLocation(size: 64),
      maxDim: 32,
    );

    expect(processed.width, 32);
    expect(img.decodeJpg(processed.bytes)!.exif.gpsIfd.isEmpty, isTrue);
  });
}
