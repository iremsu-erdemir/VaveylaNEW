import 'package:image_picker/image_picker.dart';

Future<XFile?> pickAndSaveImage(ImageSource source) async {
  final picker = ImagePicker();
  return picker.pickImage(
    source: source,
    maxWidth: 800,
    imageQuality: 85,
  );
}
