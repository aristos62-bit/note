// lib/core/utils/contact_props.dart
//
// SPoT για contact properties. Ενοποιεί τα 4πλά _extractContactProps:
// contact_list, contact_detail, share_service, appointment_detail.

import 'dart:convert';
import '../../models/item_property.dart';
import 'debug_config.dart';

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

  factory ContactProps.fromProperties(List<ItemProperty> props) {
    try {
      String? get(String key) {
        for (final p in props) {
          if (p.key == key) return p.value;
        }
        return null;
      }

      List<String> phones = [];
      final phonesJson = get('phones');
      if (phonesJson != null && phonesJson.isNotEmpty) {
        try {
          phones = (jsonDecode(phonesJson) as List)
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList();
        } catch (_) {
          // ignore malformed JSON, fallback παρακάτω
        }
      }

      return ContactProps(
        phones: phones,
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
