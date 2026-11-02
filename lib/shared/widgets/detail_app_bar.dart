// lib/shared/widgets/detail_app_bar.dart
//
// E11: Ενοποιημένη AppBar για όλα τα detail screens.
// • Ίδια σειρά ενεργειών παντού: save → reminder → favorite → pin → archive → delete.
// • null callback = η ενέργεια κρύβεται (π.χ. habit χωρίς reminder, collection χωρίς pin).
// • Compact density + icon 20 + titleSpacing 0 + actionsPadding 0:
//   χωράει 6 ενέργειες ακόμα και στα 320dp (πριν: επικάλυψη με back / overflow).
// • Saving slot (spinner + «Αποθήκευση...») μόνο όπου υπάρχει πραγματικό isSaving.
// • Καμία εξάρτηση από providers: μόνο callbacks (η λογική μένει στις οθόνες).
//
import 'package:flutter/material.dart';
import '../../core/core.dart';

/// Σταθερό μέγεθος εικονιδίων ενεργειών (συμβατό με τα υπάρχοντα detail screens).
const double _kActionIconSize = 20;

/// Κοινή AppBar των detail screens (note/task/habit/event/journal/contact/
/// appointment/collection/entry).
///
/// Όλα τα callbacks είναι nullable· όταν είναι `null` το αντίστοιχο κουμπί δεν
/// εμφανίζεται. Το save απενεργοποιείται αυτόματα όσο [isSaving] είναι `true`.
class DetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DetailAppBar({
    super.key,
    this.isSaving = false,
    this.isPinned = false,
    this.isFavorite = false,
    this.isArchived = false,
    this.onSave,
    this.onReminder,
    this.onFavorite,
    this.onPin,
    this.onArchive,
    this.onDelete,
  });

  /// Αποθήκευση σε εξέλιξη (autosave τίτλου ή χειροκίνητο save).
  final bool isSaving;

  final bool isPinned;
  final bool isFavorite;
  final bool isArchived;

  final VoidCallback? onSave;
  final VoidCallback? onReminder;
  final VoidCallback? onFavorite;
  final VoidCallback? onPin;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  @override
  Size get preferredSize => const Size.fromHeight(Spacing.appBarHeight);

  @override
  Widget build(BuildContext context) {
    final List<Widget> actions = <Widget>[
      if (onSave != null)
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(
            Icons.save_rounded,
            color: context.cPrimary,
            size: _kActionIconSize,
          ),
          tooltip: 'Αποθήκευση',
          onPressed: isSaving ? null : onSave,
        ),
      if (onReminder != null)
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(
            Icons.notifications_none_rounded,
            color: context.cText2,
            size: _kActionIconSize,
          ),
          tooltip: 'Υπενθύμιση',
          onPressed: onReminder,
        ),
      if (onFavorite != null)
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(
            isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
            color: isFavorite
                ? ColorsUI.getWarning(context.brightness)
                : context.cText2,
            size: _kActionIconSize,
          ),
          tooltip: isFavorite ? 'Αφαίρεση αγαπημένου' : 'Αγαπημένο',
          onPressed: onFavorite,
        ),
      if (onPin != null)
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(
            isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            color: isPinned ? context.cPrimary : context.cText2,
            size: _kActionIconSize,
          ),
          tooltip: isPinned ? 'Αποκαρφίτσωμα' : 'Καρφίτσωμα',
          onPressed: onPin,
        ),
      if (onArchive != null)
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(
            isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
            color: context.cText2,
            size: _kActionIconSize,
          ),
          tooltip: isArchived ? 'Επαναφορά' : 'Αρχειοθέτηση',
          onPressed: onArchive,
        ),
      if (onDelete != null)
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(
            Icons.delete_outline_rounded,
            color: context.cError,
            size: _kActionIconSize,
          ),
          tooltip: 'Διαγραφή',
          onPressed: onDelete,
        ),
    ];

    return AppBar(
      backgroundColor: context.cBg,
      elevation: 0,
      scrolledUnderElevation: 1,
      toolbarHeight: Spacing.appBarHeight,
      titleSpacing: 0,
      actionsPadding: EdgeInsets.zero,
      title: isSaving
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: AppIconSize.xs,
                  height: AppIconSize.xs,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.cText2,
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                Flexible(
                  child: Text(
                    'Αποθήκευση...',
                    style: context.bodySm.withColor(context.cText2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ],
            )
          : null,
      actions: actions,
    );
  }
}
