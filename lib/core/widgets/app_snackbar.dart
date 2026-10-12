import 'package:flutter/material.dart';
import 'package:yoopn/core/themes/app_colors.dart';

/// The one snackbar style in the app. Pass [isError] for failures,
/// [action] for retry-style snackbars.
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
  SnackBarAction? action,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : null,
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
}
