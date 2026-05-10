// lib/features/contacts/contact_detail_screen.dart
//
// Detail screen επαφής: όνομα, πολλαπλά τηλέφωνα (αποθηκεύονται ως JSON),
// email, εταιρεία, website, διεύθυνση, σημειώσεις, γενέθλια, tags.
// ✅ Folder‑aware: δείχνει φάκελο
// ✅ Save logic: isNew + manual Save button (ίδια με NoteDetailScreen)
// ✅ Responsive: single col mobile / two‑panel tablet
// ✅ Dark mode: ColorsUI + context extensions
// ✅ DebugConfig: nav, db, provider logs
// ✅ AppBar: Αποθήκευση, Υπενθύμιση, Αγαπημένο, Pin, Αρχειοθέτηση, Διαγραφή
// ✅ Tags: προβολή, προσθήκη, αφαίρεση
//
import 'dart:convert'; // 🆕 για jsonEncode / jsonDecode
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
  // 🆕 Λίστα controllers για πολλαπλά τηλέφωνα
  late final List<TextEditingController> _phoneCtrls;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _companyCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _notesCtrl;

  // ── Save state (ίδια λογική με NoteDetailScreen) ───────────
  // ignore: prefer_final_fields
  bool _isSaving = false;
  bool _isEditingName = false;
  String _lastSavedName = '';

  // ── Cached values ─────────────────────────────────────────
  String _lastPhonesJson = '';   // 🆕 αντί για _lastPhone
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
    _phoneCtrls = [];   // 🆕
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
    for (final c in _phoneCtrls) {
      c.dispose();
    }
    _emailCtrl.dispose();
    _companyCtrl.dispose();
    _websiteCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onNameChanged(String _) => _isEditingName = true;

  // 🆕 Προσθήκη νέου πεδίου τηλεφώνου
  void _addPhoneField() {
    setState(() {
      _phoneCtrls.add(TextEditingController());
    });
  }

  // 🆕 Αφαίρεση πεδίου τηλεφώνου (εκτός αν είναι το τελευταίο, μπορεί να μείνει κενό)
  void _removePhoneField(int index) {
    if (_phoneCtrls.length <= 1) return; // κρατάμε τουλάχιστον ένα κενό πεδίο
    setState(() {
      _phoneCtrls[index].dispose();
      _phoneCtrls.removeAt(index);
    });
  }

  /// Αποθηκεύει τις τρέχουσες τιμές των πεδίων στη βάση
  /// μόνο αν έχουν αλλάξει σε σχέση με τις cached τιμές.
  Future<void> _persistChanges() async {
    final name    = _nameCtrl.text.trim();
    final email   = _emailCtrl.text.trim();
    final company = _companyCtrl.text.trim();
    final website = _websiteCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final notes   = _notesCtrl.text.trim();

    final phonesList = _phoneCtrls
        .map((c) => c.text.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final phonesJson = jsonEncode(phonesList);

    // 1. Τίτλος (πρώτα, ανεξάρτητα)
    if (name != _lastSavedName) {
      await ref.read(itemNotifierProvider.notifier)
          .updateItem(widget.itemId, title: name.isEmpty ? null : name);
    }

    // 2. Properties παράλληλα (μόνο αυτά που άλλαξαν)
    final notifier = ref.read(propertyNotifierProvider(widget.itemId).notifier);
    final futures  = <Future<void>>[];

    if (phonesJson != _lastPhonesJson) {
      futures.add(notifier.setText('phones', phonesList.isEmpty ? null : phonesJson));
      futures.add(notifier.remove('phone')); // καθαρισμός παλιού key
    }
    if (email   != _lastEmail)   futures.add(notifier.setText('email',   email.isEmpty   ? null : email));
    if (company != _lastCompany) futures.add(notifier.setText('company', company.isEmpty ? null : company));
    if (website != _lastWebsite) futures.add(notifier.setText('website', website.isEmpty ? null : website));
    if (address != _lastAddress) futures.add(notifier.setText('address', address.isEmpty ? null : address));
    if (notes   != _lastNotes)   futures.add(notifier.setText('notes',   notes.isEmpty   ? null : notes));

    if (futures.isNotEmpty) await Future.wait(futures);

    _lastSavedName  = name;
    _lastPhonesJson = phonesJson;
    _lastEmail      = email;
    _lastCompany    = company;
    _lastWebsite    = website;
    _lastAddress    = address;
    _lastNotes      = notes;
    _isEditingName  = false;

    DebugConfig.db('ContactDetail changes persisted id=${widget.itemId}');
  }

  Future<void> _saveOrDelete() async {
    if (_isSaving) return;
    final name = _nameCtrl.text.trim();

    if (name.isEmpty) {
      DebugConfig.db('ContactDetail delete empty contact id=${widget.itemId}');
      try {
        if (widget.isNew) {
          await ref.read(itemNotifierProvider.notifier).deleteItem(widget.itemId);
        }
      } catch (e) {
        DebugConfig.error('ContactDetail delete', e);
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _persistChanges();
    } catch (e) {
      DebugConfig.error('ContactDetail save', e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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

  Future<void> _delete(BuildContext context) async {
    final ok = await ConfirmDialog.delete(context, title: 'Διαγραφή επαφής;');
    if (!ok || !mounted) return;
    DebugConfig.db('ContactDetail delete id=${widget.itemId}');
    await ref.read(itemNotifierProvider.notifier).deleteItem(widget.itemId);
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

  void _showTagPicker() {
    showTagPickerSheet(context, widget.itemId);
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
            await _saveOrDelete();
            if (!nav.mounted) return;
            nav.pop();
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
      phoneCtrls: _phoneCtrls,   // 🆕
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
      onAddPhone: _addPhoneField,      // 🆕
      onRemovePhone: _removePhoneField, // 🆕
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
            phoneCtrls: _phoneCtrls,   // 🆕
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
            onAddPhone: _addPhoneField,      // 🆕
            onRemovePhone: _removePhoneField, // 🆕
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
      Text('',
          style: context.bodySm.withColor(context.cText2)),
    ])
        : null,
    actions: [
      // Save
      // Save
      IconButton(
        icon: Icon(Icons.save_rounded, color: context.cPrimary),
        tooltip: 'Αποθήκευση',
        onPressed: () async {
          if (_nameCtrl.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Παρακαλώ προσθέστε όνομα επαφής')),
            );
            return;
          }
          final nav = Navigator.of(context);
          await _saveOrDelete();
          if (!nav.mounted) return;
          nav.pop();
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
    // 🆕 Αν δεν έχουμε ακόμα τηλέφωνα, τα φορτώνουμε από τα props
    if (_phoneCtrls.isEmpty) {
      // Προσπαθούμε να διαβάσουμε 'phones' (JSON λίστα)
      final phonesJson = props.where((p) => p.key == 'phones').firstOrNull?.value;
      List<String> phones = [];
      if (phonesJson != null && phonesJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(phonesJson);
          if (decoded is List) {
            phones = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {
          // Αγνοούμε – θα δοκιμάσουμε το παλιό 'phone'
        }
      }
      // Fallback στο παλιό κλειδί 'phone'
      if (phones.isEmpty) {
        final oldPhone = props.where((p) => p.key == 'phone').firstOrNull?.value;
        if (oldPhone != null && oldPhone.isNotEmpty) {
          phones = [oldPhone];
        }
      }
      // Αν δεν έχουμε κανένα τηλέφωνο, βάζουμε ένα κενό πεδίο
      if (phones.isEmpty) {
        phones = [''];
      }

      // Δημιουργούμε controllers και ενημερώνουμε το cached json
      for (final p in phones) {
        _phoneCtrls.add(TextEditingController(text: p));
      }
      _lastPhonesJson = jsonEncode(phones.where((p) => p.isNotEmpty).toList());
    } else if (_lastPhonesJson.isEmpty) {
      // Έχουμε ήδη controllers αλλά δεν έχουμε cached – πιθανόν πρώτη φόρτωση
      final currentPhones = _phoneCtrls.map((c) => c.text.trim()).where((p) => p.isNotEmpty).toList();
      _lastPhonesJson = jsonEncode(currentPhones);
    }

    // Υπόλοιπα πεδία (ίδια λογική)
    if (_lastEmail.isNotEmpty) return;

    final email = props.where((p) => p.key == 'email').firstOrNull?.value ?? '';
    final company = props.where((p) => p.key == 'company').firstOrNull?.value ?? '';
    final website = props.where((p) => p.key == 'website').firstOrNull?.value ?? '';
    final address = props.where((p) => p.key == 'address').firstOrNull?.value ?? '';
    final notes = props.where((p) => p.key == 'notes').firstOrNull?.value ?? '';
    final bdStr = props.where((p) => p.key == 'birthday').firstOrNull?.value;

    if (_emailCtrl.text.isEmpty && email.isNotEmpty) _emailCtrl.text = email;
    if (_companyCtrl.text.isEmpty && company.isNotEmpty) _companyCtrl.text = company;
    if (_websiteCtrl.text.isEmpty && website.isNotEmpty) _websiteCtrl.text = website;
    if (_addressCtrl.text.isEmpty && address.isNotEmpty) _addressCtrl.text = address;
    if (_notesCtrl.text.isEmpty && notes.isNotEmpty) _notesCtrl.text = notes;

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
// CONTACT BODY — η φόρμα (υποστηρίζει πολλαπλά τηλέφωνα)
// ════════════════════════════════════════════════════════════════

class _ContactBody extends ConsumerWidget {
  final Item item;
  final TextEditingController nameCtrl;
  final List<TextEditingController> phoneCtrls; // 🆕
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
  final VoidCallback onAddPhone;      // 🆕
  final ValueChanged<int> onRemovePhone; // 🆕

  const _ContactBody({
    required this.item,
    required this.nameCtrl,
    required this.phoneCtrls,
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
    required this.onAddPhone,
    required this.onRemovePhone,
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
                // 🆕 Πολλαπλά τηλέφωνα
                _PhoneListEditor(
                  controllers: phoneCtrls,
                  onAdd: onAddPhone,
                  onRemove: onRemovePhone,
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

        // ── Tags section ─────────────────────────────────────
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

// 🆕 Widget για λίστα τηλεφώνων
class _PhoneListEditor extends StatelessWidget {
  final List<TextEditingController> controllers;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _PhoneListEditor({
    required this.controllers,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.phone_rounded, size: 18, color: context.cText2),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Text('Τηλέφωνο${controllers.length > 1 ? ' (${controllers.length})' : ''}',
                  style: context.bodySm.withColor(context.cText2)),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.add_circle_outline_rounded, color: context.cPrimary, size: 22),
              onPressed: onAdd,
              tooltip: 'Προσθήκη τηλεφώνου',
            ),
          ],
        ),
        ...controllers.asMap().entries.map((entry) {
          final index = entry.key;
          final ctrl = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Row(
              children: [
                const SizedBox(width: 18 + Spacing.md), // στοίχιση με το εικονίδιο
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
                    ],
                    style: context.bodyMd,
                    decoration: InputDecoration(
                      hintText: 'π.χ. 2101234567',
                      hintStyle: context.bodyMd.withColor(context.cDisabled),
                      filled: true,
                      fillColor: ColorsUI.getSurface(context.brightness),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.inputBR,
                        borderSide: BorderSide(color: ColorsUI.getBorder(context.brightness)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.inputBR,
                        borderSide: BorderSide(color: ColorsUI.getBorder(context.brightness)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.inputBR,
                        borderSide: BorderSide(color: context.cPrimary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
                    ),
                  ),
                ),
                if (controllers.length > 1)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline_rounded, color: context.cError, size: 22),
                    onPressed: () => onRemove(index),
                    tooltip: 'Αφαίρεση τηλεφώνου',
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CONTACT FIELD (απλό, αμετάβλητο)
// ════════════════════════════════════════════════════════════════

class _ContactField extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;

  const _ContactField({
    required this.icon,
    required this.label,
    required this.controller,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
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
// BIRTHDAY FIELD (αμετάβλητο)
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
// SUMMARY PANEL — tablet left panel (δείχνει πολλαπλά τηλέφωνα)
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

    // 🆕 Διαβάζουμε τα τηλέφωνα από 'phones' ή 'phone'
    List<String> phones = [];
    final phonesJson = props.where((p) => p.key == 'phones').firstOrNull?.value;
    if (phonesJson != null && phonesJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(phonesJson);
        if (decoded is List) {
          phones = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    if (phones.isEmpty) {
      final oldPhone = props.where((p) => p.key == 'phone').firstOrNull?.value;
      if (oldPhone != null && oldPhone.isNotEmpty) {
        phones = [oldPhone];
      }
    }

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
          // 🆕 Εμφάνιση όλων των τηλεφώνων
          ...phones.map((p) => _QuickAction(
            icon: Icons.call_rounded,
            label: p,
            color: context.cSuccess,
          )),
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