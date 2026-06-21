import 'package:flutter/material.dart';

Widget buildProductFileImage(String path, double width, double height) {
  return Container(
    width: width,
    height: height,
    color: Colors.grey[300],
    child: Icon(Icons.image_not_supported, size: 32, color: Colors.grey[600]),
  );
}
