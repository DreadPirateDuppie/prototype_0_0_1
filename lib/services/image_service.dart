import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageService {
  /// Compress image to reduce file size
  static Future<File?> compressImage(File imageFile) async {
    try {
      print('ImageService: Starting compression for ${imageFile.path}');
      
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';
      
      print('ImageService: Target path: $targetPath');

      // Compress image
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: 85,
        minWidth: 1920,
        minHeight: 1080,
        format: CompressFormat.jpeg,
      );

      if (compressedFile != null) {
        final compressedFileObj = File(compressedFile.path);
        if (await compressedFileObj.length() == 0) {
          print('ImageService: Compressed file is 0 bytes, using original file');
          return imageFile;
        }
        print('ImageService: Compression successful, path: ${compressedFile.path}');
        return compressedFileObj;
      } else {
        print('ImageService: Compression returned null, using original file');
        return imageFile;
      }
    } catch (e, stackTrace) {
      print('ImageService: Compression error: $e');
      print('ImageService: Stack trace: $stackTrace');
      // Return original if compression fails
      return imageFile;
    }
  }

  /// Get file size in MB
  static Future<double> getFileSizeMB(File file) async {
    final bytes = await file.length();
    return bytes / (1024 * 1024);
  }
}
