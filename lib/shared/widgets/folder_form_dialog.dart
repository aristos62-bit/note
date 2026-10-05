// lib/shared/widgets/folder_form_dialog.dart
//
// SPoT για τις φόρμες φακέλων (create + edit).
// Ενοποιεί 3 byte-σχεδόν-identical dialogs:
//   home_screen._showCreateFolderDialog + _editFolder,
//   folder_browser_screen._editFolder.
// Pixel-identical layout, βελτιωμένη συμπεριφορά:
//   inline σφάλμα + disabled κουμπί σε κενό όνομα (αντί σιωπηλού return),
//   controller dispose (διόρθωση leak), validation με AppStringUtils.clean.
//
// ΧΡΗΣΗ:
//   final result = await FolderFormDialog.show(
//     context, title: 'Νέος Φάκελος', confirmLabel: 'Δημιουργία',
//   );
//   if (result == null) return; // ακύρωση
//   await ref.read(folderNotifierProvider.notifier)
//       .create(result.name, icon: result.icon, color: result.color);
//
import 'package:flutter/material.dart';
import '../../core/core.dart';
import '../../helpers/item_color_helper.dart';

/// Προεπιλεγμένο εικονίδιο/χρώμα (ίδια με system folder "Γενικά").
const kDefaultFolderIcon = '📁';
const kDefaultFolderColor = '#6366F1';

/// Εικονίδια φακέλων (κοινή λίστα, byte-identical με τις 3 παλιές τοπικές).
const kFolderIcons = [
  '📁', '💼', '🏠', '📚', '🎵', '🎮', '⚽', '🌍', '🔬',
  '✈️', '🍕', '🏆', '🖼️', '📝', '⭐', '🎬', '💡', '🛒',
  '🏋️', '🌱', '📊', '🔐', '🎯', '😊', '👤', '👥', '🧠', '🗣️',
  '🛠️', '⚙️', '🔧', '🧰', '📐', '💻', '📱', '📋', '🏷️', '🔔',
  '⏰', '💬', '🚀', '🔑', '🎉', '🎨', '👦', '👧', '👴', '👵', '👨',
  '👩', '👶', '🧑', '👪', '🧠', '🛠️', '⚙️', '🔧', '🧰', '📐',
  '💻', '📱', '🔑', '🚀', '🎉',
];

/// Χρώματα φακέλων (κοινή λίστα, byte-identical με τις παλιές τοπικές).
const kFolderColors = [
  '#6366F1', '#A1A3F7', // Indigo
  '#8B5CF6', '#B99DFA', // Purple
  '#EC4899', '#F491C2', // Pink
  '#EF4444', '#F58F8F', // Red
  '#F97316', '#FBAB73', // Orange
  '#EAB308', '#F2D16B', // Yellow
  '#22C55E', '#7ADC9E', // Green
  '#14B8A6', '#72D4CA', // Teal
  '#06B6D4', '#6AD3E5', // Cyan
  '#3B82F6', '#89B4FA', // Blue
  '#64748B', '#A2ACB9', // Slate
  '#E11D48', '#ED7791', // Rose
];

/// Αποτέλεσμα φόρμας φακέλου (name καθαρισμένο με AppStringUtils.clean).
class FolderFormResult {
  final String name;
  final String icon;
  final String color;

  const FolderFormResult({
    required this.name,
    required this.icon,
    required this.color,
  });
}

class FolderFormDialog extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final String initialName;
  final String initialIcon;
  final String initialColor;

  const FolderFormDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.initialName = '',
    this.initialIcon = kDefaultFolderIcon,
    this.initialColor = kDefaultFolderColor,
  });

  /// Ανοίγει το dialog. Επιστρέφει null σε ακύρωση.
  /// Το pop γίνεται με dialog-context (όχι blind pop caller).
  static Future<FolderFormResult?> show(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    String initialName = '',
    String initialIcon = kDefaultFolderIcon,
    String initialColor = kDefaultFolderColor,
  }) {
    DebugConfig.nav('FolderFormDialog.show "$title"');
    return showDialog<FolderFormResult?>(
      context: context,
      builder: (ctx) => FolderFormDialog(
        title: title,
        confirmLabel: confirmLabel,
        initialName: initialName,
        initialIcon: initialIcon,
        initialColor: initialColor,
      ),
    );
  }

  @override
  State<FolderFormDialog> createState() => _FolderFormDialogState();
}

class _FolderFormDialogState extends State<FolderFormDialog> {
  late final TextEditingController _ctrl;
  late String _icon;
  late String _color;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
    _icon = widget.initialIcon;
    _color = widget.initialColor;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _canSave => AppStringUtils.clean(_ctrl.text).isNotEmpty;

  void _confirm() {
    final name = AppStringUtils.clean(_ctrl.text);
    if (name.isEmpty) {
      DebugConfig.warning('FolderFormDialog: empty name rejected');
      setState(() => _error = 'Το όνομα δεν μπορεί να είναι κενό');
      return;
    }
    Navigator.pop(context, FolderFormResult(name: name, icon: _icon, color: _color));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ColorsUI.getSurface(context.brightness),
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Όνομα φακέλου...',
                errorText: _error,
                filled: true,
                fillColor: ColorsUI.getBackground(context.brightness),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.inputBR,
                  borderSide: BorderSide(color: ColorsUI.getBorder(context.brightness)),
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
            Text('Εικονίδιο', style: context.labelMd.withColor(context.cText2)),
            const SizedBox(height: Spacing.xs),
            Wrap(
              spacing: Spacing.xs,
              runSpacing: Spacing.xs,
              children: kFolderIcons
                  .map((e) => GestureDetector(
                        onTap: () => setState(() => _icon = e),
                        child: AnimatedContainer(
                          duration: AppDuration.fast,
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _icon == e
                                ? context.cPrimary.withValues(alpha: 0.12)
                                : ColorsUI.getSurface(context.brightness),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: _icon == e
                                  ? context.cPrimary
                                  : ColorsUI.getBorder(context.brightness),
                            ),
                          ),
                          child: Center(
                              child: Text(e, style: const TextStyle(fontSize: 20))),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: Spacing.md),
            Text('Χρώμα', style: context.labelMd.withColor(context.cText2)),
            const SizedBox(height: Spacing.xs),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: kFolderColors.map((hex) {
                final c = ItemColorHelper.parseHex(hex) ??
                    const Color(0xFF6366F1);
                final isActive = _color == hex;
                return GestureDetector(
                  onTap: () => setState(() => _color = hex),
                  child: AnimatedContainer(
                    duration: AppDuration.fast,
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive ? context.cText : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: isActive
                        ? const Icon(Icons.check_rounded,
                            size: 16, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Άκυρο'),
        ),
        FilledButton(
          onPressed: _canSave ? _confirm : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
