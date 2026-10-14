import 'package:flutter/material.dart';
import '../core/constants.dart';

InputDecoration fieldDecoration(
  String label, {
  IconData? icon,
  String? hint,
  String? prefix,
  Widget? suffix,
}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefix,
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(kBorder),
    enabledBorder: border(kBorder),
    focusedBorder: border(kPrimary, 1.6),
    errorBorder: border(kError),
    focusedErrorBorder: border(kError, 1.6),
  );
}

void showMessage(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? kError : kPrimaryDark,
      behavior: SnackBarBehavior.floating,
    ));
}
