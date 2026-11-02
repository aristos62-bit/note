// lib/shared/widgets/notification_hint.dart
//
// E08 (S284): SPoT για τις μόνιμες γραμμές-hint ειδοποιήσεων.
//
//  • NotificationHintRow       — dumb row (icon + κείμενο). Αντικαθιστά τα
//    3 inline αντίγραφα του S202 hint (settings / sheet / διάγνωση).
//  • NotificationPermissionHint — state-aware (άδεια OS + in-app flag).
//
// Fail-open: granted/unknown → SizedBox.shrink (καμία νέα γραμμή).
//
import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../services/notification_permission.dart';

/// Γραμμή-hint: icon + κείμενο σε μία σειρά, με [compact] για πυκνά σημεία
/// (icon 16 αντί 20, όπως το υπάρχον hint του sheet).
class NotificationHintRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  final bool compact;

  const NotificationHintRow({
    super.key,
    required this.icon,
    required this.text,
    this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.cText2;
    return Row(
      children: [
        Icon(icon, size: compact ? 16 : 20, color: c),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Text(text, style: context.bodySm.withColor(c)),
        ),
      ],
    );
  }
}

/// Μόνιμη ειδοποίηση κατάστασης: δείχνει γραμμή ΜΟΝΟ όταν κάτι εμποδίζει
/// την εμφάνιση (in-app OFF ή OS denied). Προτεραιότητα στο in-app, γιατί
/// διορθώνεται με 1 tap στο διπλανό switch.
class NotificationPermissionHint extends StatelessWidget {
  final NotificationPermissionState osState;

  /// `null` = άγνωστο/φορτώνει (δεν συμπεραίνουμε OFF).
  final bool? inAppEnabled;
  final bool compact;

  const NotificationPermissionHint({
    super.key,
    required this.osState,
    this.inAppEnabled,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final String? message;
    if (inAppEnabled == false) {
      message = compact
          ? AppErrors.notifDisabledInAppShort
          : AppErrors.notifDisabledInApp;
    } else if (osState == NotificationPermissionState.denied) {
      message = compact
          ? AppErrors.notifBlockedBySystemShort
          : AppErrors.notifBlockedBySystem;
    } else {
      message = null;
    }
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: compact ? Spacing.xs : Spacing.sm),
      child: NotificationHintRow(
        icon: Icons.notifications_off_rounded,
        text: message,
        color: context.cWarning,
        compact: compact,
      ),
    );
  }
}
