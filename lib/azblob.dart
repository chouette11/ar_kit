import 'dart:typed_data';

import 'package:azblob/azblob.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';

Future uploadImageToAzure(BuildContext context, Uint8List content) async {
  try {
    var now = DateTime.now();
    String fileName = "test${now.toString()}";
    // read file as Uint8List
    var storage = AzureStorage.parse(dotenv.env['CONNECTION_KEY']);
    String container = "images";
    // get the mine type of the file
    await storage.putBlob(
        '/$container/$fileName',
        bodyBytes: content,
        contentType: 'image/jpg',
        type: BlobType.BlockBlob);
    print("done");
  } on AzureStorageException catch (ex) {
    print(ex.message);
  } catch (err) {
    print(err);
  }
}

Future<Uint8List> getImage() async {
  final ImagePicker _picker = ImagePicker();
  var _imageFile = await _picker.pickImage(source: ImageSource.gallery);
  Uint8List content = await _imageFile!.readAsBytes();
  return content;
}