// lib/features/notes/note_list_screen.dart
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../shared/widgets/widgets.dart';
import 'note_detail_screen.dart';

class NoteListScreen extends StatelessWidget {
  const NoteListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ItemListScreen(
      itemType: ItemType.note,
      title: 'Σημειώσεις',
      detailScreenBuilder: (context, item, {bool isNew = false}) {
        return NoteDetailScreen(itemId: item.id, isNew: isNew);
      },
    );
  }
}