// lib/shared/widgets/link_text.dart
//
// Πατήσιμα links μέσα σε σώμα σημείωσης/event.
// SPoT: `extractUrls` (pure, testable) + `LinkLauncher.openUrl` +
// `LinkList` widget (χρησιμοποιείται από BlockTileWidget + EventDetail notes).
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/core.dart';

/// Βγάζει τα http(s) URLs από ελεύθερο κείμενο (χωρίς διπλότυπα).
/// Οι παρενθέσεις επιτρέπονται μέσα στο URL (π.χ. Wikipedia) —
/// κόβεται μόνο η μη-ισορροπημένη τελική (π.χ. "(δες https://x.gr/a)").
List<String> extractUrls(String text) {
  final found = <String>[];
  final re = RegExp(r'https?://[^\s<>"\]]+');
  for (final m in re.allMatches(text)) {
    var url = m.group(0)!;
    // Κόψε τελικά σημεία στίξης (πρόταση "...δες https://x.gr.").
    while (url.isNotEmpty && '.,;:!?'.contains(url[url.length - 1])) {
      url = url.substring(0, url.length - 1);
    }
    // Κόψε τελικές ')' που δεν κλείνουν κάποια '(' του URL.
    int count(String s, String c) => s.split(c).length - 1;
    while (url.endsWith(')') && count(url, '(') < count(url, ')')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.isNotEmpty && !found.contains(url)) found.add(url);
  }
  return found;
}

/// Άνοιγμα URL σε εξωτερικό browser. Μόνο http/https.
class LinkLauncher {
  LinkLauncher._();

  static Future<bool> openUrl(String raw) async {
    try {
      final uri = Uri.tryParse(raw.trim());
      if (uri == null ||
          !(uri.scheme == 'http' || uri.scheme == 'https') ||
          uri.host.isEmpty) {
        DebugConfig.warning('LinkLauncher rejected non-http url: $raw');
        return false;
      }
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) DebugConfig.warning('LinkLauncher launch failed: $raw');
      return ok;
    } catch (e, stack) {
      DebugConfig.error('LinkLauncher.openUrl', e, stack);
      return false;
    }
  }
}

/// Σειρά πατήσιμων links κάτω από κείμενο block/notes.
class LinkList extends StatelessWidget {
  final String text;

  const LinkList({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final urls = extractUrls(text);
    if (urls.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final url in urls)
          GestureDetector(
            onTap: () => LinkLauncher.openUrl(url),
            child: Padding(
              padding: const EdgeInsets.only(top: Spacing.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link_rounded,
                      size: 14, color: context.cPrimary),
                  const SizedBox(width: Spacing.xs),
                  Flexible(
                    child: Text(
                      url,
                      style: context.bodySm.withColor(context.cPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
