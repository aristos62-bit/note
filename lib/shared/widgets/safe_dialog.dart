// lib/shared/widgets/safe_dialog.dart
//
// SPoT dialog-body — απόσταγμα ConfirmDialog (S108).
// Με LOOSE dialog constraints τυλίγει όταν χωράει, κυλάει όταν δεν χωράει.
// Κανόνας: dialog με εσωτερική scrollable λίστα → Flexible (S107), ΟΧΙ αυτό.
//
// ΧΡΗΣΗ:
//   AlertDialog(content: SafeDialogBody(child: Column(...)))
//
import 'package:flutter/material.dart';

class SafeDialogBody extends StatelessWidget {
  final Widget child;
  const SafeDialogBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: child,
    );
  }
}
