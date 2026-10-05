// lib/core/utils/contact_props.dart
//
// SPoT για contact properties. Ενοποιεί τα 4πλά _extractContactProps:
// contact_list, contact_detail, share_service, appointment_detail.

import 'dart:convert';
import '../../models/item_property.dart';
import 'debug_config.dart';
import 'string_utils.dart';

class ContactProps {
  final List<String> phones;
  final String? phoneFallback;
  final String? email;
  final String? company;
  final String? website;
  final String? address;
  final String? birthday;
  final String? notes;
  final String? photo;

  const ContactProps({
    this.phones = const [],
    this.phoneFallback,
    this.email,
    this.company,
    this.website,
    this.address,
    this.birthday,
    this.notes,
    this.photo,
  });

  String? get primaryPhone =>
      phones.isNotEmpty ? phones.first : phoneFallback;

  /// SPoT: "phones" JSON → List<String>. Δέχεται List<String> ΚΑΙ
  /// [{number/phone/value}] ΚΑΙ scalar. isPhone-gate ΜΟΝΟ στο raw-scalar
  /// fallback (τα στοιχεία λίστας κρατούν isNotEmpty, όχι gate — κοντά νούμερα).
  static List<String> parsePhonesValue(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return AppStringUtils.isPhone(raw) ? [raw.trim()] : const [];
    }
    if (decoded is String) {
      return AppStringUtils.isPhone(decoded) ? [decoded.trim()] : const [];
    }
    if (decoded is num) return [decoded.toString()];
    if (decoded is! List) return const [];
    final out = <String>[];
    for (final e in decoded) {
      if (e == null) continue;
      if (e is String) {
        if (e.isNotEmpty) out.add(e);
        continue;
      }
      if (e is num) {
        out.add(e.toString());
        continue;
      }
      if (e is Map) {
        for (final k in ['number', 'phone', 'value']) {
          final v = e[k];
          if (v != null && v.toString().isNotEmpty) {
            out.add(v.toString());
            break;
          }
        }
        continue;
      }
      final s = e.toString();
      if (s.isNotEmpty && s != 'null') out.add(s);
    }
    return out.where((s) => s.isNotEmpty).toList();
  }

  factory ContactProps.fromProperties(List<ItemProperty> props) {
    try {
      String? get(String key) {
        for (final p in props) {
          if (p.key == key) return p.value;
        }
        return null;
      }

      return ContactProps(
        phones: parsePhonesValue(get('phones')),
        phoneFallback: get('phone'),
        email: get('email'),
        company: get('company'),
        website: get('website'),
        address: get('address'),
        birthday: get('birthday'),
        notes: get('notes'),
        photo: get('photo'),
      );
    } catch (e, stack) {
      DebugConfig.error('ContactProps.fromProperties', e, stack);
      return const ContactProps();
    }
  }
}
