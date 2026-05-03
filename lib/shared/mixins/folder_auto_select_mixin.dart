// lib/shared/mixins/folder_auto_select_mixin.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/folder.dart';
import '../../providers/providers.dart';
import '../../core/utils/debug_config.dart';

mixin FolderAutoSelectMixin<T extends ConsumerStatefulWidget>
on ConsumerState<T> {
  int? selectedFolderId;
  bool userExplicitlySelected = false;
  bool autoSelectDone = false;

  /// Κάλεσε αυτό στο build() για αυτόματη επιλογή φακέλου
  void tryAutoSelectFolder({
    required AsyncValue<List<Folder>> foldersAsync,
    required AsyncValue<dynamic> settingsAsync,
    String debugLabel = '',
  }) {
    if (userExplicitlySelected || autoSelectDone) return;
    if (!settingsAsync.hasValue || !foldersAsync.hasValue) return;

    final folders = foldersAsync.value!;
    if (folders.isEmpty || !mounted || selectedFolderId != null) return;

    final settings = ref.read(settingsNotifierProvider).valueOrNull;
    final preferredId = settings?.preferredFolderId;

    int? targetId = preferredId;
    if (targetId == null || !folders.any((f) => f.id == targetId)) {
      targetId = folders.firstWhere(
            (f) => f.isSystem,
        orElse: () => folders.first,
      ).id;
    }

    autoSelectDone = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => selectedFolderId = targetId);
        DebugConfig.nav(
          '$debugLabel: auto-selected folder id=$targetId (preferredId=$preferredId)',
        );
      }
    });
  }

  /// Κάλεσε αυτό όταν ο χρήστης επιλέγει φάκελο χειροκίνητα
  void onUserSelectFolder(int? id) {
    setState(() {
      selectedFolderId = id;
      userExplicitlySelected = true;
    });
  }
}