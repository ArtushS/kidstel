import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/app.dart';
import 'shared/theme/theme_controller.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 ОБЯЗАТЕЛЬНО
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final themeController = ThemeController();
  runApp(App(themeController: themeController));
}
