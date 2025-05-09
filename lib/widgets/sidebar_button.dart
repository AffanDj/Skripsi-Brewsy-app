import 'package:flutter/material.dart';

class SidebarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  SidebarButton({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Container(
          width: double.infinity,  // Membuat lebar container penuh
          height: 60,  // Menetapkan tinggi tetap agar ukuran tombol konsisten
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF003049) : Colors.transparent,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? Colors.white : Colors.black),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(color: selected ? Colors.white : Colors.black),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
