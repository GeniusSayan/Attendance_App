import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ViewNamesSection extends StatefulWidget {
  const ViewNamesSection({super.key});

  @override
  State<ViewNamesSection> createState() => _ViewNamesSectionState();
}

class _ViewNamesSectionState extends State<ViewNamesSection> {
  List<String> names = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchNames();
  }

  Future<void> fetchNames() async {
    var url = Uri.parse("https://sparrow-aware-silkworm.ngrok-free.app/view_students");

    try {
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({}), // No section needed
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        setState(() {
          names = data.map((item) => item['name'].toString()).toList();
          loading = false;
        });
      } else {
        setState(() {
          loading = false;
        });
        print("Server error: ${response.statusCode}");
      }
    } on TimeoutException {
      setState(() {
        loading = false;
      });
      print("Server Timed Out");
    } on SocketException {
      setState(() {
        loading = false;
      });
      print("Server Unable to connect");
    } catch (e) {
      setState(() {
        loading = false;
      });
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Registered Persons",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 28,
            color: theme.primaryColor,
          ),
        ),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : names.isEmpty
          ? const Center(
        child: Text(
          "No Registered Names",
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
        ),
      )
          : ListView.builder(
        itemCount: names.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "• ${names[index]}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          );
        },
      ),
    );
  }
}
