import 'package:face_recognizer/view_names.dart';
import 'package:flutter/material.dart';

class ViewNamesSelectionPage extends StatefulWidget {
  const ViewNamesSelectionPage({super.key});

  @override
  State<ViewNamesSelectionPage> createState() => _ViewNamesSelectionPageState();
}

class _ViewNamesSelectionPageState extends State<ViewNamesSelectionPage> {
  List<String> sections = ["F" , "G" , "H" , "I" , "J"];
  String? selectedSection;

  @override
  Widget build(BuildContext context) {
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
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
          SizedBox(height: 20,),
          ElevatedButton(
            onPressed: () {
              if(selectedSection != null) {
                Navigator.push(context, MaterialPageRoute(builder: (context)=>ViewNames(section: selectedSection!,)));
              }
            },
            child: Text("Next" , style: TextStyle(fontSize: 20 , fontWeight: FontWeight.bold),)
          )
        ],
      ),
    );
  }
}
