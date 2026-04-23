// lib/features/contacts/contact_detail_screen.dart
//
// Detail screen επαφής: όνομα, τηλέφωνο, email, εταιρεία, κ.α.
// ✅ Folder‑aware: δείχνει φάκελο
// ✅ Save logic: isNew + manual Save button (ίδια με NoteDetailScreen)
// ✅ Responsive: single col mobile / two‑panel tablet
// ✅ Dark mode: ColorsUI + context extensions
// ✅ DebugConfig: nav, db, provider logs
// ✅ AppBar: Αποθήκευση, Υπενθύμιση, Αγαπημένο, Pin, Αρχειοθέτηση, Διαγραφή
// ✅ Tags: προβολή, προσθήκη, αφαίρεση
//
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';

class ContactDetailScreen extends ConsumerStatefulWidget {
  final int itemId;
  final bool isNew;

  const ContactDetailScreen({
    super.key,
    required this.itemId,
    this.isNew = false,
  });

  @override
  ConsumerState<ContactDetailScreen> createState() =>
      _ContactDetailScreenState();
}

class _ContactDetailScreenState extends ConsumerState<ContactDetailScreen> {
  // ── Controllers ─────────────────────────────────────────────
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _companyCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _notesCtrl;

  // ── Save state (ίδια λογική με NoteDetailScreen) ───────────
  bool _isSaving = false;
  bool _isEditingName = false;
  String _lastSavedName = '';
  bool _hasEverBeenSaved = false;

  // ── Cached props ───────────────────────────────────────────
  String _lastPhone = '';
  String _lastEmail = '';
  String _lastCompany = '';
  String _lastWebsite = '';
  String _lastAddress = '';
  String _lastNotes = '';
  DateTime? _lastBirthday;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _companyCtrl = TextEditingController();
    _websiteCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    DebugConfig.nav(
        'ContactDetailScreen init id=${widget.itemId} isNew=${widget.isNew}');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _companyCtrl.dispose();
    _websiteCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged(String _) => _isEditingName = true;

  Future<void> _save() async {
    if (!mounted) return;
    setState(() => _isSaving = true);

    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final company = _companyCtrl.text.trim();
    final website = _websiteCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final notes = _notesCtrl.text.trim();

    DebugConfig.db('ContactDetail save id=${widget.itemId} name="$name"');

    await ref
        .read(itemNotifierProvider.notifier)
        .updateItem(widget.itemId, title: name.isEmpty ? null : name);

    final notifier = ref.read(propertyNotifierProvider(widget.itemId).notifier);

    if (phone != _lastPhone) {
      await notifier.setText('phone', phone.isEmpty ? null : phone);
    }
    if (email != _lastEmail) {
      await notifier.setText('email', email.isEmpty ? null : email);
    }
    if (company != _lastCompany) {
      await notifier.setText('company', company.isEmpty ? null : company);
    }
    if (website != _lastWebsite) {
      await notifier.setText('website', website.isEmpty ? null : website);
    }
    if (address != _lastAddress) {
      await notifier.setText('address', address.isEmpty ? null : address);
    }
    if (notes != _lastNotes) {
      await notifier.setText('notes', notes.isEmpty ? null : notes);
    }

    _lastSavedName = name;
    _lastPhone = phone;
    _lastEmail = email;
    _lastCompany = company;
    _lastWebsite = website;
    _lastAddress = address;
    _lastNotes = notes;
    _hasEverBeenSaved = true;
    _isEditingName = false;

    if (!mounted) return;
    setState(() => _isSaving = false);
    ref.invalidate(itemNotifierProvider);

    DebugConfig.db('ContactDetail saved successfully');
  }

  Future<void> _pickBirthday(BuildContext context) async {
    final now = DateTime.now();
    final init = _lastBirthday ?? DateTime(1990, 1, 1);

    final picked = await showDatePicker(
      context: context,
      locale: const Locale('el', 'GR'),
      initialDate: init,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null || !mounted) return;

    DebugConfig.db('ContactDetail setBirthday $picked');
    await ref
        .read(propertyNotifierProvider(widget.itemId).notifier)
        .setDate('birthday', picked);
    setState(() => _lastBirthday = picked);
  }

  Future<void> _clearBirthday() async {
    await ref
        .read(propertyNotifierProvider(widget.itemId).notifier)
        .remove('birthday');
    setState(() => _lastBirthday = null);
  }

  Future<bool> _onPopInvoked() async {
    if (widget.isNew && !_hasEverBeenSaved) {
      DebugConfig.db(
          'ContactDetail auto-delete NEW contact id=${widget.itemId}');
      await ref.read(itemNotifierProvider.notifier).deleteItem(widget.itemId);
      return true;
    }
    DebugConfig.nav('ContactDetail back keep id=${widget.itemId}');
    return true;
  }

  Future<void> _delete(BuildContext context) async {
    final future = ConfirmDialog.delete(context, title: 'Διαγραφή επαφής;');
    final ok = await future;
    if (!ok || !mounted) return;
    DebugConfig.db('ContactDetail delete id=${widget.itemId}');
    await ref.read(itemNotifierProvider.notifier).deleteItem(widget.itemId);
    if (!mounted) return;
    ref.invalidate(itemNotifierProvider);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _togglePin(Item item) async {
    await ref
        .read(itemNotifierProvider.notifier)
        .togglePin(item.id, item.pinned);
  }

  Future<void> _toggleFav(Item item) async {
    await ref
        .read(itemNotifierProvider.notifier)
        .toggleFavorite(item.id, item.favorite);
  }

  Future<void> _toggleArchive(Item item) async {
    await ref
        .read(itemNotifierProvider.notifier)
        .toggleArchive(item.id, item.archived);
  }

  // ── Reminder bottom sheet (ίδιο με NoteDetailScreen) ─────────
  Future<void> _showReminderDialog() async {
    final title =
    _nameCtrl.text.trim().isEmpty ? 'Επαφή' : _nameCtrl.text.trim();
    await showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: ReminderSection(
          itemId: widget.itemId,
          itemTitle: title,
          defaultStartTime: null,
        ),
      ),
    );
  }

  // ── Tag picker sheet ────────────────────────────────────────
  void _showTagPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) => _TagPickerSheet(itemId: widget.itemId),
    );
  }

  @override
  Widget build(BuildContext context) {
    DebugConfig.provider('ContactDetailScreen build id=${widget.itemId}');
    final itemAsync = ref.watch(itemStreamProvider(widget.itemId));

    return itemAsync.when(
      loading: () => _buildLoading(),
      error: (e, _) {
        DebugConfig.error('ContactDetail load failed', e);
        return _buildError();
      },
      data: (item) {
        if (item == null) return _buildNotFound();

        if (!_isEditingName) {
          final dbName = item.title ?? '';
          if (_nameCtrl.text != dbName) {
            _nameCtrl.text = dbName;
            _nameCtrl.selection =
                TextSelection.collapsed(offset: _nameCtrl.text.length);
          }
          if (_lastSavedName.isEmpty && dbName.isNotEmpty) {
            _lastSavedName = dbName;
          }
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final nav = Navigator.of(context);
            final canPop = await _onPopInvoked();
            if (canPop) nav.pop();
          },
          child: ResponsiveLayout(
            mobile: _buildMobile(context, item),
            tablet: _buildTablet(context, item),
          ),
        );
      },
    );
  }

  Widget _buildMobile(BuildContext context, Item item) => Scaffold(
    backgroundColor: context.cBg,
    appBar: _buildAppBar(context, item),
    body: _ContactBody(
      item: item,
      nameCtrl: _nameCtrl,
      phoneCtrl: _phoneCtrl,
      emailCtrl: _emailCtrl,
      companyCtrl: _companyCtrl,
      websiteCtrl: _websiteCtrl,
      addressCtrl: _addressCtrl,
      notesCtrl: _notesCtrl,
      birthday: _lastBirthday,
      onNameChanged: _onNameChanged,
      onPickBirthday: () => _pickBirthday(context),
      onClearBirthday: _clearBirthday,
      onSyncProps: _syncPropsFromDB,
      onShowTagPicker: _showTagPicker,
    ),
  );

  Widget _buildTablet(BuildContext context, Item item) => Scaffold(
    backgroundColor: context.cBg,
    appBar: _buildAppBar(context, item),
    body: Row(
      children: [
        SizedBox(
          width: context.isDesktop ? 280 : 240,
          child: _ContactSummaryPanel(
            item: item,
            onShowTagPicker: _showTagPicker,
          ),
        ),
        VerticalDivider(
            width: 1, color: ColorsUI.getBorder(context.brightness)),
        Expanded(
          child: _ContactBody(
            item: item,
            nameCtrl: _nameCtrl,
            phoneCtrl: _phoneCtrl,
            emailCtrl: _emailCtrl,
            companyCtrl: _companyCtrl,
            websiteCtrl: _websiteCtrl,
            addressCtrl: _addressCtrl,
            notesCtrl: _notesCtrl,
            birthday: _lastBirthday,
            onNameChanged: _onNameChanged,
            onPickBirthday: () => _pickBirthday(context),
            onClearBirthday: _clearBirthday,
            onSyncProps: _syncPropsFromDB,
            onShowTagPicker: _showTagPicker,
          ),
        ),
      ],
    ),
  );

  AppBar _buildAppBar(BuildContext context, Item item) => AppBar(
    backgroundColor: context.cBg,
    elevation: 0,
    scrolledUnderElevation: 1,
    title: _isSaving
        ? Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: context.cText2),
      ),
      const SizedBox(width: Spacing.xs),
      Text('Αποθήκευση...',
          style: context.bodySm.withColor(context.cText2)),
    ])
        : null,
    actions: [
      // Save
      IconButton(
        icon: Icon(Icons.save_rounded, color: context.cPrimary),
        tooltip: 'Αποθήκευση',
        onPressed: () async {
          await _save();
          if (!context.mounted) return;
          Navigator.of(context).pop();
        },
      ),
      // Reminder
      IconButton(
        icon: Icon(Icons.notifications_none_rounded, color: context.cText2),
        onPressed: _showReminderDialog,
        tooltip: 'Υπενθύμιση',
      ),
      // Favorite
      IconButton(
        icon: Icon(
          item.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
          color: item.favorite
              ? ColorsUI.getWarning(context.brightness)
              : context.cText2,
        ),
        onPressed: () => _toggleFav(item),
        tooltip: item.favorite ? 'Αφαίρεση αγαπημένου' : 'Αγαπημένο',
      ),
      // Pin
      IconButton(
        icon: Icon(
          item.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
          color: item.pinned ? context.cPrimary : context.cText2,
        ),
        onPressed: () => _togglePin(item),
        tooltip: item.pinned ? 'Αποκαρφίτσωμα' : 'Καρφίτσωμα',
      ),
      // Archive
      IconButton(
        icon: Icon(
          item.archived ? Icons.unarchive_rounded : Icons.archive_rounded,
          color: context.cText2,
        ),
        onPressed: () => _toggleArchive(item),
        tooltip: item.archived ? 'Επαναφορά' : 'Αρχειοθέτηση',
      ),
      // Delete
      IconButton(
        icon: Icon(Icons.delete_outline_rounded, color: context.cError),
        onPressed: () => _delete(context),
        tooltip: 'Διαγραφή',
      ),
    ],
  );

  void _syncPropsFromDB(List<ItemProperty> props) {
    if (_lastPhone.isNotEmpty) return;

    final phone = props.where((p) => p.key == 'phone').firstOrNull?.value ?? '';
    final email = props.where((p) => p.key == 'email').firstOrNull?.value ?? '';
    final company =
        props.where((p) => p.key == 'company').firstOrNull?.value ?? '';
    final website =
        props.where((p) => p.key == 'website').firstOrNull?.value ?? '';
    final address =
        props.where((p) => p.key == 'address').firstOrNull?.value ?? '';
    final notes = props.where((p) => p.key == 'notes').firstOrNull?.value ?? '';
    final bdStr = props.where((p) => p.key == 'birthday').firstOrNull?.value;

    if (_phoneCtrl.text.isEmpty && phone.isNotEmpty) _phoneCtrl.text = phone;
    if (_emailCtrl.text.isEmpty && email.isNotEmpty) _emailCtrl.text = email;
    if (_companyCtrl.text.isEmpty && company.isNotEmpty) {
      _companyCtrl.text = company;
    }
    if (_websiteCtrl.text.isEmpty && website.isNotEmpty) {
      _websiteCtrl.text = website;
    }
    if (_addressCtrl.text.isEmpty && address.isNotEmpty) {
      _addressCtrl.text = address;
    }
    if (_notesCtrl.text.isEmpty && notes.isNotEmpty) _notesCtrl.text = notes;

    _lastPhone = phone;
    _lastEmail = email;
    _lastCompany = company;
    _lastWebsite = website;
    _lastAddress = address;
    _lastNotes = notes;
    if (bdStr != null) _lastBirthday = DateTime.tryParse(bdStr);
  }

  Widget _buildLoading() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(backgroundColor: context.cBg),
    body: const Center(child: CircularProgressIndicator()),
  );

  Widget _buildError() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(backgroundColor: context.cBg),
    body: EmptyState.error(
        onRetry: () => ref.invalidate(itemStreamProvider(widget.itemId))),
  );

  Widget _buildNotFound() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(backgroundColor: context.cBg),
    body: const EmptyState(
      icon: Icons.person_off_rounded,
      title: 'Η επαφή δεν βρέθηκε',
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// CONTACT BODY — η φόρμα
// ════════════════════════════════════════════════════════════════

class _ContactBody extends ConsumerWidget {
  final Item item;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController companyCtrl;
  final TextEditingController websiteCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController notesCtrl;
  final DateTime? birthday;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onPickBirthday;
  final VoidCallback onClearBirthday;
  final ValueChanged<List<ItemProperty>> onSyncProps;
  final VoidCallback onShowTagPicker;

  const _ContactBody({
    required this.item,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
    required this.companyCtrl,
    required this.websiteCtrl,
    required this.addressCtrl,
    required this.notesCtrl,
    required this.birthday,
    required this.onNameChanged,
    required this.onPickBirthday,
    required this.onClearBirthday,
    required this.onSyncProps,
    required this.onShowTagPicker,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(item.id));
    final props = propsAsync.valueOrNull ?? [];
    if (props.isNotEmpty) onSyncProps(props);

    final bdStr = props.where((p) => p.key == 'birthday').firstOrNull?.value;
    final dbBirthday = bdStr != null ? DateTime.tryParse(bdStr) : null;
    final displayBirthday = birthday ?? dbBirthday;

    final color = ColorsUI.itemTypeColor(ItemType.contact, context.brightness);
    final name = item.title ?? '';
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final tagsAsync = ref.watch(itemTagsProvider(item.id));

    return CustomScrollView(
      slivers: [
        // ── Avatar + Name ────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              context.responsiveHPadding,
              Spacing.lg,
              context.responsiveHPadding,
              Spacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(letter, style: context.h2.withColor(color)),
                  ),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: TextField(
                    controller: nameCtrl,
                    onChanged: onNameChanged,
                    style: context.h2.copyWith(fontWeight: FontWeight.w600),
                    maxLines: null,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Όνομα επαφής...',
                      hintStyle: context.h2.withColor(context.cDisabled),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Divider ──────────────────────────────────────────
        SliverToBoxAdapter(
          child: Divider(
              indent: context.responsiveHPadding,
              endIndent: context.responsiveHPadding,
              color: ColorsUI.getBorder(context.brightness)),
        ),

        // ── Fields ───────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.responsiveHPadding,
              vertical: Spacing.sm,
            ),
            child: Column(
              children: [
                _ContactField(
                  icon: Icons.phone_rounded,
                  label: 'Τηλέφωνο',
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
                  ],
                ),
                _ContactField(
                  icon: Icons.email_rounded,
                  label: 'Email',
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                ),
                _ContactField(
                  icon: Icons.business_rounded,
                  label: 'Εταιρεία',
                  controller: companyCtrl,
                  textCapitalization: TextCapitalization.words,
                ),
                _ContactField(
                  icon: Icons.language_rounded,
                  label: 'Website',
                  controller: websiteCtrl,
                  keyboardType: TextInputType.url,
                ),
                _ContactField(
                  icon: Icons.location_on_rounded,
                  label: 'Διεύθυνση',
                  controller: addressCtrl,
                  maxLines: 2,
                ),
                _BirthdayField(
                  birthday: displayBirthday,
                  onPick: onPickBirthday,
                  onClear: onClearBirthday,
                ),
                _ContactField(
                  icon: Icons.notes_rounded,
                  label: 'Σημειώσεις',
                  controller: notesCtrl,
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ),

        // ── Tags section (ίδιο με NoteDetailScreen) ─────────
        SliverToBoxAdapter(
          child: Padding(
            padding:
            EdgeInsets.symmetric(horizontal: context.responsiveHPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: Spacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tags',
                        style: context.labelSm.withColor(context.cText2)),
                    TextButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Προσθήκη'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onShowTagPicker,
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.xs),
                tagsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (tags) => TagChipList.interactive(
                    tagNames: tags.map((t) => t.name).toList(),
                    tagColors: tags.map((t) => t.color).toList(),
                    onTagDelete: (name) async {
                      final tag = tags.firstWhere((t) => t.name == name,
                          orElse: () => tags.first);
                      await ref
                          .read(tagNotifierProvider.notifier)
                          .removeFromItem(item.id, tag.id);
                    },
                    onAdd: onShowTagPicker,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CONTACT FIELD
// ════════════════════════════════════════════════════════════════

class _ContactField extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;

  const _ContactField({
    required this.icon,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Icon(icon, size: 18, color: context.cText2),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              textCapitalization: textCapitalization,
              inputFormatters: inputFormatters,
              maxLines: maxLines,
              style: context.bodyMd,
              decoration: InputDecoration(
                labelText: label,
                labelStyle: context.bodySm.withColor(context.cText2),
                filled: true,
                fillColor: ColorsUI.getSurface(context.brightness),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.inputBR,
                  borderSide:
                  BorderSide(color: ColorsUI.getBorder(context.brightness)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.inputBR,
                  borderSide:
                  BorderSide(color: ColorsUI.getBorder(context.brightness)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.inputBR,
                  borderSide: BorderSide(color: context.cPrimary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md, vertical: Spacing.sm),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// BIRTHDAY FIELD
// ════════════════════════════════════════════════════════════════

class _BirthdayField extends StatelessWidget {
  final DateTime? birthday;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _BirthdayField({
    required this.birthday,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final label = birthday != null
        ? DateFormat.yMMMMd('el_GR').format(birthday!)
        : 'Επιλογή ημερομηνίας';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs + 2),
      child: Row(
        children: [
          Icon(Icons.cake_rounded, size: 18, color: context.cText2),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: GestureDetector(
              onTap: onPick,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md, vertical: Spacing.sm + 4),
                decoration: BoxDecoration(
                  color: ColorsUI.getSurface(context.brightness),
                  borderRadius: AppRadius.inputBR,
                  border:
                  Border.all(color: ColorsUI.getBorder(context.brightness)),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Γενέθλια',
                            style: context.bodySm.withColor(context.cText2)),
                        const SizedBox(height: 2),
                        Text(label,
                            style: context.bodyMd.withColor(
                              birthday != null
                                  ? context.cText
                                  : context.cDisabled,
                            )),
                      ],
                    ),
                  ),
                  if (birthday != null)
                    GestureDetector(
                      onTap: onClear,
                      child: Icon(Icons.close_rounded,
                          size: 16, color: context.cText2),
                    ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SUMMARY PANEL — tablet left panel (με tags)
// ════════════════════════════════════════════════════════════════

class _ContactSummaryPanel extends ConsumerWidget {
  final Item item;
  final VoidCallback onShowTagPicker;

  const _ContactSummaryPanel({
    required this.item,
    required this.onShowTagPicker,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(item.id));
    final props = propsAsync.valueOrNull ?? [];
    final phone = props.where((p) => p.key == 'phone').firstOrNull?.value;
    final email = props.where((p) => p.key == 'email').firstOrNull?.value;
    final company = props.where((p) => p.key == 'company').firstOrNull?.value;
    final tagsAsync = ref.watch(itemTagsProvider(item.id));

    final color = ColorsUI.itemTypeColor(ItemType.contact, context.brightness);
    final name = item.title ?? '';
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      color: ColorsUI.getSurface(context.brightness),
      padding: const EdgeInsets.all(Spacing.lg),
      child: ListView(
        children: [
          const SizedBox(height: Spacing.lg),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(letter, style: context.h1.withColor(color)),
            ),
          ),
          const SizedBox(height: Spacing.md),
          Text(name.isNotEmpty ? name : 'Νέα επαφή',
              style: context.titleLg, textAlign: TextAlign.center),
          if (company != null) ...[
            const SizedBox(height: Spacing.xs),
            Text(company,
                style: context.bodyMd.withColor(context.cText2),
                textAlign: TextAlign.center),
          ],
          const SizedBox(height: Spacing.lg),
          const Divider(),
          const SizedBox(height: Spacing.sm),
          if (phone != null)
            _QuickAction(
              icon: Icons.call_rounded,
              label: phone,
              color: context.cSuccess,
            ),
          if (email != null)
            _QuickAction(
              icon: Icons.email_rounded,
              label: email,
              color: context.cPrimary,
            ),
          const Divider(height: Spacing.xl),
          Text('Tags', style: context.labelMd.withColor(context.cText2)),
          const SizedBox(height: Spacing.sm),
          tagsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (tags) => TagChipList.readOnly(
              tagNames: tags.map((t) => t.name).toList(),
              tagColors: tags.map((t) => t.color).toList(),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          TextButton.icon(
            onPressed: onShowTagPicker,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Προσθήκη Tag'),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _QuickAction(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Text(label,
              style: context.bodyMd,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAG PICKER SHEET (αντιγραφή για αυτονομία)
// ════════════════════════════════════════════════════════════════

class _TagPickerSheet extends ConsumerStatefulWidget {
  final int itemId;
  const _TagPickerSheet({required this.itemId});

  @override
  ConsumerState<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<_TagPickerSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _addTag(String name) async {
    if (name.trim().isEmpty) return;
    final tag =
    await ref.read(tagNotifierProvider.notifier).createOrGet(name.trim());
    if (tag == null || !mounted) return;
    await ref
        .read(tagNotifierProvider.notifier)
        .addToItem(widget.itemId, tag.id);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);
    final itemTagsAsync = ref.watch(itemTagsProvider(widget.itemId));
    final itemTagIds =
        itemTagsAsync.valueOrNull?.map((t) => t.id).toSet() ?? {};

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: context.cBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: Spacing.md),
            Text('Προσθήκη Tag', style: context.titleMd),
            const SizedBox(height: Spacing.md),
            TextField(
              controller: _ctrl,
              autofocus: true,
              onSubmitted: _addTag,
              decoration: InputDecoration(
                hintText: 'Νέο tag...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => _addTag(_ctrl.text),
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
            tagsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (tags) {
                final available =
                tags.where((t) => !itemTagIds.contains(t.id)).toList();
                if (available.isEmpty) return const SizedBox.shrink();
                return Wrap(
                  spacing: Spacing.xs,
                  runSpacing: Spacing.xs,
                  children: available
                      .map((t) => TagChip(
                    name: t.name,
                    color: t.color,
                    onTap: () async {
                      final nav = Navigator.of(context);
                      await ref
                          .read(tagNotifierProvider.notifier)
                          .addToItem(widget.itemId, t.id);
                      nav.pop();
                    },
                  ))
                      .toList(),
                );
              },
            ),
            SizedBox(
                height: MediaQuery.of(context).padding.bottom + Spacing.sm),
          ],
        ),
      ),
    );
  }
}