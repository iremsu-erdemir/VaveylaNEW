import 'help_documentation_web_pdf_view_stub.dart'
    if (dart.library.html) 'help_documentation_web_pdf_view_web.dart';

import 'package:flutter/widgets.dart';

Widget buildHelpDocumentationWebPdfView(String assetPath) {
  return buildHelpDocumentationWebPdfViewImpl(assetPath);
}
