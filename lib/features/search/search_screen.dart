// lib/features/search/search_screen.dart
//
// Global search με debounce 300ms, type filter chips, match highlight.
// ✅ Responsive: list mobile / 2-col grid tablet+desktop
// ✅ Dark mode: ColorsUI + context extensions
// ✅ DebugConfig: search, nav logs
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/search_service.dart';
import '../../shared/widgets/widgets.dart';
import '../notes/note_detail_screen.dart';
import '../tasks/task_detail_screen.dart';
import '../../features/collections/collection_entries_screen.dart';
import '../../features/collections/collections_screen.dart' show FieldDef;

// ── Local state ───────────────────────────────────────────────────

class _SearchState {
  final String query;
  final ItemType? typeFilter;
  final List<SearchResult> results;
  final bool isLoading;
  final bool hasSearched;

  const _SearchState({
    this.query       = '',
    this.typeFilter,
    this.results     = const [],
    this.isLoading   = false,
    this.hasSearched = false,
  });

  _SearchState copyWith({
    String? query,
    ItemType? typeFilter,
    bool clearTypeFilter = false,
    List<SearchResult>? results,
    bool? isLoading,
    bool? hasSearched,
  }) {
    return _SearchState(
      query:       query       ?? this.query,
      typeFilter:  clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      results:     results     ?? this.results,
      isLoading:   isLoading   ?? this.isLoading,
      hasSearched: hasSearched ?? this.hasSearched,
    );
  }
}

class _SearchNotifier extends Notifier<_SearchState> {
  @override
  _SearchState build() => const _SearchState();

  Future<void> search(String query, int workspaceId) async {
    DebugConfig.search('🔍 _SearchNotifier.search started: query="$query", workspaceId=$workspaceId, state.typeFilter=${state.typeFilter}');
    final q = query.trim();
    state = state.copyWith(query: q, isLoading: true, hasSearched: true);

    if (q.isEmpty) {
      DebugConfig.search('🔍 query empty, clearing results');
      state = state.copyWith(results: [], isLoading: false);
      return;
    }

    DebugConfig.search('🔍 SearchNotifier: "$q" type=${state.typeFilter?.name}');

    try {
      final results = await SearchService.instance.search(
        query:       q,
        workspaceId: workspaceId,
        filterType:  state.typeFilter,
      );
      DebugConfig.search('🔍 SearchNotifier got ${results.length} results');
      state = state.copyWith(results: results, isLoading: false);
    } catch (e) {
      DebugConfig.error('🔍 SearchNotifier failed', e);
      state = state.copyWith(results: [], isLoading: false);
    }
  }

  void setTypeFilter(ItemType? type, int workspaceId) {
    final sameFilter = state.typeFilter == type;
    state = state.copyWith(
      clearTypeFilter: sameFilter,
      typeFilter: sameFilter ? null : type,
    );
    DebugConfig.provider('SearchNotifier filter: ${state.typeFilter?.name}');
    if (state.query.isNotEmpty) search(state.query, workspaceId);
  }

  void clear() {
    state = const _SearchState();
  }
}

final _searchNotifierProvider =
NotifierProvider<_SearchNotifier, _SearchState>(_SearchNotifier.new);

// ════════════════════════════════════════════════════════════════
// SEARCH SCREEN
// ════════════════════════════════════════════════════════════════

class SearchScreen extends ConsumerStatefulWidget {
  /// Αν δοθεί initialQuery, ξεκινάει αμέσως αναζήτηση
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _ctrl;
  final _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialQuery ?? '');
    DebugConfig.nav('SearchScreen init query="${widget.initialQuery}"');

    if (widget.initialQuery?.isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _doSearch());
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
              (_) => _focusNode.requestFocus());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int? get _wsId => ref.read(activeWorkspaceIdProvider);

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _doSearch);
  }

  // Στο _SearchScreenState, μέσα στη μέθοδο _doSearch:

  void _doSearch() {
    DebugConfig.search('🔍 _doSearch called, text="${_ctrl.text}"');
    final wsId = _wsId;
    DebugConfig.search('🔍 _doSearch wsId=$wsId');
    if (wsId == null) {
      DebugConfig.error('🔍 _doSearch wsId is null, cannot search', null);
      return;
    }
    ref.read(_searchNotifierProvider.notifier).search(_ctrl.text, wsId);
  }

  void _clearSearch() {
    _ctrl.clear();
    ref.read(_searchNotifierProvider.notifier).clear();
    _focusNode.requestFocus();
  }

  void _openResult(BuildContext context, SearchResult result) {
    DebugConfig.nav('Search → ${result.item.type.name} id=${result.item.id}');
    switch (result.item.type) {
      case ItemType.task:
      case ItemType.checklist:
        Navigator.push(
            context,
            AppTransitions.slideRoute(TaskDetailScreen(itemId: result.item.id)));
      case ItemType.knowledge:
        _openKnowledgeEntry(context, result.item);
      default:
        Navigator.push(
            context,
            AppTransitions.slideRoute(NoteDetailScreen(itemId: result.item.id)));
    }
  }

  Future<void> _openKnowledgeEntry(BuildContext context, Item entry) async {
    // 1) Βρίσκουμε τη συλλογή στην οποία ανήκει η εγγραφή μέσω property 'collection_id'
    final props = await ref.read(itemPropertiesProvider(entry.id).future);
    final collectionIdStr = props.where((p) => p.key == 'collection_id').firstOrNull?.value;
    if (collectionIdStr == null) {
      DebugConfig.error('Knowledge entry without collection_id', null);
      return;
    }
    final collectionId = int.tryParse(collectionIdStr);
    if (collectionId == null) return;

    // 2) Βρίσκουμε το item της συλλογής
    final collection = await ref.read(itemStreamProvider(collectionId).future);
    if (collection == null) return;

    // 3) Φόρτωση schema της συλλογής από τα properties της
    final collectionProps = await ref.read(itemPropertiesProvider(collectionId).future);
    final schemaJson = collectionProps.where((p) => p.key == 'schema').firstOrNull?.value ?? '';
    final fields = FieldDef.listFromJson(schemaJson);

    if (mounted) {
      Navigator.of(context).push(
        AppTransitions.slideRoute(
          CollectionEntryDetailScreen(
            entryId: entry.id,
            collectionId: collectionId,
            fields: fields,
            isNew: false,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('SearchScreen build');
    final state = ref.watch(_searchNotifierProvider);
    final wsId  = _wsId;

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: _buildAppBar(context, state, wsId),
      body: Column(
        children: [
          // ── Type filter chips ─────────────────────────────────
          _TypeFilterRow(
            selected: state.typeFilter,
            onTap: (type) => ref
                .read(_searchNotifierProvider.notifier)
                .setTypeFilter(type, wsId ?? 0),
          ),

          // ── Results ───────────────────────────────────────────
          Expanded(
            child: _buildBody(context, state),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, _SearchState state, int? wsId) {
    return AppBar(
      backgroundColor:        context.cBg,
      elevation:              0,
      scrolledUnderElevation: 1,
      titleSpacing: 0,
      title: Padding(
        padding: EdgeInsets.only(right: context.responsiveHPadding),
        child: TextField(
          controller:  _ctrl,
          focusNode:   _focusNode,
          onChanged:   _onQueryChanged,
          style:       context.bodyMd,
          textInputAction: TextInputAction.search,
          onSubmitted:  (_) => _doSearch(),
          decoration: InputDecoration(
            hintText:  'Αναζήτηση...',
            hintStyle: context.bodyMd.withColor(context.cDisabled),
            filled:    true,
            fillColor: ColorsUI.getSurface(context.brightness),
            border: OutlineInputBorder(
              borderRadius: AppRadius.inputBR,
              borderSide:   BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Spacing.md, vertical: Spacing.sm,
            ),
            prefixIcon: Icon(Icons.search_rounded,
                color: context.cText2, size: 20),
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.close_rounded,
                  color: context.cText2, size: 20),
              onPressed: _clearSearch,
            )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, _SearchState state) {
    // Αρχική κατάσταση — δεν έχει γίνει ακόμα αναζήτηση
    if (!state.hasSearched) {
      return _SearchSuggestions();
    }

    // Loading
    if (state.isLoading) {
      return ListView.separated(
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHPadding,
          vertical:   Spacing.sm,
        ),
        itemCount:        5,
        separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
        itemBuilder:      (_, __) => const ItemCardSkeleton(),
      );
    }

    // Empty results
    if (state.results.isEmpty && state.query.isNotEmpty) {
      return EmptyState.search(query: state.query);
    }

    // Results
    return ResponsiveLayout(
      mobile:  _ResultsList(
        results:  state.results,
        query:    state.query,
        onTap:    (r) => _openResult(context, r),
      ),
      tablet: _ResultsGrid(
        results:  state.results,
        query:    state.query,
        onTap:    (r) => _openResult(context, r),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TYPE FILTER ROW
// ════════════════════════════════════════════════════════════════

class _TypeFilterRow extends StatelessWidget {
  final ItemType? selected;
  final ValueChanged<ItemType> onTap;

  const _TypeFilterRow({required this.selected, required this.onTap});

  static const _types = [
    ItemType.note,
    ItemType.task,
    ItemType.habit,
    ItemType.knowledge,
    ItemType.event,
    ItemType.contact,
    ItemType.journal,
    ItemType.appointment
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: context.cBg,
      child: ListView.separated(
        scrollDirection:  Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: context.responsiveHPadding,
          vertical:   Spacing.xs,
        ),
        itemCount:        _types.length,
        separatorBuilder: (_, __) => const SizedBox(width: Spacing.xs),
        itemBuilder: (_, i) {
          final type     = _types[i];
          final isActive = selected == type;
          final color    = ColorsUI.itemTypeColor(type, context.brightness);

          return GestureDetector(
            onTap: () => onTap(type),
            child: AnimatedContainer(
              duration: AppDuration.fast,
              padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm + 2, vertical: Spacing.xs),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withValues(alpha: 0.12)
                    : ColorsUI.getSurface(context.brightness),
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(
                  color: isActive
                      ? color.withValues(alpha: 0.5)
                      : ColorsUI.getBorder(context.brightness),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ItemTypeIcon(type,
                      size: 13,
                      color: isActive ? color : context.cText2),
                  const SizedBox(width: 4),
                  Text(
                    ItemTypeIcon.labelFor(type),
                    style: context.labelSm.withColor(
                        isActive ? color : context.cText2),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SEARCH SUGGESTIONS — αρχική κατάσταση
// ════════════════════════════════════════════════════════════════

class _SearchSuggestions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: context.responsivePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded,
                size: context.responsive(mobile: 64.0, tablet: 80.0),
                color: context.cDisabled),
            const SizedBox(height: Spacing.md),
            Text('Αναζήτηση σε όλα', style: context.titleMd),
            const SizedBox(height: Spacing.sm),
            Text(
              'Σημειώσεις, εργασίες, επαφές,\nσελιδοδείκτες και άλλα',
              style: context.bodyMd.withColor(context.cText2),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// RESULTS LIST — mobile (plain list)
// ════════════════════════════════════════════════════════════════

class _ResultsList extends StatelessWidget {
  final List<SearchResult> results;
  final String query;
  final ValueChanged<SearchResult> onTap;

  const _ResultsList({
    required this.results,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical:   Spacing.sm,
      ),
      itemCount:        results.length,
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.sm),
      itemBuilder: (_, i) => _SearchResultCard(
        result: results[i],
        query:  query,
        onTap:  () => onTap(results[i]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// RESULTS GRID — tablet/desktop (2-3 col)
// ════════════════════════════════════════════════════════════════

class _ResultsGrid extends StatelessWidget {
  final List<SearchResult> results;
  final String query;
  final ValueChanged<SearchResult> onTap;

  const _ResultsGrid({
    required this.results,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cols = context.gridColumns;

    return GridView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: context.responsiveHPadding,
        vertical:   Spacing.sm,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   cols,
        mainAxisSpacing:  Spacing.sm,
        crossAxisSpacing: Spacing.sm,
        mainAxisExtent:   110,
      ),
      itemCount: results.length,
      itemBuilder: (_, i) => _SearchResultCard(
        result: results[i],
        query:  query,
        onTap:  () => onTap(results[i]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SEARCH RESULT CARD
// ════════════════════════════════════════════════════════════════

class _SearchResultCard extends StatelessWidget {
  final SearchResult result;
  final String query;
  final VoidCallback onTap;

  const _SearchResultCard({
    required this.result,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final item  = result.item;
    final color = ColorsUI.itemTypeColor(item.type, context.brightness);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Spacing.sm),
        decoration: BoxDecoration(
          color:        ColorsUI.getCard(context.brightness),
          borderRadius: AppRadius.cardBR,
          border: Border.all(
            color: ColorsUI.getBorder(context.brightness),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: type + match badge ──────────────────────
            Row(
              children: [
                ItemTypeIcon(item.type, size: 13, color: color),
                const SizedBox(width: Spacing.xs),
                Text(ItemTypeIcon.labelFor(item.type),
                    style: context.labelSm.withColor(color)),
                const Spacer(),
                _MatchBadge(matchType: result.matchType),
              ],
            ),

            const SizedBox(height: Spacing.xs),

            // ── Title with highlight ────────────────────────────
            _HighlightedText(
              text:    item.title ?? 'Χωρίς τίτλο',
              query:   query,
              style:   context.bodyMd,
              maxLines: 1,
            ),

            // ── Match snippet ───────────────────────────────────
            if (result.matchedText != null &&
                result.matchType != SearchMatchType.title) ...[
              const SizedBox(height: Spacing.xs / 2),
              _HighlightedText(
                text:    result.matchedText!,
                query:   query,
                style:   context.bodySm.withColor(context.cText2),
                maxLines: 2,
              ),
            ],

            const Spacer(),

            // ── Updated at ──────────────────────────────────────
            if (item.updatedAt != null)
              Text(item.updatedAt!.relative,
                  style: context.labelSm.withColor(context.cDisabled)),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MATCH BADGE — δείχνει πού βρέθηκε το αποτέλεσμα
// ════════════════════════════════════════════════════════════════

class _MatchBadge extends StatelessWidget {
  final SearchMatchType matchType;
  const _MatchBadge({required this.matchType});

  @override
  Widget build(BuildContext context) {
    final label = switch (matchType) {
      SearchMatchType.title    => 'Τίτλος',
      SearchMatchType.content  => 'Περιεχόμενο',
      SearchMatchType.property => 'Στοιχείο',
      SearchMatchType.tag      => 'Tag',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:        context.cSurface,
        borderRadius: BorderRadius.circular(AppRadius.badge),
        border: Border.all(color: context.cBorder),
      ),
      child: Text(label,
          style: context.labelSm.withColor(context.cText2)),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// HIGHLIGHTED TEXT — bold highlight στο matched query
// ════════════════════════════════════════════════════════════════

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final int maxLines;

  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, style: style,
          maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }

    final spans = _buildSpans(context);

    return Text.rich(
      TextSpan(children: spans),
      maxLines:  maxLines,
      overflow:  TextOverflow.ellipsis,
    );
  }

  List<TextSpan> _buildSpans(BuildContext context) {
    final lowerText  = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans      = <TextSpan>[];
    int   start      = 0;

    while (true) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start), style: style));
        break;
      }
      // Text before match
      if (idx > start) {
        spans.add(TextSpan(
            text: text.substring(start, idx), style: style));
      }
      // Highlighted match
      spans.add(TextSpan(
        text:  text.substring(idx, idx + query.length),
        style: style.copyWith(
          fontWeight:      FontWeight.w700,
          color:           context.cPrimary,
          backgroundColor: context.cPrimary.withValues(alpha: 0.12),
        ),
      ));
      start = idx + query.length;
    }

    return spans;
  }
}