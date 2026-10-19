// test/settings_font_scale_tile_test.dart
//
// F17 (S259): «Μέγεθος γραμματοσειράς» — ο τίτλος ΔΕΝ πρέπει να στενεύει από το
// Slider (πλέον το Slider μπαίνει σε δική του γραμμή, πλήρους πλάτους).
//
// Invariants (ανεξάρτητα από τη γραμματοσειρά):
//  1. δομικό   : το πλάτος που δίνεται στον τίτλο == όλο το πλάτος του tile-content
//                (στο παλιό Row layout: 296.7 - 192 = 104.7 dp ⇒ red).
//  2. σημασιολ.: το πλάτος του τίτλου φτάνει για τη μεγαλύτερη λέξη
//                «γραμματοσειράς» (μετριέται με ΙΔΙΟ style/scale path ⇒ ίδια metrics).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_note/core/core.dart';
import 'package:super_note/features/settings/settings_tiles.dart';

const _label = 'Μέγεθος γραμματοσειράς';
const _longestWord = 'γραμματοσειράς';

// Διαθέσιμο πλάτος tile-content (dp) της συσκευής M2007J20CG
// (2400x1080 px @ density 2.75): portrait 296.7, tablet-landscape 328.3.
const _contentWidths = <double>[296.7, 328.3];
const _scales = <double>[1.0, 1.4];

void main() {
  for (final width in _contentWidths) {
    for (final scale in _scales) {
      testWidgets(
        'F17 label keeps full width (content ${width}dp, textScale $scale)',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: Column(
                      children: [
                        SizedBox(
                          // Το tile προσθέτει horizontal padding Spacing.md ανά πλευρά.
                          width: width + Spacing.md * 2,
                          child: Consumer(
                            builder: (context, ref, _) =>
                                SettingsFontScaleTile(current: scale, ref: ref),
                          ),
                        ),
                        // Probe: ίδιο render path (style + textScaler) με τον τίτλο,
                        // με μη φραγμένο πλάτος ⇒ intrinsic πλάτος της λέξης.
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Builder(
                            builder: (c) => Text(_longestWord, style: c.bodyMd),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);

          final wordWidth = tester.getSize(find.text(_longestWord)).width;
          final paragraph =
              tester.renderObject<RenderParagraph>(find.text(_label));

          // 1) δομικό: ο τίτλος παίρνει όλο το πλάτος (όχι μειωμένο από sibling).
          expect(
            paragraph.constraints.maxWidth,
            greaterThanOrEqualTo(width - 0.5),
            reason: 'ο τίτλος στενεύει (παλιό Row layout ⇒ 104.7 dp)',
          );
          // 2) σημασιολογικό: χωράει η μεγαλύτερη λέξη.
          expect(
            paragraph.constraints.maxWidth,
            greaterThanOrEqualTo(wordWidth),
            reason: 'η λέξη «$_longestWord» ($wordWidth dp) δεν χωράει',
          );
        },
      );
    }
  }
}
