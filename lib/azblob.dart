import 'dart:typed_data';

import 'package:azblob/azblob.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';

Future uploadImageToAzure(BuildContext context, Uint8List content) async {
  try {
    var now = DateTime.now();
    String fileName = "test${now.toString()}";
    // read file as Uint8List
    var storage = AzureStorage.parse('DefaultEndpointsProtocol=https;AccountName=stortestkeiichiro;AccountKey=X/YAuUAAWwQz8YST5lLj9Tp/noTZAGBAACQaJy/CPTGrefLvFJ0/Xji0Yw4JdpB9z5eEu1FPYMSP93/5sfz5wg==;EndpointSuffix=core.windows.net');
    String container = "test";
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