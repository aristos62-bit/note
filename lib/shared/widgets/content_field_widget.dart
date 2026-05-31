import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/core.dart';

/// Shared text field widget with consistent behavior across all detail screens.
///
/// Features:
/// - Auto-delete empty content on focus loss
/// - Auto-expand to multiple lines (maxLines: null)
/// - Debounced save (avoids saving on every keystroke)
/// - Cursor at start for new fields
/// - Tap to position cursor, long press for text selection
class ContentFieldWidget extends StatefulWidget {
  final String? initialText;
  final String? hintText;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSaved;
  final VoidCallback? onDeleteEmpty;
  final Duration debounce;
  final bool autoDeleteEmpty;
  final bool cursorAtStart;
  final bool autoFocus;
  final TextInputAction? textInputAction;

  const ContentFieldWidget({
    super.key,
    this.initialText,
    this.hintText,
    this.style,
    this.onChanged,
    this.onSaved,
    this.onDeleteEmpty,
    this.debounce = const Duration(milliseconds: 500),
    this.autoDeleteEmpty = true,
    this.cursorAtStart = false,
    this.autoFocus = false,
    this.textInputAction,
  });

  @override
  State<ContentFieldWidget> createState() => _ContentFieldWidgetState();
}

class _ContentFieldWidgetState extends State<ContentFieldWidget> {
  late final TextEditingController _ctrl;
  late final FocusNode _focusNode;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText ?? '');
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    if (widget.cursorAtStart || widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.autoFocus) {
          _focusNode.requestFocus();
        }
        if (widget.cursorAtStart) {
          _ctrl.selection = const TextSelection.collapsed(offset: 0);
        }
      });
    }
  }

  @override
  void didUpdateWidget(ContentFieldWidget old) {
    super.didUpdateWidget(old);
    if (widget.initialText != old.initialText && !_focusNode.hasFocus) {
      _ctrl.text = widget.initialText ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    _debounce?.cancel();
    if (!_focusNode.hasFocus && widget.autoDeleteEmpty) {
      final text = _ctrl.text.trim();
      if (text.isEmpty) {
        widget.onDeleteEmpty?.call();
      } else {
        widget.onSaved?.call(text);
      }
    }
  }

  void _onChange(String value) {
    widget.onChanged?.call(value);
    _debounce?.cancel();
    _debounce = Timer(widget.debounce, () {
      final trimmed = value.trim();
      if (trimmed.isEmpty && widget.autoDeleteEmpty) {
        widget.onDeleteEmpty?.call();
      } else {
        widget.onSaved?.call(trimmed);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      focusNode: _focusNode,
      onChanged: _onChange,
      style: widget.style ?? context.bodyMd,
      maxLines: null,
      textInputAction: widget.textInputAction,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: (widget.style ?? context.bodyMd).withColor(context.cDisabled),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
