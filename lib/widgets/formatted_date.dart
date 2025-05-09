import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Widget getFormattedDate() {
  DateTime now = DateTime.now().toLocal();
  String dayName = DateFormat('EEEE', 'id_ID').format(now); // Hari dalam Bahasa Indonesia
  String formattedDate = DateFormat('d MMMM yyyy', 'id_ID').format(now); // Format tanggal dengan locale Indonesia
  String formattedTime = DateFormat('HH:mm').format(now); // Format waktu lokal dengan benar

  String fullDate = '$formattedDate $dayName | $formattedTime';

  return Text(
    fullDate,
    style: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    ),
  );
}
