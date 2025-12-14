import 'package:flutter/material.dart';

void notify(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
    ),
  );
}
