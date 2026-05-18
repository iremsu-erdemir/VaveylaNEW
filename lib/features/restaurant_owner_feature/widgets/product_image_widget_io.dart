import 'dart:io';

import 'package:flutter/material.dart';

Widget buildProductFileImage(String path, double width, double height) {
  return Image.file(
    File(path),
    width: width,
    height: height,
    fit: BoxFit.cover,
  );
}
