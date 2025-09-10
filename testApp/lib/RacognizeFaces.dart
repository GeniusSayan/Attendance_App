import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;

class RecognizeFaces extends StatefulWidget {
  const RecognizeFaces({super.key});

  @override
  State<RecognizeFaces> createState() => _RecognizeFacesState();
}

class _RecognizeFacesState extends State<RecognizeFaces> {
  final ImagePicker _picker = ImagePicker();
  File? imageFile;
  Uint8List? processedImageBytes;
  String status = "Not Started";
  bool statusState = true;
  List<String> names = [];
  int recognisedFaceCount = 0;

  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;

      setState(() {
        imageFile = File(image.path);
        names = [];
        processedImageBytes = null;
        recognisedFaceCount = 0;
        status = "Not Started";
        statusState = true;
      });
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  Future<void> sendPicture() async {
    if (imageFile == null) {
      setState(() {
        status = "Select an Image First";
        statusState = false;
      });
      return;
    }

    var url = Uri.parse("https://sparrow-aware-silkworm.ngrok-free.app/recognize_face");
    var request = http.MultipartRequest('POST', url);

    var stream = http.ByteStream(imageFile!.openRead());
    var length = await imageFile!.length();
    var multipartFile = http.MultipartFile('image', stream, length, filename: basename(imageFile!.path));
    request.files.add(multipartFile);

    setState(() {
      status = "🟢 Recognizing...";
      statusState = true;
    });

    try {
      var response = await request.send().timeout(Duration(seconds: 120));
      var responseBody = await response.stream.bytesToString();
      var jsonData = jsonDecode(responseBody);

      if (response.statusCode == 200) {
        List<dynamic> faceData = jsonData['data'] ?? [];
        String? base64Image = jsonData['processed_image']; // Assuming single image

        setState(() {
          names = faceData.map((e) => e.toString()).toList();
          recognisedFaceCount = faceData.length;
          processedImageBytes = base64Image != null ? base64Decode(base64Image) : null;
          status = names.isEmpty ? "⚠️ No Face Detected" : "✅ Recognition Complete";
          statusState = names.isNotEmpty;
        });
      } else {
        setState(() {
          status = "⚠️ Server Error: ${response.statusCode}";
          statusState = false;
        });
      }
    } on TimeoutException {
      setState(() {
        status = "⚠️ Server Timed Out";
        statusState = false;
      });
    } on SocketException {
      setState(() {
        status = "⚠️ Unable to Connect";
        statusState = false;
      });
    } catch (e) {
      setState(() {
        status = "Error: $e";
        statusState = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Recognize Faces",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28, color: theme.primaryColor),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 20),
            imageFile != null
                ? Container(
              margin: EdgeInsets.symmetric(horizontal: 30),
              decoration: BoxDecoration(border: Border.all(width: 2), borderRadius: BorderRadius.circular(12)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: processedImageBytes != null
                    ? Image.memory(processedImageBytes!)
                    : Image.file(imageFile!),
              ),
            )
                : SizedBox(),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => pickImage(ImageSource.camera),
                  icon: Icon(Icons.camera_alt),
                  label: Text("Camera"),
                ),
                ElevatedButton.icon(
                  onPressed: () => pickImage(ImageSource.gallery),
                  icon: Icon(Icons.photo),
                  label: Text("Gallery"),
                ),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: sendPicture,
              icon: Icon(Icons.face),
              label: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  "Recognize",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              "Status: $status",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statusState ? Colors.green : Colors.red),
            ),
            SizedBox(height: 10),
            Text(
              "Recognized Faces: $recognisedFaceCount",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: ClampingScrollPhysics(),
              itemCount: names.length,
              itemBuilder: (context, index) => Container(
                padding: EdgeInsets.all(10),
                margin: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(width: 2),
                  borderRadius: BorderRadius.circular(50),
                  color: Colors.lightGreenAccent,
                ),
                child: Text(
                  names[index],
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
