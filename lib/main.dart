import 'package:flutter/material.dart';

import 'app/app.dart';
import 'firebase/firebase_bootstrap.dart';
import 'package:flutter/foundation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrap = FirebaseBootstrap();
  await bootstrap.init();

  if (kDebugMode) {
    debugPrint(
      'If AppCheck debug token appears in logs, copy it to Firebase Console → '
      'App Check → Apps → KidsTel Android → Manage debug tokens',
    );
  }

  runApp(KidsTelApp(firebaseBootstrap: bootstrap));
}
