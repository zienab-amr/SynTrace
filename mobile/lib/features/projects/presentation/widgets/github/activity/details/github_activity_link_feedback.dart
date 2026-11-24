import 'package:flutter/material.dart';

void showGitHubActivityLinkError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Unable to open the source link.')),
  );
}
