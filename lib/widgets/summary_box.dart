import 'package:flutter/material.dart';

class SummaryBox extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;

  SummaryBox({required this.label, required this.value, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFF1A72DD),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 16, color: Colors.white)),
            SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
