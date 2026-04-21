import 'dart:io';
import 'package:cloudinary/cloudinary.dart';
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  final cloudinary = Cloudinary.signedConfig(
    cloudName: 'your_cloud_name',
    apiKey: 'your_api_key',
    apiSecret: 'your_api_secret',
  );

  // Upload image from file
  Future<String> uploadImage(File imageFile) async {
    try {
      final response = await cloudinary.upload(
        file: imageFile.path,
        fileBytes: await imageFile.readAsBytes(),
        resourceType: CloudinaryResourceType.image,
        folder: 'raina_app',
      );

      return response.secureUrl!;
    } catch (e) {
      rethrow;
    }
  }

  // Upload image from camera/gallery
  Future<String> uploadImageFromPicker(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      return await uploadImage(File(pickedFile.path));
    }
    throw Exception('No image selected');
  }

  // Delete image
  Future<void> deleteImage(String publicId) async {
    await cloudinary.destroy(publicId);
  }
}
