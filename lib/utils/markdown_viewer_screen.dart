import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart'; // Corrected import

class MarkdownViewerScreen extends StatelessWidget {
  final String title;
  final String markdownAssetPath;

  const MarkdownViewerScreen({
    super.key,
    required this.title,
    required this.markdownAssetPath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(title.tr()),
      ),
      body: FutureBuilder(
        future: rootBundle.loadString(markdownAssetPath),
        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
          if (snapshot.hasData) {
            return Markdown(data: snapshot.data!); // Use Markdown widget
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                "${"error_loading_markdown".tr()}: ${snapshot.error}",
              ),
            );
          }
          return Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
