import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../constants/help_documentation_constants.dart';
import 'app_scaffold.dart';
import 'general_app_bar.dart';
import 'help_documentation_web_pdf_view.dart';

class HelpDocumentationScreen extends StatelessWidget {
  const HelpDocumentationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      padding: EdgeInsets.zero,
      appBar: const GeneralAppBar(
        title: HelpDocumentationConstants.title,
        showBackIcon: true,
        includeInfoButton: false,
      ),
      body:
          kIsWeb
              ? buildHelpDocumentationWebPdfView(
                HelpDocumentationConstants.pdfAssetPath,
              )
              : SfPdfViewer.asset(HelpDocumentationConstants.pdfAssetPath),
    );
  }
}
