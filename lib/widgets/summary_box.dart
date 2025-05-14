import 'package:flutter/material.dart';

const Color primaryColor = Color(0xFF01479E);
const Color secondaryColor = Color(0xFFFF6F00);
const Color backgroundColor = Color(0xFFF5F7FA);


class SummaryBox extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color borderColor;

  SummaryBox(
      {required this.label, required this.value, required this.subtitle, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: borderColor, width: 6)),
          boxShadow: [
            BoxShadow(
              color: borderColor.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryColor.withOpacity(0.7))),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: primaryColor)),
            const SizedBox(height: 6),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: primaryColor.withOpacity(0.4))),
          ],
        ),
      ),
    );
  }
}
