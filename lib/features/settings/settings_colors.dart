// lib/features/settings/settings_colors.dart
//
// S253 (P2): χρώματα καρτών ανά τύπο + color picker (split από settings_screen.dart).
//
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';
import '../../helpers/item_color_helper.dart';

class SettingsItemTypeColorsTile extends ConsumerWidget {
  final String? colorsJson;
  final WidgetRef ref;
  const SettingsItemTypeColorsTile({super.key, required this.colorsJson, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef r) {
    final map = itemTypeColorsMap(colorsJson);
    const visibleTypes = {
      ItemType.note,
      ItemType.task,
      ItemType.event,
      ItemType.contact,
      ItemType.habit,
      ItemType.journal,
      ItemType.appointment,
    };
    final types = ItemType.values.where(visibleTypes.contains).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Χρώματα καρτών', style: context.bodyMd),
          const SizedBox(height: 4),
          Text(
            'Ορίστε χρώμα φόντου ανά τύπο στοιχείου',
            style: context.bodySm.withColor(context.cText2),
          ),
          const SizedBox(height: Spacing.sm),
          ...types.map((type) {
            final hex = map[type.name];
            final color = ItemColorHelper.parseHex(hex);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(ItemTypeIcon.iconDataFor(type), size: 18, color: context.cText2),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      ItemTypeIcon.labelFor(type),
                      style: context.bodyMd,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showColorPicker(context, type, hex),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color ?? _defaultBg(type, context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: context.cBorder,
                          width: color == null ? 2 : 0,
                        ),
                      ),
                      child: color == null
                          ? Icon(Icons.close_rounded, size: 14, color: context.cText2)
                          : null,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, ItemType type, String? currentHex) {
    showSafeSheet<void>(
      context,
      builder: (sheetCtx) => SettingsColorPickerSheet(
        type: type,
        currentHex: currentHex,
        onSelected: (hex) {
          Navigator.pop(sheetCtx);
          ref.read(settingsNotifierProvider.notifier).setItemTypeColor(type, hex);
        },
      ),
    );
  }

  Color _defaultBg(ItemType type, BuildContext context) {
    return ItemColorHelper.backgroundColorForType(type, context);
  }
}

class SettingsColorPickerSheet extends StatefulWidget {
  final ItemType type;
  final String? currentHex;
  final ValueChanged<String?> onSelected;

  const SettingsColorPickerSheet({
    super.key,
    required this.type,
    required this.currentHex,
    required this.onSelected,
  });

  @override
  State<SettingsColorPickerSheet> createState() => SettingsColorPickerSheetState();
}

class SettingsColorPickerSheetState extends State<SettingsColorPickerSheet> {
  MaterialColor? _selectedFamily;

  static const _colorFamilies = <MaterialColor>[
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.blueGrey,
    Colors.grey,
  ];

  String _colorToHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  List<Color> _shadesOf(MaterialColor family) => [
    family.shade50,
    family.shade100,
    family.shade200,
    family.shade300,
    family.shade400,
    family.shade500,
    family.shade600,
    family.shade700,
    family.shade800,
    family.shade900,
  ];

  String _familyLabel(MaterialColor family) {
    if (family == Colors.red) return 'Κόκκινο';
    if (family == Colors.pink) return 'Ροζ';
    if (family == Colors.purple) return 'Μωβ';
    if (family == Colors.deepPurple) return 'Βαθύ μωβ';
    if (family == Colors.indigo) return 'Λουλακί';
    if (family == Colors.blue) return 'Μπλε';
    if (family == Colors.lightBlue) return 'Γαλάζιο';
    if (family == Colors.cyan) return 'Κυανό';
    if (family == Colors.teal) return 'Τιρκουάζ';
    if (family == Colors.green) return 'Πράσινο';
    if (family == Colors.lightGreen) return 'Ανοιχτό πράσινο';
    if (family == Colors.lime) return 'Λάιμ';
    if (family == Colors.yellow) return 'Κίτρινο';
    if (family == Colors.amber) return 'Κεχριμπάρι';
    if (family == Colors.orange) return 'Πορτοκαλί';
    if (family == Colors.deepOrange) return 'Βαθύ πορτοκαλί';
    if (family == Colors.brown) return 'Καφέ';
    if (family == Colors.blueGrey) return 'Μπλε-γκρι';
    if (family == Colors.grey) return 'Γκρι';
    return '';
  }

  @override
  void initState() {
    super.initState();
    if (widget.currentHex != null) {
      for (final family in _colorFamilies) {
        if (_shadesOf(family).any((s) => _colorToHex(s) == widget.currentHex)) {
          _selectedFamily = family;
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(width: Spacing.md),
              Icon(ItemTypeIcon.iconDataFor(widget.type), size: 18, color: context.cText),
              const SizedBox(width: Spacing.sm),
              Text('Χρώμα — ${ItemTypeIcon.labelFor(widget.type)}', style: context.titleSm),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Divider(height: 1, color: context.cDivider),
          const SizedBox(height: Spacing.sm),
          // Προεπιλογή
          ListTile(
            leading: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.cBorder, width: 2),
              ),
              child: Icon(Icons.close_rounded, size: 14, color: context.cText2),
            ),
            title: Text('Προεπιλογή', style: context.bodyMd),
            trailing: widget.currentHex == null ? Icon(Icons.check, size: 18, color: context.cPrimary) : null,
            onTap: () => widget.onSelected(null),
          ),
          const Divider(height: 1),
          const SizedBox(height: Spacing.sm),
          // Οικογένειες χρωμάτων
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            child: Text('Οικογένεια', style: context.labelSm.withColor(context.cText2)),
          ),
          const SizedBox(height: Spacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: _colorFamilies.length,
              itemBuilder: (_, i) {
                final family = _colorFamilies[i];
                final isSelected = _selectedFamily == family;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFamily = isSelected ? null : family),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: family.shade500,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 2.5)
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : null,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _familyLabel(family),
                        style: context.bodySm.withColor(context.cText2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Αποχρώσεις επιλεγμένης οικογένειας
          if (_selectedFamily != null) ...[
            const SizedBox(height: Spacing.sm),
            const Divider(height: 1),
            const SizedBox(height: Spacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
              child: Text('Αποχρώσεις', style: context.labelSm.withColor(context.cText2)),
            ),
            const SizedBox(height: Spacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: Spacing.md, right: Spacing.md, bottom: Spacing.sm),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemCount: _shadesOf(_selectedFamily!).length,
                itemBuilder: (_, i) {
                  final color = _shadesOf(_selectedFamily!)[i];
                  final hex = _colorToHex(color);
                  final isSelected = hex == widget.currentHex;
                  return GestureDetector(
                    onTap: () => widget.onSelected(hex),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2.5)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Map<String, String?> itemTypeColorsMap(String? json) {
  if (json == null || json.isEmpty) return {};
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return {};
    return decoded.map((k, v) => MapEntry(k.toString(), v?.toString()));
  } catch (_) {
    return {};
  }
}
