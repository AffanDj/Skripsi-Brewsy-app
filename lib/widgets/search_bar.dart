import 'package:flutter/material.dart';

class CustomSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String searchLabel;


  CustomSearchBar({required this.controller , required this.searchLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: searchLabel,
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.search),
        ),
      ),
    );
  }
}
