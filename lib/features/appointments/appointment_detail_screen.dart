// lib/features/appointments/appointment_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/core.dart';
import '../../helpers/super_note_helper.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/widgets.dart';

class AppointmentDetailScreen extends ConsumerStatefulWidget {
  final int itemId;
  final bool isNew;

  const AppointmentDetailScreen({
    super.key,
    required this.itemId,
    this.isNew = false,
  });

  @override
  ConsumerState<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState
    extends ConsumerState<AppointmentDetailScreen> {
  // --- Basic fields ---
  late TextEditingController _titleCtrl;
  late final FocusNode _titleFocusNode;
  late TextEditingController _locationCtrl;
  late TextEditingController _notesCtrl;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isFavorite = false;
  bool _isSaving = false;
  bool _isEditingTitle = false;

  // --- Contact fields ---
  late TextEditingController _contactNameCtrl;
  late TextEditingController _contactPhoneCtrl;
  late TextEditingController _contactEmailCtrl;
  late TextEditingController _contactCompanyCtrl;
  late TextEditingController _contactWebsiteCtrl;
  late TextEditingController _contactAddressCtrl;
  late TextEditingController _contactNotesCtrl;
  DateTime? _contactBirthday;

  bool _contactSectionExpanded = false;
  int? _linkedContactId;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _titleFocusNode = FocusNode();
    _titleFocusNode.addListener(() {
      if (!mounted) return;

      if (!_titleFocusNode.hasFocus && _isEditingTitle) {
        setState(() => _isEditingTitle = false);
      }
    });
    _locationCtrl = TextEditingController();
    _notesCtrl = TextEditingController();

    _contactNameCtrl = TextEditingController();
    _contactPhoneCtrl = TextEditingController();
    _contactEmailCtrl = TextEditingController();
    _contactCompanyCtrl = TextEditingController();
    _contactWebsiteCtrl = TextEditingController();
    _contactAddressCtrl = TextEditingController();
    _contactNotesCtrl = TextEditingController();

    _loadData();
    DebugConfig.nav('AppointmentDetailScreen init id=${widget.itemId}');
  }

  Future<void> _loadData() async {
    final item = await ref.read(itemByIdProvider(widget.itemId).future);
    if (!mounted) return;
    if (item == null) return;

    _titleCtrl.text = item.title ?? '';
    _isFavorite = item.favorite;

    final props = await ref.read(itemPropertiesProvider(widget.itemId).future);
    if (!mounted) return;

    for (final p in props) {
      switch (p.key) {
        case 'date':
          _selectedDate = p.dateValue;
          break;
        case 'time':
          if (p.value != null && p.value!.isNotEmpty) {
            final parts = p.value!.split(':');
            if (parts.length == 2) {
              _selectedTime = TimeOfDay(
                hour: int.parse(parts[0]),
                minute: int.parse(parts[1]),
              );
            }
          }
          break;
        case 'location':
          _locationCtrl.text = p.value ?? '';
          break;
        case 'notes':
          _notesCtrl.text = p.value ?? '';
          break;
        case 'contact_name':
          _contactNameCtrl.text = p.value ?? '';
          break;
        case 'contact_phone':
          _contactPhoneCtrl.text = p.value ?? '';
          break;
        case 'contact_email':
          _contactEmailCtrl.text = p.value ?? '';
          break;
        case 'contact_company':
          _contactCompanyCtrl.text = p.value ?? '';
          break;
        case 'contact_website':
          _contactWebsiteCtrl.text = p.value ?? '';
          break;
        case 'contact_address':
          _contactAddressCtrl.text = p.value ?? '';
          break;
        case 'contact_notes':
          _contactNotesCtrl.text = p.value ?? '';
          break;
        case 'contact_birthday':
          if (p.value != null) _contactBirthday = DateTime.tryParse(p.value!);
          break;
      }
    }

    final relations = await SuperNoteHelper.instance.relations.getFrom(widget.itemId);
    Relation? contactRelation;
    for (final r in relations) {
      if (r.relationType == RelationType.references) {
        contactRelation = r;
        break;
      }
    }
    if (contactRelation != null) {
      final contactId = contactRelation.toItemId;
      final contact = await ref.read(itemByIdProvider(contactId).future);
      if (contact != null && contact.type == ItemType.contact) {
        _linkedContactId = contactId;
        final contactProps = await ref.read(itemPropertiesProvider(contactId).future);
        if (_contactNameCtrl.text.isEmpty) {
          _contactNameCtrl.text = contact.title ?? '';
        }
        for (final p in contactProps) {
          switch (p.key) {
            case 'phone':
              if (_contactPhoneCtrl.text.isEmpty) _contactPhoneCtrl.text = p.value ?? '';
              break;
            case 'email':
              if (_contactEmailCtrl.text.isEmpty) _contactEmailCtrl.text = p.value ?? '';
              break;
            case 'company':
              if (_contactCompanyCtrl.text.isEmpty) _contactCompanyCtrl.text = p.value ?? '';
              break;
            case 'website':
              if (_contactWebsiteCtrl.text.isEmpty) _contactWebsiteCtrl.text = p.value ?? '';
              break;
            case 'address':
              if (_contactAddressCtrl.text.isEmpty) _contactAddressCtrl.text = p.value ?? '';
              break;
            case 'notes':
              if (_contactNotesCtrl.text.isEmpty) _contactNotesCtrl.text = p.value ?? '';
              break;
            case 'birthday':
              if (_contactBirthday == null && p.value != null) {
                _contactBirthday = DateTime.tryParse(p.value!);
              }
              break;
          }
        }
      }
    }

    setState(() {});
  }


  /// Αποθηκεύει τα δεδομένα στη DB χωρίς validation και χωρίς navigation.
  /// Χρησιμοποιείται από _save() και _onPopInvoked() (auto-save on back).
  Future<void> _saveData() async {
    final itemNotifier = ref.read(itemNotifierProvider.notifier);
    final propertyNotifier = ref.read(propertyNotifierProvider(widget.itemId).notifier);

    await itemNotifier.updateItem(
      widget.itemId,
      title: _titleCtrl.text.trim(),
      favorite: _isFavorite,
    );

    await Future.wait([
      propertyNotifier.setText(
        'date', _selectedDate?.toIso8601String(),
      ),
      propertyNotifier.setText(
        'time',
        _selectedTime != null
            ? '${_selectedTime!.hour}:${_selectedTime!.minute}'
            : null,
      ),
      propertyNotifier.setText(
        'location',
        _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      ),
      propertyNotifier.setText(
        'notes',
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      ),
      propertyNotifier.setText(
        'contact_name',
        _contactNameCtrl.text.trim().isEmpty ? null : _contactNameCtrl.text.trim(),
      ),
      propertyNotifier.setText(
        'contact_phone',
        _contactPhoneCtrl.text.trim().isEmpty ? null : _contactPhoneCtrl.text.trim(),
      ),
      propertyNotifier.setText(
        'contact_email',
        _contactEmailCtrl.text.trim().isEmpty ? null : _contactEmailCtrl.text.trim(),
      ),
      propertyNotifier.setText(
        'contact_company',
        _contactCompanyCtrl.text.trim().isEmpty ? null : _contactCompanyCtrl.text.trim(),
      ),
      propertyNotifier.setText(
        'contact_website',
        _contactWebsiteCtrl.text.trim().isEmpty ? null : _contactWebsiteCtrl.text.trim(),
      ),
      propertyNotifier.setText(
        'contact_address',
        _contactAddressCtrl.text.trim().isEmpty ? null : _contactAddressCtrl.text.trim(),
      ),
      propertyNotifier.setText(
        'contact_notes',
        _contactNotesCtrl.text.trim().isEmpty ? null : _contactNotesCtrl.text.trim(),
      ),
      propertyNotifier.setText(
        'contact_birthday',
        _contactBirthday?.toIso8601String(),
      ),
    ]);

    // Contact linking logic
    final hasContactData = _contactNameCtrl.text.trim().isNotEmpty ||
        _contactPhoneCtrl.text.trim().isNotEmpty ||
        _contactEmailCtrl.text.trim().isNotEmpty ||
        _contactCompanyCtrl.text.trim().isNotEmpty ||
        _contactWebsiteCtrl.text.trim().isNotEmpty ||
        _contactAddressCtrl.text.trim().isNotEmpty ||
        _contactNotesCtrl.text.trim().isNotEmpty ||
        _contactBirthday != null;

    if (hasContactData) {
      final workspaceId = ref.read(activeWorkspaceIdProvider);
      if (workspaceId == null) return;

      if (_linkedContactId == null) {
        final shouldCreate = await _askCreateContact();
        if (!mounted) return;
        if (shouldCreate) {
          final newContact = await itemNotifier.create(
            type: ItemType.contact,
            title: _contactNameCtrl.text.trim(),
            folderId: null,
          );
          if (!mounted) return;
          if (newContact != null) {
            _linkedContactId = newContact.id;
            final contactPropNotifier =
            ref.read(propertyNotifierProvider(newContact.id).notifier);
            await Future.wait([
              contactPropNotifier.setText('name', _contactNameCtrl.text.trim().isEmpty ? null : _contactNameCtrl.text.trim()),
              contactPropNotifier.setText('phone', _contactPhoneCtrl.text.trim().isEmpty ? null : _contactPhoneCtrl.text.trim()),
              contactPropNotifier.setText('email', _contactEmailCtrl.text.trim().isEmpty ? null : _contactEmailCtrl.text.trim()),
              contactPropNotifier.setText('company', _contactCompanyCtrl.text.trim().isEmpty ? null : _contactCompanyCtrl.text.trim()),
              contactPropNotifier.setText('website', _contactWebsiteCtrl.text.trim().isEmpty ? null : _contactWebsiteCtrl.text.trim()),
              contactPropNotifier.setText('address', _contactAddressCtrl.text.trim().isEmpty ? null : _contactAddressCtrl.text.trim()),
              contactPropNotifier.setText('notes', _contactNotesCtrl.text.trim().isEmpty ? null : _contactNotesCtrl.text.trim()),
              if (_contactBirthday != null)
                contactPropNotifier.setDate('birthday', _contactBirthday!),
            ]);
            if (!mounted) return;
            await SuperNoteHelper.instance.relations.create(
              fromItemId: widget.itemId,
              toItemId: newContact.id,
              type: RelationType.references,
            );
          }
        }
      } else {
        final contactPropNotifier =
        ref.read(propertyNotifierProvider(_linkedContactId!).notifier);
        final currentContact =
        await ref.read(itemByIdProvider(_linkedContactId!).future);
        if (!mounted) return;
        if (currentContact != null &&
            currentContact.title != _contactNameCtrl.text.trim()) {
          await itemNotifier.updateItem(
            _linkedContactId!,
            title: _contactNameCtrl.text.trim().isEmpty
                ? null
                : _contactNameCtrl.text.trim(),
          );
        }
        await Future.wait([
          contactPropNotifier.setText('name', _contactNameCtrl.text.trim().isEmpty ? null : _contactNameCtrl.text.trim()),
          contactPropNotifier.setText('phone', _contactPhoneCtrl.text.trim().isEmpty ? null : _contactPhoneCtrl.text.trim()),
          contactPropNotifier.setText('email', _contactEmailCtrl.text.trim().isEmpty ? null : _contactEmailCtrl.text.trim()),
          contactPropNotifier.setText('company', _contactCompanyCtrl.text.trim().isEmpty ? null : _contactCompanyCtrl.text.trim()),
          contactPropNotifier.setText('website', _contactWebsiteCtrl.text.trim().isEmpty ? null : _contactWebsiteCtrl.text.trim()),
          contactPropNotifier.setText('address', _contactAddressCtrl.text.trim().isEmpty ? null : _contactAddressCtrl.text.trim()),
          contactPropNotifier.setText('notes', _contactNotesCtrl.text.trim().isEmpty ? null : _contactNotesCtrl.text.trim()),
          if (_contactBirthday != null)
            contactPropNotifier.setDate('birthday', _contactBirthday!)
          else
            contactPropNotifier.remove('birthday'),
        ]);
      }
    } else {
      if (_linkedContactId != null) {
        final existing =
        await SuperNoteHelper.instance.relations.getFrom(widget.itemId);
        if (!mounted) return;
        for (final r in existing) {
          if (r.toItemId == _linkedContactId &&
              r.relationType == RelationType.references) {
            await SuperNoteHelper.instance.relations.delete(r.id);
          }
        }
        _linkedContactId = null;
      }
    }
  }
  Future<void> _save() async {
    // Validation μόνο εδώ (όχι στο _saveData)
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Παρακαλώ προσθέστε τίτλο')),
      );
      return; // ← μένει στην οθόνη, δεν κλείνει
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Επιλέξτε ημερομηνία')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);

    try {
      await _saveData();
      if (mounted) {
        setState(() => _isSaving = false);
        navigator.pop();
      }
    } catch (e) {
      DebugConfig.error('AppointmentDetailScreen._save', e);
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Σφάλμα αποθήκευσης: ${e.toString()}')),
        );
      }
    }
  }

  Future<bool> _askCreateContact() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Δημιουργία επαφής'),
        content: const Text('Θέλετε να δημιουργήσετε νέα επαφή με τα στοιχεία που συμπληρώσατε;'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Όχι')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Ναι')),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showContactPicker() async {
    final selected = await showModalBottomSheet<Item>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(AppRadius.bottomSheet), topRight: Radius.circular(AppRadius.bottomSheet)),
      ),
      builder: (ctx) => const _ContactSearchSheet(),
    );
    if (selected != null) {
      await _loadContactFromItem(selected);
      if (!mounted) return;
      final existing = await SuperNoteHelper.instance.relations.getFrom(widget.itemId);
      for (final r in existing) {
        if (r.relationType == RelationType.references) {
          await SuperNoteHelper.instance.relations.delete(r.id);
        }
      }
      await SuperNoteHelper.instance.relations.create(
        fromItemId: widget.itemId,
        toItemId: selected.id,
        type: RelationType.references,
      );
      _linkedContactId = selected.id;
    }
  }

  Future<void> _loadContactFromItem(Item contact) async {
    final props = await ref.read(itemPropertiesProvider(contact.id).future);
    if (!mounted) return;
    _contactNameCtrl.text = contact.title ?? '';
    for (final p in props) {
      switch (p.key) {
        case 'phone': _contactPhoneCtrl.text = p.value ?? ''; break;
        case 'email': _contactEmailCtrl.text = p.value ?? ''; break;
        case 'company': _contactCompanyCtrl.text = p.value ?? ''; break;
        case 'website': _contactWebsiteCtrl.text = p.value ?? ''; break;
        case 'address': _contactAddressCtrl.text = p.value ?? ''; break;
        case 'notes': _contactNotesCtrl.text = p.value ?? ''; break;
        case 'birthday': if (p.value != null) _contactBirthday = DateTime.tryParse(p.value!); break;
      }
    }
    setState(() {});
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final init = _contactBirthday ?? DateTime(1990, 1, 1);
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('el', 'GR'),
      initialDate: init,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _contactBirthday = picked);
  }

  Future<void> _clearBirthday() async => setState(() => _contactBirthday = null);

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('el', 'GR'),
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _onTitleChanged(String value) => _isEditingTitle = true;

  Future<bool> _onPopInvoked() async {
    if (_isSaving) return false;

    if (_titleCtrl.text.trim().isEmpty) {
      if (widget.isNew) {
        DebugConfig.db('AppointmentDetail delete empty appointment id=${widget.itemId}');
        await ref.read(itemNotifierProvider.notifier).deleteItem(widget.itemId);
      }
      return true;
    }

    // ✅ Κλειδώνει το save button κατά το auto-save
    if (mounted) setState(() => _isSaving = true);
    try {
      await _saveData();
    } catch (e) {
      DebugConfig.error('AppointmentDetailScreen auto-save on pop', e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
    return true;
  }
  Future<void> _togglePin(Item item) async {
    await ref.read(itemNotifierProvider.notifier).togglePin(item.id, item.pinned);
  }

  Future<void> _archive(Item item) async {
    final ok = await ConfirmDialog.archive(context);
    if (!ok || !mounted) return;
    await ref.read(itemNotifierProvider.notifier).toggleArchive(item.id, item.archived);
    if (mounted) Navigator.of(context).pop();
  }
  Future<void> _delete(Item item) async {
    final ok = await ConfirmDialog.delete(context, title: 'Διαγραφή ραντεβού;');
    if (!ok || !mounted) return;
    await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
    if (mounted) Navigator.pop(context);
  }

  // --- Υπολογισμός startDateTime για τις υπενθυμίσεις ---
  DateTime? _getStartDateTime() {
    if (_selectedDate != null) {
      return DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime?.hour ?? 0,
        _selectedTime?.minute ?? 0,
      );
    }
    return null;
  }

  // --- Εμφάνιση bottom sheet με το ReminderSection (κανονικό, όχι full screen) ---
  Future<void> _showReminderDialog() async {
    final startDateTime = _getStartDateTime();
    final title = _titleCtrl.text.trim().isEmpty ? 'Ραντεβού' : _titleCtrl.text.trim();
    await showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(AppRadius.bottomSheet), topRight: Radius.circular(AppRadius.bottomSheet)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: ReminderSection(
          itemId: widget.itemId,
          itemTitle: title,
          defaultStartTime: startDateTime,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(itemStreamProvider(widget.itemId));

    return itemAsync.when(
      loading: () => _buildLoading(),
      error: (e, _) => _buildError(),
      data: (item) {
        if (item == null) return _buildNotFound();

        if (
        !_isEditingTitle &&
            !_isSaving &&
            _titleCtrl.text != item.title
        ) {
          _titleCtrl.text = item.title ?? '';
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final canPop = await _onPopInvoked();
            if (context.mounted && canPop) Navigator.of(context).pop();
          },
          child: Scaffold(
            backgroundColor: context.cBg,
            appBar: _buildAppBar(item),
            body: _buildBody(),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(Item item) {
    return AppBar(
      backgroundColor: context.cBg,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: _isSaving
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : null,
      actions: [
        // 1. Save
        IconButton(
          icon: Icon(Icons.save_rounded, color: context.cPrimary),
          onPressed: _isSaving ? null : _save,
          tooltip: 'Αποθήκευση',
        ),
        // 2. Reminder (καμπάνα)
        IconButton(
          icon: Icon(Icons.notifications_none_rounded, color: context.cText2),
          onPressed: _showReminderDialog,
          tooltip: 'Υπενθύμιση',
        ),
        // 3. Pin
        IconButton(
          icon: Icon(item.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: item.pinned ? context.cPrimary : context.cText2),
          onPressed: () => _togglePin(item),
          tooltip: item.pinned ? 'Αποκαρφίτσωμα' : 'Καρφίτσωμα',
        ),
        // 4. Favorite
        IconButton(
          icon: Icon(_isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: _isFavorite ? ColorsUI.getWarning(context.brightness) : context.cText2),
          onPressed: () => setState(() => _isFavorite = !_isFavorite),
          tooltip: _isFavorite ? 'Αφαίρεση αγαπημένου' : 'Αγαπημένο',
        ),
        // 5. Archive
        IconButton(
          icon: Icon(item.archived ? Icons.unarchive_rounded : Icons.archive_rounded, color: context.cText2),
          onPressed: () => _archive(item),
          tooltip: item.archived ? 'Επαναφορά' : 'Αρχειοθέτηση',
        ),
        // 6. Delete
        IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: context.cError),
          onPressed: () => _delete(item),
          tooltip: 'Διαγραφή',
        ),
      ],
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title field
          TextField(
            controller: _titleCtrl,
            focusNode: _titleFocusNode,
            onChanged: _onTitleChanged,
            style: context.h2.copyWith(fontWeight: FontWeight.w600),
            maxLines: null,
            decoration: InputDecoration(
              hintText: 'Τίτλος...',
              hintStyle: context.h2.withColor(context.cDisabled),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: Spacing.md),

          // Date & time
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(_selectedDate != null ? DateFormat('dd/MM/yyyy').format(_selectedDate!) : 'Επιλογή ημερομηνίας'),
              ),
              OutlinedButton.icon(
                onPressed: _selectTime,
                icon: const Icon(Icons.access_time),
                label: Text(_selectedTime != null ? _selectedTime!.format(context) : 'Επιλογή ώρας'),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),

          // Contact picker button
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Στοιχεία επαφής', style: context.titleSm),
              TextButton.icon(
                onPressed: _showContactPicker,
                icon: const Icon(Icons.contact_page_rounded, size: 18),
                label: const Text('Αναζήτηση επαφής'),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),

          // Expandable contact fields
          Card(
            child: ExpansionTile(
              initiallyExpanded: _contactSectionExpanded,
              onExpansionChanged: (expanded) => setState(() => _contactSectionExpanded = expanded),
              title: const Text('Στοιχεία επαφής', style: TextStyle(fontWeight: FontWeight.w500)),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.xs),
                  child: Column(
                    children: [
                      TextField(controller: _contactNameCtrl, decoration: const InputDecoration(labelText: 'Όνομα επαφής')),
                      const SizedBox(height: Spacing.sm),
                      TextField(controller: _contactPhoneCtrl, decoration: const InputDecoration(labelText: 'Τηλέφωνο'), keyboardType: TextInputType.phone),
                      const SizedBox(height: Spacing.sm),
                      TextField(controller: _contactEmailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: Spacing.sm),
                      TextField(controller: _contactCompanyCtrl, decoration: const InputDecoration(labelText: 'Εταιρεία')),
                      const SizedBox(height: Spacing.sm),
                      TextField(controller: _contactWebsiteCtrl, decoration: const InputDecoration(labelText: 'Website'), keyboardType: TextInputType.url),
                      const SizedBox(height: Spacing.sm),
                      TextField(controller: _contactAddressCtrl, decoration: const InputDecoration(labelText: 'Διεύθυνση'), maxLines: 2),
                      const SizedBox(height: Spacing.sm),
                      _BirthdayField(birthday: _contactBirthday, onPick: _pickBirthday, onClear: _clearBirthday),
                      const SizedBox(height: Spacing.sm),
                      TextField(controller: _contactNotesCtrl, decoration: const InputDecoration(labelText: 'Σημειώσεις επαφής'), maxLines: 3),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),

          // Location field
          TextField(
            controller: _locationCtrl,
            decoration: const InputDecoration(
              labelText: 'Τοποθεσία',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on),
            ),
          ),
          const SizedBox(height: Spacing.md),

          // Notes (appointment)
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Σημειώσεις ραντεβού',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 5,
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(),
    body: const Center(child: CircularProgressIndicator()),
  );

  Widget _buildError() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(),
    body: EmptyState.error(onRetry: () => ref.invalidate(itemStreamProvider(widget.itemId))),
  );

  Widget _buildNotFound() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(),
    body: const EmptyState(icon: Icons.event_busy_rounded, title: 'Το ραντεβού δεν βρέθηκε'),
  );

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _contactEmailCtrl.dispose();
    _titleFocusNode.dispose();
    _contactCompanyCtrl.dispose();
    _contactWebsiteCtrl.dispose();
    _contactAddressCtrl.dispose();
    _contactNotesCtrl.dispose();
    super.dispose();
  }
}

// --- Birthday Field ---
class _BirthdayField extends StatelessWidget {
  final DateTime? birthday;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _BirthdayField({required this.birthday, required this.onPick, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final label = birthday != null ? DateFormat.yMMMMd('el_GR').format(birthday!) : 'Επιλογή ημερομηνίας';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs + 2),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Spacing.md,
        runSpacing: 6,
        children: [
          Icon(Icons.cake_rounded, size: 18, color: context.cText2),
          GestureDetector(
            onTap: onPick,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm + 4),
              decoration: BoxDecoration(
                color: ColorsUI.getSurface(context.brightness),
                borderRadius: AppRadius.inputBR,
                border: Border.all(color: ColorsUI.getBorder(context.brightness)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Γενέθλια', style: context.bodySm.withColor(context.cText2)),
                        const SizedBox(height: 2),
                        Text(label, style: context.bodyMd.withColor(birthday != null ? context.cText : context.cDisabled)),
                      ],
                    ),
                  ),
                  if (birthday != null)
                    GestureDetector(
                      onTap: onClear,
                      child: Icon(Icons.close_rounded, size: 16, color: context.cText2),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Contact Search Sheet ---
class _ContactSearchSheet extends ConsumerStatefulWidget {
  const _ContactSearchSheet();

  @override
  ConsumerState<_ContactSearchSheet> createState() => _ContactSearchSheetState();
}

class _ContactSearchSheetState extends ConsumerState<_ContactSearchSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(itemsStreamProvider).whenData(
          (items) => items.where((i) => i.type == ItemType.contact).toList(),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: Spacing.sm),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: context.cBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (val) => setState(() => _query = val.toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Αναζήτηση επαφής...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(borderRadius: AppRadius.inputBR, borderSide: BorderSide.none),
                  filled: true,
                  fillColor: ColorsUI.getSurface(context.brightness),
                ),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Expanded(
              child: contactsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => EmptyState.error(),
                data: (contacts) {
                  final filtered = contacts.where((c) => c.title?.toLowerCase().contains(_query) ?? false).toList();
                  if (filtered.isEmpty) return EmptyState.search(query: _query);
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final contact = filtered[i];
                      return ListTile(
                        leading: const Icon(Icons.person_rounded),
                        title: Text(contact.title ?? 'Χωρίς όνομα'),
                        subtitle: _ContactPreview(contactId: contact.id),
                        onTap: () => Navigator.pop(context, contact),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// --- Contact Preview Widget ---
class _ContactPreview extends ConsumerWidget {
  final int contactId;
  const _ContactPreview({required this.contactId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propsAsync = ref.watch(itemPropertiesProvider(contactId));
    return propsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (props) {
        final phone = props.where((p) => p.key == 'phone').firstOrNull?.value;
        if (phone != null && phone.isNotEmpty) {
          return Text(phone, style: TextStyle(fontSize: 12, color: context.cText2));
        }
        final email = props.where((p) => p.key == 'email').firstOrNull?.value;
        if (email != null && email.isNotEmpty) {
          return Text(email, style: TextStyle(fontSize: 12, color: context.cText2));
        }
        return const SizedBox.shrink();
      },
    );
  }
}