import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class MemoryMediaService {
  final ImagePicker _picker = ImagePicker();
  FirebaseStorage get _storage => FirebaseStorage.instance;

  /// Picks an image from the specified source (camera or gallery)
  Future<XFile?> pickImage(ImageSource source) async {
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Saves the picked image to the app's document directory for persistence
  Future<String?> saveImageLocally(XFile file) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}${path.extension(file.path)}';
      final localPath = path.join(directory.path, 'memories', fileName);
      
      // Ensure directory exists
      final memoryDir = Directory(path.join(directory.path, 'memories'));
      if (!await memoryDir.exists()) {
        await memoryDir.create(recursive: true);
      }

      final savedImage = await File(file.path).copy(localPath);
      return savedImage.path;
    } catch (e) {
      debugPrint('Error saving image locally: $e');
      return null;
    }
  }

  /// Uploads a local file to Firebase Storage
  Future<String?> uploadToFirebase(String localPath, String userId) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;

      final fileName = path.basename(localPath);
      final storageRef = _storage.ref().child('users/$userId/memories/$fileName');
      
      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask;
      
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading to Firebase Storage: $e');
      return null;
    }
  }

  /// Deletes local file if it exists
  Future<void> deleteLocalFile(String localPath) async {
    try {
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting local file: $e');
    }
  }
}
