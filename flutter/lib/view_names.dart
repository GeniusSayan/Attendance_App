import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ViewNames extends StatefulWidget {
  const ViewNames({super.key, required this.section});
  final String section;
  @override
  State<ViewNames> createState() => _ViewNamesState();
}

class _ViewNamesState extends State<ViewNames> {
  List<String> names = [];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    checkNames();
  }

  Future<void> checkNames() async {
    var url = Uri.parse(
        "https://sparrow-aware-silkworm.ngrok-free.app/view_students");

    try {
      var response = await http.post(url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"section": widget.section})).timeout(Duration(seconds: 10));
        
      if (response.statusCode == 200) {
        print(jsonDecode(response.body));
        List<dynamic> data = jsonDecode(response.body);
        setState(() {
          names =
            data.map((item) => item['name'].toString()).toList();
        }); // Decode JSON response
        print(names);
      }
    } on TimeoutException {
      print("Server Timed Out");
    } on SocketException {
      print("Server Unable to connect");
    } catch (e) {
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          "Registered Persons",
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 35,
              color: theme.primaryColor),
        ),
      ),
      body: names.isEmpty
          ? Center(
              child: Text(
              "No Registered Names",
              style: TextStyle(
                  fontSize: 30, fontWeight: FontWeight.bold, color: Colors.red),
            ))
          : ListView.builder(
              itemCount: names.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 20,vertical: 10),
                  child: Text("• ${names[index]}" , style: TextStyle(fontSize: 20 , fontWeight: FontWeight.bold),),
                );
              }),
    );
  }
}
