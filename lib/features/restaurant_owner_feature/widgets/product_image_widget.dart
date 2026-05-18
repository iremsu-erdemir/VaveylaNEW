import 'package:flutter/material.dart';

import 'product_image_widget_stub.dart'
    if (dart.library.io) 'product_image_widget_io.dart' as impl;

Widget buildProductImage(String imagePath, double width, double height) {
  if (imagePath.isEmpty) {
    return Image.asset(
      'assets/images/logo.png',
      width: width,
      height: height,
      fit: BoxFit.cover,
    );
  }
  if (imagePath.startsWith('assets/')) {
    return Image.asset(
      imagePath,
      width: width,
      height: height,
      fit: BoxFit.cover,
    );
  }
  if (imagePath.startsWith('blob:') || imagePath.startsWith('http')) {
    return Image.network(
      imagePath,
      width: width,
      height: height,
      fit: BoxFit.cover,
    );
  }
  return impl.buildProductFileImage(imagePath, width, height);
}
