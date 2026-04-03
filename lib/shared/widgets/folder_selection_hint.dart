
import 'package:flutter/material.dart';
import '../../core/core.dart';

class FolderSelectionHint extends StatelessWidget {
  final String itemType;
  final VoidCallback? onSelectFolder;

  const FolderSelectionHint({
    super.key,
    required this.itemType,
    this.onSelectFolder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: Spacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.cInfo.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: context.cInfo,
          ),
          const SizedBox(width: Spacing.xs),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Απαιτείται φάκελος για προσθήκη ',
                    style: context.bodySm.withColor(context.cInfo),
                  ),
                  TextSpan(
                    text: itemType,
                    style: context.bodySm.withColor(context.cInfo).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onSelectFolder != null)
            TextButton(
              onPressed: onSelectFolder,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Επιλογή',
                style: context.labelSm.withColor(context.cInfo),
              ),
            ),
        ],
      ),
    );
  }
}