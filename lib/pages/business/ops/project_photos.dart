import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Opens the gallery. iOS needs photo-library permission. Android 13+ uses the
/// system photo picker, so it does not ask for broad storage access.
Future<XFile?> pickProjectPhoto() async {
  final allowed = await _photosAllowed();
  if (!allowed) {
    throw StateError(
      'Allow photo access in Settings, then try the upload again.',
    );
  }
  return ImagePicker().pickImage(
    source: ImageSource.gallery,
    imageQuality: 85,
    maxWidth: 2000,
  );
}

Future<List<XFile>> pickProjectPhotos() async {
  final allowed = await _photosAllowed();
  if (!allowed) {
    throw StateError(
      'Allow photo access in Settings, then try the upload again.',
    );
  }
  return ImagePicker().pickMultiImage(imageQuality: 85, maxWidth: 2000);
}

Future<bool> _photosAllowed() async {
  if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) return true;
  final status = await Permission.photos.request();
  return status.isGranted || status.isLimited;
}

/// Center-crops a cover to 16:9, shrinks gallery photos, and encodes JPEG
/// under the 5 MB upload limit.
Uint8List prepareProjectImage(Uint8List bytes, {bool cover = false}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Could not read that photo. Try another one.');
  }
  var picture = cover ? _coverCrop(decoded) : decoded;
  if (picture.width > 1600) {
    picture = img.copyResize(picture, width: 1600);
  }
  var quality = 80;
  var encoded = Uint8List.fromList(img.encodeJpg(picture, quality: quality));
  while (encoded.length > 4 * 1024 * 1024 && quality > 40) {
    quality -= 10;
    encoded = Uint8List.fromList(img.encodeJpg(picture, quality: quality));
  }
  if (encoded.length > 5 * 1024 * 1024) {
    picture = img.copyResize(picture, width: 1024);
    encoded = Uint8List.fromList(img.encodeJpg(picture, quality: 60));
  }
  if (encoded.length > 5 * 1024 * 1024) {
    throw StateError('That photo is still too large after cropping.');
  }
  return encoded;
}

img.Image _coverCrop(img.Image source) {
  const ratio = 16 / 9;
  final current = source.width / source.height;
  if ((current - ratio).abs() < 0.02) return source;
  if (current > ratio) {
    final width = (source.height * ratio).round();
    final x = ((source.width - width) / 2).round();
    return img.copyCrop(
      source,
      x: x,
      y: 0,
      width: width,
      height: source.height,
    );
  }
  final height = (source.width / ratio).round();
  final y = ((source.height - height) / 2).round();
  return img.copyCrop(
    source,
    x: 0,
    y: y,
    width: source.width,
    height: height,
  );
}
