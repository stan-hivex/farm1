import 'dart:convert';
import 'dart:typed_data';
import '/backend/services/api_service.dart';

class KycApiService {
  static Future<List<String>> uploadImages({
    required List<String> base64Images,
    required List<String> filenames,
    required List<String> mimeTypes,
  }) =>
      ApiService.uploadImages(
        files: base64Images.map(base64Decode).cast<Uint8List>().toList(),
        filenames: filenames,
        mimeTypes: mimeTypes,
      );
}
