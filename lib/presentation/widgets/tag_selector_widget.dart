// ==============================================================================
// PRESENTATION WIDGET: tag_selector_widget.dart
// 1. TagInputWidget: Biểu mẫu nhập và quản lý thẻ Tag với gợi ý thông minh
// 2. TagFilterBarWidget: Thanh cuộn chọn Tag nhanh trên HomeScreen
// ==============================================================================

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Danh sách các tag phổ biến gợi ý sẵn cho sinh viên và giảng viên
const List<String> kSuggestedTags = [
  'flutter',
  'lập_trình',
  'cntt',
  'toán_cao_cấp',
  'ai_ml',
  'giáo_trình',
  'đề_thi',
  'slide',
  'bài_tập',
  'tiếng_anh',
];

/// Widget nhập và quản lý danh sách thẻ Tag
class TagInputWidget extends StatefulWidget {
  final List<String> initialTags;
  final ValueChanged<List<String>> onTagsChanged;

  const TagInputWidget({
    super.key,
    required this.initialTags,
    required this.onTagsChanged,
  });

  @override
  State<TagInputWidget> createState() => _TagInputWidgetState();
}

class _TagInputWidgetState extends State<TagInputWidget> {
  late List<String> _tags;
  final TextEditingController _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tags = List<String>.from(widget.initialTags);
  }

  void _addTag(String rawTag) {
    final cleanTag = rawTag.trim().replaceAll('#', '').replaceAll(',', '');
    if (cleanTag.isEmpty) return;

    if (!_tags.any((t) => t.toLowerCase() == cleanTag.toLowerCase())) {
      setState(() {
        _tags.add(cleanTag);
      });
      widget.onTagsChanged(_tags);
    }
    _tagController.clear();
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
    widget.onTagsChanged(_tags);
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ô nhập tag với nút thêm
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _tagController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Nhập tag và bấm Enter (vd: flutter, de_thi)...',
                  hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  prefixIcon: const Icon(Icons.tag_rounded, color: AppTheme.primaryColor, size: 18),
                  filled: true,
                  fillColor: AppTheme.scaffoldBackground,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.borderSubtle),
                  ),
                ),
                onFieldSubmitted: _addTag,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                foregroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _addTag(_tagController.text),
              child: const Text('Thêm', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),

        // Danh sách tag hiện tại đã gắn
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _tags.map((tag) {
              return Chip(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                labelPadding: const EdgeInsets.only(left: 4),
                avatar: const Icon(Icons.tag_rounded, size: 14, color: AppTheme.primaryColor),
                label: Text(
                  tag,
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                deleteIcon: const Icon(Icons.close_rounded, size: 14, color: AppTheme.textSecondary),
                onDeleted: () => _removeTag(tag),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              );
            }).toList(),
          ),
        ],

        // Gợi ý tag phổ biến
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.lightbulb_outline_rounded, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            const Text(
              'Gợi ý:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: kSuggestedTags.map((sug) {
                    final isAlreadyAdded = _tags.any((t) => t.toLowerCase() == sug.toLowerCase());
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                        backgroundColor: isAlreadyAdded
                            ? AppTheme.primaryColor.withValues(alpha: 0.25)
                            : AppTheme.scaffoldBackground,
                        side: BorderSide(
                          color: isAlreadyAdded ? AppTheme.primaryColor : AppTheme.borderSubtle,
                        ),
                        label: Text(
                          '#$sug',
                          style: TextStyle(
                            fontSize: 11,
                            color: isAlreadyAdded ? AppTheme.primaryColor : AppTheme.textSecondary,
                            fontWeight: isAlreadyAdded ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        onPressed: isAlreadyAdded ? null : () => _addTag(sug),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Thanh cuộn chọn Tag nhanh trên HomeScreen
class TagFilterBarWidget extends StatelessWidget {
  final List<String> tags;
  final String? selectedTag;
  final ValueChanged<String?> onTagSelected;

  const TagFilterBarWidget({
    super.key,
    required this.tags,
    required this.selectedTag,
    required this.onTagSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tags.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isAllSelected = selectedTag == null;
            return ChoiceChip(
              label: const Text('Tất cả tag', style: TextStyle(fontSize: 11.5)),
              selected: isAllSelected,
              onSelected: (_) => onTagSelected(null),
              selectedColor: AppTheme.primaryColor,
              backgroundColor: AppTheme.cardBackground,
              labelStyle: TextStyle(
                color: isAllSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: isAllSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isAllSelected ? AppTheme.primaryColor : AppTheme.borderSubtle,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            );
          }

          final tag = tags[index - 1];
          final isSelected = selectedTag?.toLowerCase() == tag.toLowerCase();

          return ChoiceChip(
            avatar: Icon(
              Icons.tag_rounded,
              size: 13,
              color: isSelected ? Colors.white : AppTheme.primaryColor,
            ),
            label: Text('#$tag', style: const TextStyle(fontSize: 11.5)),
            selected: isSelected,
            onSelected: (_) => onTagSelected(tag),
            selectedColor: AppTheme.primaryColor,
            backgroundColor: AppTheme.cardBackground,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textPrimary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            side: BorderSide(
              color: isSelected ? AppTheme.primaryColor : AppTheme.borderSubtle,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          );
        },
      ),
    );
  }
}
