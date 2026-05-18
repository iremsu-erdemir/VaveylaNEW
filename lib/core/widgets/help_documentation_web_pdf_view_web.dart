import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

final Set<String> _registeredViewTypes = <String>{};

Widget buildHelpDocumentationWebPdfViewImpl(String assetPath) {
  final String pdfUrl = Uri.base.resolve(assetPath).toString();
  final String viewType = 'help-doc-pdf-${assetPath.hashCode}';

  if (_registeredViewTypes.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe =
          html.IFrameElement()
            ..src = pdfUrl
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%';
      return iframe;
    });
  }

  return HtmlElementView(viewType: viewType);
}
