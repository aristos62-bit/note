// lib/providers/pinned_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'db_provider.dart';
import 'workspace_provider.dart';

// ─────────────────────────────────────────────────────────────────
// ΑΝΕΞΑΡΤΗΤΑ STREAMS ΓΙΑ PINNED / FAVORITES (ΥΨΗΛΗ ΑΠΟΔΟΣΗ)
// 🔹 Δεν εξαρτώνται από το itemsStreamProvider
// 🔹 Κάνουν yield μόνο όταν αλλάζουν τα σχετικά δεδομένα
// ─────────────────────────────────────────────────────────────────

/// Stream όλων των pinned items του active workspace — ανεξάρτητο
final pinnedItemsStreamProvider = StreamProvider<List<Item>>((ref) {
  final db   = ref.watch(dbProvider);
  final wsId = ref.watch(activeWorkspaceIdProvider);
  if (wsId == null) return Stream.value(const []);
  return db.items.watchPinnedByWorkspace(wsId);
});

/// Stream όλων των favorite items του active workspace — ανεξάρτητο
/// Stream pinned + favorites — ανεξάρτητα Isar queries.
/// ΔΕΝ εξαρτάται από itemsStreamProvider.
/// Φωτίζει ΜΟΝΟ όταν αλλάξει pinned ή favorite status.
final pinnedAndFavoritesProvider =
StreamProvider<({List<Item> pinned, List<Item> favorites})>((ref) {
  final db   = ref.watch(dbProvider);
  final wsId = ref.watch(activeWorkspaceIdProvider);

  if (wsId == null) {
    return Stream.value((pinned: <Item>[], favorites: <Item>[]));
  }

  // ignore: close_sinks — κλείνει στο onDispose
  final controller =
  StreamController<({List<Item> pinned, List<Item> favorites})>();

  List<Item> currentPinned    = [];
  List<Item> currentFavorites = [];
  bool pinnedLoaded    = false;
  bool favoritesLoaded = false;

  void emit() {
    if (pinnedLoaded && favoritesLoaded && !controller.isClosed) {
      controller.add((pinned: currentPinned, favorites: currentFavorites));
    }
  }

  final pinnedSub = db.items.watchPinnedByWorkspace(wsId).listen((items) {
    currentPinned = items;
    pinnedLoaded  = true;
    emit();
  });

  final favoritesSub =
  db.items.watchFavoritesByWorkspace(wsId).listen((items) {
    currentFavorites = items;
    favoritesLoaded  = true;
    emit();
  });

  ref.onDispose(() {
    pinnedSub.cancel();
    favoritesSub.cancel();
    controller.close();
  });

  return controller.stream;
});
