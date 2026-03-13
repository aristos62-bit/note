// lib/shared/widgets/confirm_dialog.dart
//
// ConfirmDialog — dialog επιβεβαίωσης για destructive actions.
// ✅ Responsive: bottom sheet σε mobile, dialog σε tablet/desktop
// ✅ Dark mode: χρησιμοποιεί ColorsUI
// ✅ DebugConfig: log στο confirm/cancel
//
// ΧΡΗΣΗ:
//   // Διαγραφή (κόκκινο)
//   final confirmed = await ConfirmDialog.delete(
//     context,
//     title: 'Διαγραφή σημείωσης',
//     subtitle: 'Η ενέργεια δεν μπορεί να αναιρεθεί.',
//   );
//   if (confirmed) notifier.deleteItem(item.id);
//
//   // Γενικό (μπλε)
//   final confirmed = await ConfirmDialog.show(
//     context,
//     title: 'Αρχειοθέτηση;',
//     subtitle: 'Το item θα μετακινηθεί στο αρχείο.',
//     confirmLabel: 'Αρχειοθέτηση',
//     icon: Icons.archive_rounded,
//   );
//
import 'package:flutter/material.dart';
import '../../core/core.dart';

class ConfirmDialog {

  // ── Delete ────────────────────────────────────────────────────
  static Future<bool> delete(
      BuildContext context, {
        required String title,
        String? subtitle,
        String confirmLabel = 'Διαγραφή',
      }) {
    return show(
      context,
      title:        title,
      subtitle:     subtitle ?? 'Η ενέργεια δεν μπορεί να αναιρεθεί.',
      confirmLabel: confirmLabel,
      icon:         Icons.delete_outline_rounded,
      isDestructive: true,
    );
  }

  // ── Archive ───────────────────────────────────────────────────
  static Future<bool> archive(
      BuildContext context, {
        String title = 'Αρχειοθέτηση;',
        String? subtitle,
      }) {
    return show(
      context,
      title:        title,
      subtitle:     subtitle ?? 'Θα μπορείς να το βρεις στο αρχείο.',
      confirmLabel: 'Αρχειοθέτηση',
      icon:         Icons.archive_rounded,
    );
  }

  // ── Discard changes ───────────────────────────────────────────
  static Future<bool> discardChanges(BuildContext context) {
    return show(
      context,
      title:        'Απόρριψη αλλαγών;',
      subtitle:     'Οι αλλαγές που δεν αποθηκεύτηκαν θα χαθούν.',
      confirmLabel: 'Απόρριψη',
      cancelLabel:  'Συνέχεια επεξεργασίας',
      icon:         Icons.edit_off_rounded,
      isDestructive: true,
    );
  }

  // ── Generic show ─────────────────────────────────────────────
  static Future<bool> show(
      BuildContext context, {
        required String title,
        String? subtitle,
        String confirmLabel = 'Επιβεβαίωση',
        String cancelLabel  = 'Άκυρο',
        IconData icon       = Icons.help_outline_rounded,
        bool isDestructive  = false,
      }) async {
    DebugConfig.print('ConfirmDialog.show: "$title"');

    // Δημιουργία Future synchronously (context χρησιμοποιείται εδώ, πριν οποιοδήποτε await)
    final future = context.isMobile
        ? _showBottomSheet(
      context,
      title:         title,
      subtitle:      subtitle,
      confirmLabel:  confirmLabel,
      cancelLabel:   cancelLabel,
      icon:          icon,
      isDestructive: isDestructive,
    )
        : _showDialog(
      context,
      title:         title,
      subtitle:      subtitle,
      confirmLabel:  confirmLabel,
      cancelLabel:   cancelLabel,
      icon:          icon,
      isDestructive: isDestructive,
    );

    // Await ξεχωριστά — context δεν αγγίζεται μετά εδώ
    final result = await future;
    DebugConfig.print('ConfirmDialog result: $result for "$title"');
    return result ?? false;
  }

  // ─────────────────────────────────────────────────────────────
  // BOTTOM SHEET (mobile)
  // ─────────────────────────────────────────────────────────────

  static Future<bool?> _showBottomSheet(
      BuildContext context, {
        required String title,
        String? subtitle,
        required String confirmLabel,
        required String cancelLabel,
        required IconData icon,
        required bool isDestructive,
      }) {
    return showModalBottomSheet<bool>(
      context:       context,
      isScrollControlled: true,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft:  Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) => _ConfirmContent(
        title:         title,
        subtitle:      subtitle,
        confirmLabel:  confirmLabel,
        cancelLabel:   cancelLabel,
        icon:          icon,
        isDestructive: isDestructive,
        isSheet:       true,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DIALOG (tablet/desktop)
  // ─────────────────────────────────────────────────────────────

  static Future<bool?> _showDialog(
      BuildContext context, {
        required String title,
        String? subtitle,
        required String confirmLabel,
        required String cancelLabel,
        required IconData icon,
        required bool isDestructive,
      }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.dialogBR,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: _ConfirmContent(
            title:         title,
            subtitle:      subtitle,
            confirmLabel:  confirmLabel,
            cancelLabel:   cancelLabel,
            icon:          icon,
            isDestructive: isDestructive,
            isSheet:       false,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CONFIRM CONTENT — κοινό περιεχόμενο για sheet + dialog
// ════════════════════════════════════════════════════════════════

class _ConfirmContent extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;
  final bool isDestructive;
  final bool isSheet;

  const _ConfirmContent({
    required this.title,
    this.subtitle,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.icon,
    required this.isDestructive,
    required this.isSheet,
  });

  @override
  Widget build(BuildContext context) {
    final confirmColor = isDestructive ? context.cError : context.cPrimary;

    // Responsive padding: μεγαλύτερο σε tablet/desktop dialog
    final contentPadding = EdgeInsets.all(
      context.responsive(mobile: Spacing.lg, tablet: Spacing.xl, desktop: Spacing.xl),
    );

    // Responsive icon size
    final iconContainerSize = context.responsive<double>(mobile: 64, tablet: 72, desktop: 80);
    final iconSize          = context.responsive<double>(mobile: 30, tablet: 34, desktop: 38);

    return Padding(
      padding: contentPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar (μόνο σε sheet)
          if (isSheet) ...[
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: context.cBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: Spacing.lg),
          ],

          // Icon
          Container(
            width: iconContainerSize, height: iconContainerSize,
            decoration: BoxDecoration(
              color: confirmColor.withValues(alpha:0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: iconSize, color: confirmColor),
          ),
          const SizedBox(height: Spacing.md),

          // Title
          Text(title, style: context.titleLg, textAlign: TextAlign.center),

          // Subtitle
          if (subtitle != null) ...[
            const SizedBox(height: Spacing.sm),
            Text(
              subtitle!,
              style: context.bodyMd.withColor(context.cText2),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: Spacing.xl),

          // Buttons
          Row(
            children: [
              // Cancel
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    DebugConfig.print('ConfirmDialog: cancel "$cancelLabel"');
                    Navigator.of(context).pop(false);
                  },
                  child: Text(cancelLabel),
                ),
              ),
              const SizedBox(width: Spacing.md),
              // Confirm
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    DebugConfig.print('ConfirmDialog: confirm "$confirmLabel"');
                    Navigator.of(context).pop(true);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: confirmColor,
                    foregroundColor: ColorsUI.getAccessibleTextColor(confirmColor),
                  ),
                  child: Text(confirmLabel),
                ),
              ),
            ],
          ),

          // Bottom safe area (μόνο σε sheet)
          if (isSheet)
            SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}