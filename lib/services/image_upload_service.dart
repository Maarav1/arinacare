import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ImageUploadService {
  static Future<String?> uploadProfileImage(File imageFile, String userId) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'generateCloudinarySignature',
      );

      final results = await callable();
      final signature = results.data['signature'];
      final timestamp = results.data['timestamp'].toString();
      final apiKey = results.data['api_key'];
      final cloudName = results.data['cloud_name'];
      final folder = results.data['folder'];

      final uploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl))
        ..fields['api_key'] = apiKey
        ..fields['timestamp'] = timestamp
        ..fields['signature'] = signature
        ..fields['folder'] = folder
        ..files.add(
          await http.MultipartFile.fromPath('file', imageFile.path),
        );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseData);

      if (response.statusCode == 200) {
        return jsonResponse['secure_url'];
      } else {
        throw 'Upload failed: ${response.reasonPhrase}';
      }
    } catch (e) {
      throw 'Image upload failed: ${e.toString()}';
    }
  }
}