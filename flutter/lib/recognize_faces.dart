import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:async/async.dart';
// import 'package:face_recognizer/details_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
// import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

class RecognizeFaces extends StatefulWidget {
  const RecognizeFaces({super.key});

  @override
  State<RecognizeFaces> createState() => _RecognizeFacesState();
}

class _RecognizeFacesState extends State<RecognizeFaces> {
  final ImagePicker _picker = ImagePicker();
  BuildContext? currentContext;
  String status = "Not Started";
  bool statusState = true;
  List<String> names = [];
  List<Uint8List> processedImageBytes = []; // Store processed image bytes
  List<File> imagePaths = [];
  List<String> sections = ["F" , "G" , "H" , "I" , "J"];
  String? selectedSection;
  int recognisedFaceCount = 0;

  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);

      if (image == null) {
        print("No image selected");
        return;
      }
      setState(() {
        processedImageBytes = [];
        recognisedFaceCount = 0;
      });
      File file = File(image.path);
      imagePaths.add(file);
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  Future<void> sendPicture() async {
    final http.Client client = http.Client();
    var url = Uri.parse(
        "https://sparrow-aware-silkworm.ngrok-free.app/recognize_face");
    var request = http.MultipartRequest('POST', url);
    request.fields['section'] = selectedSection!;

    for (File file in imagePaths) {
      var stream = http.ByteStream(DelegatingStream.typed(file.openRead()));
      var length = await file.length();
      var multipartFile = http.MultipartFile('image', stream, length,
          filename: basename(file.path));
      request.files.add(multipartFile);
    }

    setState(() {
      status = " 🟢Recognizing";
      statusState = true;
    });

    try {
      var response = await client.send(request).timeout(Duration(seconds: 120));
      var responseBody = await response.stream.bytesToString();
      var jsonData = jsonDecode(responseBody);
      if (response.statusCode == 200) {
        List<dynamic> faceDate = jsonData['data'];
        List<dynamic> base64Image = jsonData['processed_images'];
        setState(() {
          for (int i = 0; i < base64Image.length; i++) {
            processedImageBytes.add(base64Decode(base64Image[i]));
          }
        });
        print("recognised: ${faceDate.length}");
        recognisedFaceCount = faceDate.length;
        if (faceDate.isNotEmpty) {
          for (var data in faceDate) {
            print(data);
            setState(() {
              names.add(data);
            });
            print(names);
          }
        } else {
          setState(() {
            status = "⚠️ No Face Detected";
            statusState = false;
          });
        }
      }
    } on TimeoutException {
      print("Server Timed Out");
      setState(() {
        status = "⚠️ Server Timed Out";
        statusState = false;
      });
    } on SocketException {
      print("Server Unable to connect");
      setState(() {
        status = "⚠️ Server Unable to connect";
        statusState = false;
      });
    } catch (e) {
      print("Error: $e");
      setState(() {
        status = "$e";
        statusState = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    // var details_provider = Provider.of<DetailsProvider>(context);
    currentContext = context;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          "Recognize Faces",
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 35,
              color: theme.primaryColor),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            imagePaths.isEmpty
                ? SizedBox()
                : Container(
                    margin: EdgeInsets.symmetric(horizontal: 40),
                    child: ListView.builder(
                        shrinkWrap: true,
                        physics: ClampingScrollPhysics(),
                        itemCount: imagePaths.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                                border: Border.all(width: 2),
                                borderRadius: BorderRadius.circular(12)),
                            child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: processedImageBytes.isEmpty? Image.file(imagePaths[index]):Image.memory(processedImageBytes[index])),
                          );
                        }),
                  ),
            Container(
              margin: EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                      onPressed: () {
                        setState(() {
                          names = [];
                          status = "Not Started";
                          statusState = true;
                        });
                        pickImage(ImageSource.camera);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 25,
                            ),
                            Text(
                              "Take Picture",
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                            )
                          ],
                        ),
                      )),
                  ElevatedButton(
                      onPressed: () {
                        setState(() {
                          names = [];
                          status = "Not Started";
                          statusState = true;
                        });
                        pickImage(ImageSource.gallery);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 25,
                            ),
                            Text(
                              "Gallery",
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                            )
                          ],
                        ),
                      ))
                ],
              ),
            ),
            SizedBox(
              height: 10,
            ),
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
              height: 20,
            ),
            ElevatedButton(
                onPressed: () {
                  if (selectedSection != null) {
                    setState(() {
                      status = "Not Started";
                      statusState = true;
                      names = [];
                      processedImageBytes = [];
                      recognisedFaceCount = 0;
                    });
                    sendPicture();
                  } else if (imagePaths.isEmpty)  {
                    setState(() {
                      status = "Select a Image First";
                      statusState = false;
                    });
                  }
                  else {
                    setState(() {
                      status = "Select a Section First";
                      statusState = false;
                    });
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Icon(
                        Icons.face,
                        size: 30,
                      ),
                      Text(
                        "Recognise",
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )),
            SizedBox(
              height: 10,
            ),
            Text("Recognised Face Count: $recognisedFaceCount"),
            SizedBox(height: 10,),
            Container(
              child: names.isEmpty
                  ? Container(
                      margin: EdgeInsets.symmetric(horizontal: 30),
                      child: Text(
                        status,
                        style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: statusState ? Colors.green : Colors.red),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: ClampingScrollPhysics(),
                      itemCount: names.length,
                      itemBuilder: (context, index) {
                        return Container(
                          padding: EdgeInsets.all(10),
                          margin: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                              border: Border.all(width: 2),
                              borderRadius: BorderRadius.circular(50),
                              color: statusState
                                  ? Colors.lightGreenAccent
                                  : Colors.red),
                          child: Text(
                            names[index],
                            style: TextStyle(
                                fontSize: 25, fontWeight: FontWeight.bold),
                          ),
                        );
                      }),
            )
          ],
        ),
      ),
    );
  }
}
