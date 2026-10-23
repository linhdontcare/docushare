// ==============================================================================
// PRESENTATION LAYER: Custom Search Bar Widget (Deep Tech Emerald)
// Tuân thủ Flutter Box Model: Container làm khung với chiều cao, viền và đổ bóng nhẹ.
// Thiết kế đồng bộ Deep Tech Emerald: Dark Slate #1E293B, Slate 700 #334155,
// Text trắng #FFFFFF và Icon tìm kiếm Emerald Green #10B981.
// ==============================================================================

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CustomSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final String hintText;
  final String initialValue;

  const CustomSearchBar({
    super.key,
    required this.onChanged,
    this.onClear,
    this.hintText = 'Tìm kiếm theo tiêu đề hoặc môn học...',
    this.initialValue = '',
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  late final TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _hasText = widget.initialValue.isNotEmpty;
    _controller.addListener(_handleTextChanged);
  }

  void _handleTextChanged() {
    final hasContent = _controller.text.trim().isNotEmpty;
    if (_hasText != hasContent) {
      setState(() {
        _hasText = hasContent;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _clearText() {
    _controller.clear();
    widget.onChanged('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Tuân thủ Box Model: Container làm khung với chiều cao 52px, viền Dark Slate
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.borderSubtle,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          textInputAction: TextInputAction.search,
          style: const TextStyle(
            fontSize: 14.5,
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hintText,
            hintStyle: const TextStyle(
              fontSize: 13.5,
              color: AppTheme.textSecondary,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 21,
              color: AppTheme.primaryColor, // Emerald Green #10B981
            ),
            suffixIcon: _hasText
                ? IconButton(
                    icon: const Icon(Icons.cancel_rounded, size: 19),
                    color: AppTheme.textSecondary,
                    onPressed: _clearText,
                    tooltip: 'Xóa tìm kiếm',
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ),
    );
  }
}
