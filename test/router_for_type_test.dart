// test/router_for_type_test.dart
//
// AppRoutes.forType SPoT (Φ4a βήμα 15): κοινός type→route mapper.
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/router/app_router.dart';
import 'package:super_note/models/models.dart';

void main() {
  test('routable types → route strings', () {
    expect(AppRoutes.forType(ItemType.note, 1), '/notes/1');
    expect(AppRoutes.forType(ItemType.task, 2), '/tasks/2');
    expect(AppRoutes.forType(ItemType.checklist, 3), '/tasks/3');
    expect(AppRoutes.forType(ItemType.habit, 4), '/habits/4');
    expect(AppRoutes.forType(ItemType.event, 5), '/calendar/5');
    expect(AppRoutes.forType(ItemType.appointment, 6), '/appointments/6');
    expect(AppRoutes.forType(ItemType.journal, 7), '/journal/7');
    expect(AppRoutes.forType(ItemType.contact, 8), '/contacts/8');
    expect(AppRoutes.forType(ItemType.project, 9), '/collections/9');
  });

  test('χωρίς route → null', () {
    expect(AppRoutes.forType(ItemType.goal, 1), isNull);
    expect(AppRoutes.forType(ItemType.finance, 1), isNull);
    expect(AppRoutes.forType(ItemType.bookmark, 1), isNull);
    expect(AppRoutes.forType(ItemType.knowledge, 1), isNull);
  });
}
