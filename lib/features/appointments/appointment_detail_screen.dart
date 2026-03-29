// lib/features/appointments/appointment_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/core.dart';
import '../../helpers/super_note_helper.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../services/habit_service.dart';
import '../../services/reminder_scheduler.dart';
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
  ConsumerState<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends ConsumerState<AppointmentDetailScreen> {
  // --- Basic fields ---
  late TextEditingController _titleCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _notesCtrl;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _reminderEnabled = false;
  RecurrenceType _recurrenceType = RecurrenceType.daily;
  int _recurrenceInterval = 1;
  List<int>? _weeklyDays;
  int? _monthlyDay;
  bool _isFavorite = false;
  bool _isSaving = false;
  bool _isEditingTitle = false;

  // --- Contact fields (identical to contact detail) ---
  late TextEditingController _contactNameCtrl;
  late TextEditingController _contactPhoneCtrl;
  late TextEditingController _contactEmailCtrl;
  late TextEditingController _contactCompanyCtrl;
  late TextEditingController _contactWebsiteCtrl;
  late TextEditingController _contactAddressCtrl;
  late TextEditingController _contactNotesCtrl;
  DateTime? _contactBirthday;

  bool _contactSectionExpanded = false;
  int? _linkedContactId; // ID της συνδεδεμένης επαφής

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
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
        case 'reminder_enabled':
          _reminderEnabled = p.value == 'true';
          break;
        case 'recurrence_type':
          _recurrenceType = RecurrenceType.values.firstWhere(
                (e) => e.name == p.value,
            orElse: () => RecurrenceType.daily,
          );
          break;
        case 'recurrence_interval':
          _recurrenceInterval = int.tryParse(p.value ?? '1') ?? 1;
          break;
        case 'recurrence_weekly_days':
          if (p.value != null && p.value!.isNotEmpty) {
            _weeklyDays = p.value!.split(',').map(int.parse).toList();
          }
          break;
        case 'recurrence_monthly_day':
          _monthlyDay = int.tryParse(p.value ?? '');
          break;
      // Contact fields (snapshot)
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

    // Φόρτωση συνδεδεμένης επαφής (αν υπάρχει)
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
        // Φόρτωση των properties της επαφής για να γεμίσουμε τα πεδία (αν τα snapshot είναι κενά)
        final contactProps = await ref.read(itemPropertiesProvider(contactId).future);
        if (_contactNameCtrl.text.isEmpty) _contactNameCtrl.text = contact.title ?? '';
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

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Παρακαλώ εισάγετε τίτλο')),
      );
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Επιλέξτε ημερομηνία')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final itemNotifier = ref.read(itemNotifierProvider.notifier);
    final propertyNotifier = ref.read(propertyNotifierProvider(widget.itemId).notifier);
    final navigator = Navigator.of(context); // capture before async

    // Update title and favorite
    await itemNotifier.updateItem(
      widget.itemId,
      title: _titleCtrl.text.trim(),
      favorite: _isFavorite,
    );

    // Save basic properties
    await propertyNotifier.setText('date', _selectedDate!.toIso8601String());
    await propertyNotifier.setText(
      'time',
      _selectedTime != null ? '${_selectedTime!.hour}:${_selectedTime!.minute}' : null,
    );
    await propertyNotifier.setText('location', _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim());
    await propertyNotifier.setText('notes', _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim());
    await propertyNotifier.setText('reminder_enabled', _reminderEnabled ? 'true' : 'false');
    await propertyNotifier.setText('recurrence_type', _recurrenceType.name);
    await propertyNotifier.setText('recurrence_interval', _recurrenceInterval.toString());
    await propertyNotifier.setText('recurrence_weekly_days', _weeklyDays?.join(','));
    await propertyNotifier.setText('recurrence_monthly_day', _monthlyDay?.toString());

    // Save contact fields to appointment (snapshot)
    await propertyNotifier.setText('contact_name', _contactNameCtrl.text.trim().isEmpty ? null : _contactNameCtrl.text.trim());
    await propertyNotifier.setText('contact_phone', _contactPhoneCtrl.text.trim().isEmpty ? null : _contactPhoneCtrl.text.trim());
    await propertyNotifier.setText('contact_email', _contactEmailCtrl.text.trim().isEmpty ? null : _contactEmailCtrl.text.trim());
    await propertyNotifier.setText('contact_company', _contactCompanyCtrl.text.trim().isEmpty ? null : _contactCompanyCtrl.text.trim());
    await propertyNotifier.setText('contact_website', _contactWebsiteCtrl.text.trim().isEmpty ? null : _contactWebsiteCtrl.text.trim());
    await propertyNotifier.setText('contact_address', _contactAddressCtrl.text.trim().isEmpty ? null : _contactAddressCtrl.text.trim());
    await propertyNotifier.setText('contact_notes', _contactNotesCtrl.text.trim().isEmpty ? null : _contactNotesCtrl.text.trim());
    if (_contactBirthday != null) {
      await propertyNotifier.setText('contact_birthday', _contactBirthday!.toIso8601String());
    } else {
      await propertyNotifier.setText('contact_birthday', null);
    }

    // --- Διαχείριση επαφής ---
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
        // Δεν υπάρχει συνδεδεμένη επαφή – ρωτάμε τον χρήστη αν θέλει να δημιουργηθεί
        final shouldCreate = await _askCreateContact();
        if (!mounted) return;
        if (shouldCreate) {
          // Δημιουργία νέας επαφής
          final newContact = await itemNotifier.create(
            type: ItemType.contact,
            title: _contactNameCtrl.text.trim(),
            folderId: null,
          );
          if (newContact != null) {
            _linkedContactId = newContact.id;
            final contactPropNotifier = ref.read(propertyNotifierProvider(newContact.id).notifier);
            await contactPropNotifier.setText('name', _contactNameCtrl.text.trim().isEmpty ? null : _contactNameCtrl.text.trim());
            await contactPropNotifier.setText('phone', _contactPhoneCtrl.text.trim().isEmpty ? null : _contactPhoneCtrl.text.trim());
            await contactPropNotifier.setText('email', _contactEmailCtrl.text.trim().isEmpty ? null : _contactEmailCtrl.text.trim());
            await contactPropNotifier.setText('company', _contactCompanyCtrl.text.trim().isEmpty ? null : _contactCompanyCtrl.text.trim());
            await contactPropNotifier.setText('website', _contactWebsiteCtrl.text.trim().isEmpty ? null : _contactWebsiteCtrl.text.trim());
            await contactPropNotifier.setText('address', _contactAddressCtrl.text.trim().isEmpty ? null : _contactAddressCtrl.text.trim());
            await contactPropNotifier.setText('notes', _contactNotesCtrl.text.trim().isEmpty ? null : _contactNotesCtrl.text.trim());
            if (_contactBirthday != null) {
              await contactPropNotifier.setDate('birthday', _contactBirthday!);
            }
            // Δημιουργία σχέσης
            await SuperNoteHelper.instance.relations.create(
              fromItemId: widget.itemId,
              toItemId: newContact.id,
              type: RelationType.references,
            );
          }
        } // else: δεν δημιουργείται επαφή – τα snapshot παραμένουν στο ραντεβού
      } else {
        // Υπάρχει συνδεδεμένη επαφή – ενημέρωσέ την
        final contactPropNotifier = ref.read(propertyNotifierProvider(_linkedContactId!).notifier);
        final currentContact = await ref.read(itemByIdProvider(_linkedContactId!).future);
        if (currentContact != null && currentContact.title != _contactNameCtrl.text.trim()) {
          await itemNotifier.updateItem(_linkedContactId!, title: _contactNameCtrl.text.trim().isEmpty ? null : _contactNameCtrl.text.trim());
        }
        await contactPropNotifier.setText('name', _contactNameCtrl.text.trim().isEmpty ? null : _contactNameCtrl.text.trim());
        await contactPropNotifier.setText('phone', _contactPhoneCtrl.text.trim().isEmpty ? null : _contactPhoneCtrl.text.trim());
        await contactPropNotifier.setText('email', _contactEmailCtrl.text.trim().isEmpty ? null : _contactEmailCtrl.text.trim());
        await contactPropNotifier.setText('company', _contactCompanyCtrl.text.trim().isEmpty ? null : _contactCompanyCtrl.text.trim());
        await contactPropNotifier.setText('website', _contactWebsiteCtrl.text.trim().isEmpty ? null : _contactWebsiteCtrl.text.trim());
        await contactPropNotifier.setText('address', _contactAddressCtrl.text.trim().isEmpty ? null : _contactAddressCtrl.text.trim());
        await contactPropNotifier.setText('notes', _contactNotesCtrl.text.trim().isEmpty ? null : _contactNotesCtrl.text.trim());
        if (_contactBirthday != null) {
          await contactPropNotifier.setDate('birthday', _contactBirthday!);
        } else {
          await contactPropNotifier.remove('birthday');
        }
      }
    } else {
      // Δεν υπάρχουν στοιχεία επαφής – αν υπήρχε σύνδεση, την αφαιρούμε
      if (_linkedContactId != null) {
        final existing = await SuperNoteHelper.instance.relations.getFrom(widget.itemId);
        for (final r in existing) {
          if (r.toItemId == _linkedContactId && r.relationType == RelationType.references) {
            await SuperNoteHelper.instance.relations.delete(r.id);
          }
        }
        _linkedContactId = null;
      }
    }

    // Handle reminders
    if (_reminderEnabled && _selectedDate != null) {
      final reminderTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime?.hour ?? 0,
        _selectedTime?.minute ?? 0,
      );
      await _scheduleReminders(reminderTime);
    } else {
      await ReminderScheduler.instance.cancelAllForItem(widget.itemId);
      final existing = await SuperNoteHelper.instance.reminders.getForItem(widget.itemId);
      for (final r in existing) {
        await SuperNoteHelper.instance.reminders.delete(r.id);
      }
    }

    setState(() => _isSaving = false);
    if (mounted) {
      navigator.pop();
    }
  }

  Future<bool> _askCreateContact() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Δημιουργία επαφής'),
        content: const Text('Θέλετε να δημιουργήσετε νέα επαφή με τα στοιχεία που συμπληρώσατε;'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Όχι'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Ναι'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // --- Contact picker ---
  Future<void> _showContactPicker() async {
    final selected = await showModalBottomSheet<Item>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ColorsUI.getSurface(context.brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.bottomSheet),
          topRight: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
      builder: (ctx) => const _ContactSearchSheet(),
    );
    if (selected != null) {
      await _loadContactFromItem(selected);
      if (!mounted) return;
      // Ενημέρωση της σύνδεσης: διαγραφή παλιάς, προσθήκη νέας
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
        case 'phone':
          _contactPhoneCtrl.text = p.value ?? '';
          break;
        case 'email':
          _contactEmailCtrl.text = p.value ?? '';
          break;
        case 'company':
          _contactCompanyCtrl.text = p.value ?? '';
          break;
        case 'website':
          _contactWebsiteCtrl.text = p.value ?? '';
          break;
        case 'address':
          _contactAddressCtrl.text = p.value ?? '';
          break;
        case 'notes':
          _contactNotesCtrl.text = p.value ?? '';
          break;
        case 'birthday':
          if (p.value != null) _contactBirthday = DateTime.tryParse(p.value!);
          break;
      }
    }
    setState(() {});
  }

  // --- Birthday picker ---
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
    if (picked != null) {
      setState(() => _contactBirthday = picked);
    }
  }

  Future<void> _clearBirthday() async {
    setState(() => _contactBirthday = null);
  }

  // --- Reminder methods (unchanged) ---
  Future<void> _scheduleReminders(DateTime firstTime) async {
    await ReminderScheduler.instance.cancelAllForItem(widget.itemId);
    final existing = await SuperNoteHelper.instance.reminders.getForItem(widget.itemId);
    for (final r in existing) {
      await SuperNoteHelper.instance.reminders.delete(r.id);
    }

    final recurrence = Recurrence(
      type: _recurrenceType,
      interval: _recurrenceInterval,
      days: _weeklyDays,
      dayOfMonth: _monthlyDay,
    );
    final dates = _generateRecurringDates(firstTime, recurrence);
    for (final date in dates) {
      final reminder = await SuperNoteHelper.instance.reminders.create(
        itemId: widget.itemId,
        triggerAt: date,
        rrule: '',
        title: 'Υπενθύμιση ραντεβού',
        body: _titleCtrl.text,
      );
      await ReminderScheduler.instance.scheduleReminder(reminder);
    }
  }

  List<DateTime> _generateRecurringDates(DateTime start, Recurrence recurrence) {
    final dates = <DateTime>[];
    final end = DateTime.now().add(const Duration(days: 60));
    DateTime current = start;
    int count = 0;
    const maxReminders = 40;
    while (current.isBefore(end) && count < maxReminders) {
      dates.add(current);
      current = _nextDate(current, recurrence);
      count++;
    }
    return dates;
  }

  DateTime _nextDate(DateTime current, Recurrence recurrence) {
    switch (recurrence.type) {
      case RecurrenceType.daily:
        return current.add(Duration(days: recurrence.interval));
      case RecurrenceType.weekly:
        DateTime next = current.add(Duration(days: 7 * recurrence.interval));
        if (recurrence.days != null && recurrence.days!.isNotEmpty) {
          int daysAdded = 0;
          while (!recurrence.days!.contains(next.weekday) && daysAdded < 7) {
            next = next.add(const Duration(days: 1));
            daysAdded++;
          }
        }
        return next;
      case RecurrenceType.monthly:
        int nextMonth = current.month + recurrence.interval;
        int year = current.year + ((nextMonth - 1) ~/ 12);
        int month = ((nextMonth - 1) % 12) + 1;
        int day = recurrence.dayOfMonth ?? current.day;
        final daysInMonth = DateTime(year, month + 1, 0).day;
        day = day.clamp(1, daysInMonth);
        return DateTime(year, month, day, current.hour, current.minute);
      case RecurrenceType.custom:
        return current.add(Duration(days: recurrence.interval));
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
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

  void _onTitleChanged(String value) {
    _isEditingTitle = true;
  }

  Future<bool> _onPopInvoked() async {
    if (widget.isNew && _titleCtrl.text.trim().isEmpty && !_isSaving) {
      await ref.read(itemNotifierProvider.notifier).deleteItem(widget.itemId);
    }
    return true;
  }

  // --- Actions ---
  Future<void> _togglePin(Item item) async {
    await ref.read(itemNotifierProvider.notifier).togglePin(item.id, item.pinned);
    if (!mounted) return;
    ref.invalidate(itemStreamProvider(widget.itemId));
  }

  Future<void> _archive(Item item) async {
    final ok = await ConfirmDialog.archive(context);
    if (!ok || !mounted) return;
    await ref.read(itemNotifierProvider.notifier).toggleArchive(item.id, item.archived);
    if (!mounted) return;
    ref.invalidate(itemStreamProvider(widget.itemId));
  }

  Future<void> _delete(Item item) async {
    final ok = await ConfirmDialog.delete(context, title: 'Διαγραφή ραντεβού;');
    if (!ok || !mounted) return;
    await ref.read(itemNotifierProvider.notifier).deleteItem(item.id);
    if (mounted) Navigator.pop(context);
  }

  // --- Build UI ---
  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(itemStreamProvider(widget.itemId));

    return itemAsync.when(
      loading: () => _buildLoading(),
      error: (e, _) => _buildError(),
      data: (item) {
        if (item == null) return _buildNotFound();

        if (!_isEditingTitle && _titleCtrl.text != item.title) {
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
          ? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.cText2,
            ),
          ),
          const SizedBox(width: Spacing.xs),
          Text('Αποθήκευση...', style: context.bodySm.withColor(context.cText2)),
        ],
      )
          : null,
      actions: [
        IconButton(
          icon: Icon(Icons.save_rounded, color: context.cPrimary),
          onPressed: _save,
          tooltip: 'Αποθήκευση',
        ),
        IconButton(
          icon: Icon(
            _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
            color: _isFavorite ? ColorsUI.getWarning(context.brightness) : context.cText2,
          ),
          onPressed: () => setState(() => _isFavorite = !_isFavorite),
          tooltip: _isFavorite ? 'Αφαίρεση αγαπημένου' : 'Αγαπημένο',
        ),
        IconButton(
          icon: Icon(
            item.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            color: item.pinned ? context.cPrimary : context.cText2,
          ),
          onPressed: () => _togglePin(item),
          tooltip: item.pinned ? 'Αποκαρφίτσωμα' : 'Καρφίτσωμα',
        ),
        IconButton(
          icon: Icon(
            item.archived ? Icons.unarchive_rounded : Icons.archive_rounded,
            color: context.cText2,
          ),
          onPressed: () => _archive(item),
          tooltip: item.archived ? 'Επαναφορά' : 'Αρχειοθέτηση',
        ),
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _selectedDate != null
                        ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                        : 'Επιλογή ημερομηνίας',
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectTime,
                  icon: const Icon(Icons.access_time),
                  label: Text(
                    _selectedTime != null ? _selectedTime!.format(context) : 'Επιλογή ώρας',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),

          // Contact picker button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      // Name
                      TextField(
                        controller: _contactNameCtrl,
                        decoration: const InputDecoration(labelText: 'Όνομα επαφής'),
                      ),
                      const SizedBox(height: Spacing.sm),
                      // Phone
                      TextField(
                        controller: _contactPhoneCtrl,
                        decoration: const InputDecoration(labelText: 'Τηλέφωνο'),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: Spacing.sm),
                      // Email
                      TextField(
                        controller: _contactEmailCtrl,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: Spacing.sm),
                      // Company
                      TextField(
                        controller: _contactCompanyCtrl,
                        decoration: const InputDecoration(labelText: 'Εταιρεία'),
                      ),
                      const SizedBox(height: Spacing.sm),
                      // Website
                      TextField(
                        controller: _contactWebsiteCtrl,
                        decoration: const InputDecoration(labelText: 'Website'),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: Spacing.sm),
                      // Address
                      TextField(
                        controller: _contactAddressCtrl,
                        decoration: const InputDecoration(labelText: 'Διεύθυνση'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: Spacing.sm),
                      // Birthday
                      _BirthdayField(
                        birthday: _contactBirthday,
                        onPick: _pickBirthday,
                        onClear: _clearBirthday,
                      ),
                      const SizedBox(height: Spacing.sm),
                      // Notes
                      TextField(
                        controller: _contactNotesCtrl,
                        decoration: const InputDecoration(labelText: 'Σημειώσεις επαφής'),
                        maxLines: 3,
                      ),
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

          // Reminder toggle
          SwitchListTile(
            title: const Text('Υπενθύμιση'),
            value: _reminderEnabled,
            onChanged: (val) => setState(() => _reminderEnabled = val),
          ),
          if (_reminderEnabled) ...[
            const SizedBox(height: Spacing.sm),
            _RecurrencePicker(
              recurrenceType: _recurrenceType,
              interval: _recurrenceInterval,
              weeklyDays: _weeklyDays,
              monthlyDay: _monthlyDay,
              onChanged: (type, interval, weeklyDays, monthlyDay) {
                setState(() {
                  _recurrenceType = type;
                  _recurrenceInterval = interval;
                  _weeklyDays = weeklyDays;
                  _monthlyDay = monthlyDay;
                });
              },
            ),
          ],
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

  // --- Fallbacks ---
  Widget _buildLoading() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(),
    body: const Center(child: CircularProgressIndicator()),
  );

  Widget _buildError() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(),
    body: EmptyState.error(
      onRetry: () => ref.invalidate(itemStreamProvider(widget.itemId)),
    ),
  );

  Widget _buildNotFound() => Scaffold(
    backgroundColor: context.cBg,
    appBar: AppBar(),
    body: const EmptyState(
      icon: Icons.event_busy_rounded,
      title: 'Το ραντεβού δεν βρέθηκε',
    ),
  );

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _contactEmailCtrl.dispose();
    _contactCompanyCtrl.dispose();
    _contactWebsiteCtrl.dispose();
    _contactAddressCtrl.dispose();
    _contactNotesCtrl.dispose();
    super.dispose();
  }
}

// --- _RecurrencePicker (unchanged) ---
class _RecurrencePicker extends StatefulWidget {
  final RecurrenceType recurrenceType;
  final int interval;
  final List<int>? weeklyDays;
  final int? monthlyDay;
  final void Function(RecurrenceType, int, List<int>?, int?) onChanged;

  const _RecurrencePicker({
    required this.recurrenceType,
    required this.interval,
    required this.weeklyDays,
    required this.monthlyDay,
    required this.onChanged,
  });

  @override
  State<_RecurrencePicker> createState() => _RecurrencePickerState();
}

class _RecurrencePickerState extends State<_RecurrencePicker> {
  late RecurrenceType _type;
  late int _interval;
  late List<int> _weeklyDays;
  late int? _monthlyDay;

  late TextEditingController _intervalController;
  late TextEditingController _monthlyDayController;

  final List<String> _weekdayLabels = ['Δευ', 'Τρι', 'Τετ', 'Πεμ', 'Παρ', 'Σαβ', 'Κυρ'];

  @override
  void initState() {
    super.initState();
    _type = widget.recurrenceType;
    _interval = widget.interval;
    _weeklyDays = widget.weeklyDays?.toList() ?? [];
    _monthlyDay = widget.monthlyDay;

    _intervalController = TextEditingController(text: _interval.toString());
    _monthlyDayController = TextEditingController(text: _monthlyDay?.toString() ?? '');

    _intervalController.addListener(_onIntervalChanged);
    _monthlyDayController.addListener(_onMonthlyDayChanged);
  }

  void _onIntervalChanged() {
    final val = int.tryParse(_intervalController.text);
    if (val != null && val > 0 && val != _interval) {
      _interval = val;
      _notifyChanged();
    }
  }

  void _onMonthlyDayChanged() {
    final val = int.tryParse(_monthlyDayController.text);
    if (val != null && val >= 1 && val <= 31 && val != _monthlyDay) {
      _monthlyDay = val;
      _notifyChanged();
    }
  }

  @override
  void didUpdateWidget(_RecurrencePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.interval != oldWidget.interval) {
      _interval = widget.interval;
      _intervalController.text = _interval.toString();
    }
    if (widget.monthlyDay != oldWidget.monthlyDay) {
      _monthlyDay = widget.monthlyDay;
      _monthlyDayController.text = _monthlyDay?.toString() ?? '';
    }
    if (widget.recurrenceType != oldWidget.recurrenceType) {
      _type = widget.recurrenceType;
    }
    if (widget.weeklyDays != oldWidget.weeklyDays) {
      _weeklyDays = widget.weeklyDays?.toList() ?? [];
    }
  }

  void _notifyChanged() {
    widget.onChanged(_type, _interval, _weeklyDays.isNotEmpty ? _weeklyDays : null, _monthlyDay);
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _monthlyDayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Επανάληψη', style: context.titleSm),
            const SizedBox(height: Spacing.sm),
            DropdownButtonFormField<RecurrenceType>(
              initialValue: _type,
              items: RecurrenceType.values.map((t) {
                String label;
                switch (t) {
                  case RecurrenceType.daily:
                    label = 'Καθημερινά';
                    break;
                  case RecurrenceType.weekly:
                    label = 'Εβδομαδιαία';
                    break;
                  case RecurrenceType.monthly:
                    label = 'Μηνιαία';
                    break;
                  case RecurrenceType.custom:
                    label = 'Προσαρμοσμένη';
                    break;
                }
                return DropdownMenuItem(value: t, child: Text(label));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _type = val;
                    if (val != RecurrenceType.weekly) _weeklyDays.clear();
                    if (val != RecurrenceType.monthly) _monthlyDay = null;
                  });
                  _notifyChanged();
                }
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            // Interval
            Row(
              children: [
                Text('Κάθε', style: context.bodyMd),
                const SizedBox(width: Spacing.sm),
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _intervalController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Text(_unitLabel(_type), style: context.bodyMd),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            // Weekly days selection
            if (_type == RecurrenceType.weekly)
              Wrap(
                spacing: 8,
                children: List.generate(7, (i) {
                  final dayIndex = i + 1;
                  final isSelected = _weeklyDays.contains(dayIndex);
                  return FilterChip(
                    label: Text(_weekdayLabels[i]),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _weeklyDays.add(dayIndex);
                        } else {
                          _weeklyDays.remove(dayIndex);
                        }
                      });
                      _notifyChanged();
                    },
                  );
                }),
              ),
            // Monthly day picker
            if (_type == RecurrenceType.monthly)
              Row(
                children: [
                  Text('Ημέρα του μήνα:', style: context.bodyMd),
                  const SizedBox(width: Spacing.sm),
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: _monthlyDayController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _unitLabel(RecurrenceType type) {
    switch (type) {
      case RecurrenceType.daily:
        return 'ημέρες';
      case RecurrenceType.weekly:
        return 'εβδομάδες';
      case RecurrenceType.monthly:
        return 'μήνες';
      case RecurrenceType.custom:
        return 'ημέρες';
    }
  }
}

// --- Birthday Field ---
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
                  horizontal: Spacing.md,
                  vertical: Spacing.sm + 4,
                ),
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
                          Text(
                            'Γενέθλια',
                            style: context.bodySm.withColor(context.cText2),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            style: context.bodyMd.withColor(
                              birthday != null ? context.cText : context.cDisabled,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (birthday != null)
                      GestureDetector(
                        onTap: onClear,
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: context.cText2,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Contact Search Sheet (unchanged, but uses the correct fields) ---
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: Spacing.sm),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.cBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
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
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.inputBR,
                    borderSide: BorderSide.none,
                  ),
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
                  final filtered = contacts.where((c) {
                    final name = c.title?.toLowerCase() ?? '';
                    return name.contains(_query);
                  }).toList();
                  if (filtered.isEmpty) {
                    return EmptyState.search(query: _query);
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final contact = filtered[i];
                      return ListTile(
                        leading: const Icon(Icons.person_rounded),
                        title: Text(contact.title ?? 'Χωρίς όνομα'),
                        subtitle: _getContactPreview(contact),
                        onTap: () => Navigator.pop(context, contact),
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _getContactPreview(Item contact) {
    final props = ref.read(itemPropertiesProvider(contact.id)).valueOrNull;
    if (props == null) return const SizedBox.shrink();
    final phone = props.where((p) => p.key == 'phone').firstOrNull?.value;
    if (phone != null && phone.isNotEmpty) {
      return Text(phone, style: TextStyle(fontSize: 12, color: context.cText2));
    }
    final email = props.where((p) => p.key == 'email').firstOrNull?.value;
    if (email != null && email.isNotEmpty) {
      return Text(email, style: TextStyle(fontSize: 12, color: context.cText2));
    }
    return const SizedBox.shrink();
  }
}