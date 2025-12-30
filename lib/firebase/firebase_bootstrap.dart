import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

class FirebaseBootstrap {
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1) Firebase Core
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // 2) Firestore offline persistence
    // Must be set early (before any Firestore usage).
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );

    // 3) App Check
    // Requirement: enable Debug provider on Android; do not enforce yet.
    // Avoid crashing on unsupported platforms.
    if (!kIsWeb && Platform.isAndroid) {
      try {
        if (kDebugMode) {
          debugPrint('[AppCheck] Android provider = debug');
        }
        await FirebaseAppCheck.instance.activate(
          // Provide both the new provider classes and the legacy enum in debug
          // builds to maximize compatibility across plugin/native versions.
          // ignore: deprecated_member_use
          androidProvider: kDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
          providerAndroid: kDebugMode
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
        );
      } catch (e) {
        debugPrint('FirebaseAppCheck.activate failed: $e');
      }
    }
  }
}
