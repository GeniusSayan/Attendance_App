import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:async/async.dart';
import 'package:path/path.dart';

class AddPersonPage extends StatefulWidget {
  const AddPersonPage({super.key});

  @override
  State<AddPersonPage> createState() => _AddPersonPageState();
}

class _AddPersonPageState extends State<AddPersonPage> {
  String statusString = "Not Started";
  bool statusSignal = true;
  final ImagePicker _picker = ImagePicker();
  File? imagePath;
  final TextEditingController controller = TextEditingController();

  Future<void> pickImage(String name) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);

      if (image == null) {
        setState(() {
          statusSignal = false;
          statusString = "No image selected";
        });
        return;
      }

      File file = File(image.path);
      setState(() {
        imagePath = file;
      });
      await sendPicture(name, file);
    } catch (e) {
      setState(() {
        statusSignal = false;
        statusString = "Error picking image";
      });
    }
  }

  Future<void> sendPicture(String name, File file) async {
    var url = Uri.parse("https://sparrow-aware-silkworm.ngrok-free.app/add_person");
    var request = http.MultipartRequest('POST', url);
    var stream = http.ByteStream(DelegatingStream.typed(file.openRead()));
    var length = await file.length();
    var multipartFile = http.MultipartFile('image', stream, length,
        filename: basename(file.path));

    request.fields['name'] = name;
    request.files.add(multipartFile);

    setState(() {
      statusString = "Uploading...";
      statusSignal = true;
    });

    try {
      var response = await request.send().timeout(const Duration(seconds: 120));
      if (response.statusCode == 200) {
        setState(() {
          statusSignal = true;
          statusString = "Upload Successful ✅";
        });
      } else {
        setState(() {
          statusSignal = false;
          statusString = "Upload Failed ❌";
        });
      }
    } on TimeoutException {
      setState(() {
        statusSignal = false;
        statusString = "Server Timed Out";
      });
    } on SocketException {
      setState(() {
        statusSignal = false;
        statusString = "Server Connection Error";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Add Person",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 28,
            color: theme.primaryColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Text(
                "Status: $statusString",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: statusSignal ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 25),
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    labelText: "Name",
                    hintText: "Enter person name",
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    pickImage(controller.text.trim());
                  } else {
                    setState(() {
                      statusSignal = false;
                      statusString = "Please enter a name first";
                    });
                  }
                },
                icon: const Icon(Icons.camera_alt, size: 28),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    "Capture & Upload",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              if (imagePath != null)
                Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(width: 2, color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(imagePath!),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
