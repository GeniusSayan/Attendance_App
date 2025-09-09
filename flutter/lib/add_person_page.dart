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
  BuildContext? currentContext;
  File? imagePath;
  List<String> sections = ["F" , "G" , "H" , "I" , "J"];
  String? selectedSection;
  final TextEditingController controller = TextEditingController();

  Future<void> pickImage(String name, ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);

      if (image == null) {
        print("No image selected");
        return;
      }

      File file = File(image.path);
      setState(() {
        imagePath = file;
      });
      await sendPicture(name, file);
    } catch (e) {
      print("Error picking image: $e");
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
    request.fields['section'] = selectedSection!;
    request.files.add(multipartFile);

    setState(() {
      statusString = "Sending";
      statusSignal = true;
    });

    try {
      var response = await request.send().timeout(Duration(seconds: 120));
      if(response.statusCode == 200) {
        setState(() {
          statusSignal = true;
          statusString = "Send";
        });
      }
    } on TimeoutException {
      print("Server Timed Out");
      setState(() {
        statusSignal = false;
        statusString = "Server Timed Out";
      });
    } on SocketException {
      print("Server Unable to connect");
      setState(() {
        statusSignal = false;
        statusString = "Server Unable to connect";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    currentContext = context;
    var theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          "Add new Person",
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 35,
              color: theme.primaryColor),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: EdgeInsets.all(20),
                child: Text(
                  "Status: $statusString",
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: statusSignal ? Colors.green : Colors.red),
                ),
              ),
              SizedBox(
                height: 5,
              ),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 25),
                child: TextField(
                  controller: controller,
                  onTapOutside: (event) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20)),
                    label: Text("Name"),
                    hintText: "Enter your name",
                  ),
                ),
              ),
              SizedBox(height: 10,),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 25),
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(border: OutlineInputBorder()),
                  borderRadius: BorderRadius.circular(20),
                  // value: detailsProvider.selectedSection,
                  hint: Text(
                    "Select Section",
                    style: TextStyle(fontSize: 20),
                  ),
                  items: sections
                      .map((dept) => DropdownMenuItem(
                            value: dept,
                            child: Text(
                              dept,
                              style: TextStyle(fontSize: 17),
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedSection = value;
                    });
                  },
                ),
              ),
              SizedBox(
                height: 10,
              ),
              ElevatedButton(
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty && selectedSection != null) {
                      statusSignal = true;
                      pickImage(controller.text, ImageSource.camera);
                    } else if (controller.text.trim().isEmpty) {
                      setState(() {
                        statusSignal = false;
                        statusString = "Enter the name first";
                      });
                    }
                    else {
                      setState(() {
                        statusSignal = false;
                        statusString = "Enter the Section";
                      });
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(10),
                    child: Column(
                      children: [
                        Icon(
                          Icons.camera_alt,
                          size: 25,
                        ),
                        Text(
                          "Take Picture",
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        )
                      ],
                    ),
                  )
                ),
              Container(
                child: imagePath == null
                    ? null
                    : Container(
                        margin: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          border: Border.all(width: 2),
                          borderRadius: BorderRadius.circular(12)
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(imagePath!)
                        )
                    ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
