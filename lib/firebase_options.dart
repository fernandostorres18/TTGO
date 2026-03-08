// lib/firebase_options.dart
// Configuração Firebase para plataforma Web (ttg0-95043)

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCPgc8ctDFXQGJ25nFvIQ0T7KLrbWEstx4',
    authDomain: 'ttg0-95043.firebaseapp.com',
    projectId: 'ttg0-95043',
    storageBucket: 'ttg0-95043.firebasestorage.app',
    messagingSenderId: '625172230847',
    appId: '1:625172230847:web:13d93a8b5a9272bcf04c0a',
    measurementId: 'G-4N7BKVXTHT',
  );

  // Android: usa mesma config (sem google-services.json por ora)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCPgc8ctDFXQGJ25nFvIQ0T7KLrbWEstx4',
    appId: '1:625172230847:web:13d93a8b5a9272bcf04c0a',
    messagingSenderId: '625172230847',
    projectId: 'ttg0-95043',
    storageBucket: 'ttg0-95043.firebasestorage.app',
  );
}
