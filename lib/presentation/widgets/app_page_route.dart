import 'package:flutter/material.dart';

class AppPageRoute<T> extends MaterialPageRoute<T> {
  AppPageRoute({required Widget child}) : super(builder: (context) => child);
}

