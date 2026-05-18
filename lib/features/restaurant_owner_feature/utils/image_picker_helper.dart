import 'image_picker_helper_stub.dart'
    if (dart.library.io) 'image_picker_helper_io.dart' as impl;

import 'package:image_picker/image_picker.dart';

Future<XFile?> pickAndSaveImage(ImageSource source) {
  return impl.pickAndSaveImage(source);
}
