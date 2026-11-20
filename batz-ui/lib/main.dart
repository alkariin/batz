import 'package:flutter/material.dart';

import 'app.dart';
import 'services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    runApp(BatzApp(services: await AppServices.open()));
  } catch (error) {
    runApp(StartupErrorApp(error: error));
  }
}
