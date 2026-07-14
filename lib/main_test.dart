// Test-only driver entry point; flutter_driver intentionally remains a dev dependency.
// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_driver/driver_extension.dart';

import 'main.dart' as app;

Future<void> main() async {
  enableFlutterDriverExtension();
  await app.main();
}
