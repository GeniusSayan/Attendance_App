import 'package:flutter/material.dart';


import 'AddPersonPage.dart';
import 'RacognizeFaces.dart';
import 'ViewNamesSelectionPage.dart';

class OptionPage extends StatelessWidget {
  const OptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Options",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 28,
            color: theme.primaryColor,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildOptionButton(
              context,
              icon: Icons.person_add_alt_1,
              label: "Add a new Person",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddPersonPage()),
              ),
            ),
            const SizedBox(height: 20),
            _buildOptionButton(
              context,
              icon: Icons.people,
              label: "View Added List",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ViewNamesSection()),
              ),
            ),
            const SizedBox(height: 20),
            _buildOptionButton(
              context,
              icon: Icons.face,
              label: "Recognize Face",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RecognizeFaces()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Reusable button widget
  Widget _buildOptionButton(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
      }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 28),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
