package com.trivvo.ovum

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth monta su BiometricPrompt (androidx.biometric) sobre un
// FragmentActivity. Con FlutterActivity el plugin responde `uiUnavailable` y el
// diálogo de huella nunca llega a mostrarse.
class MainActivity : FlutterFragmentActivity()
