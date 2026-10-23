// ==============================================================================
// PRESENTATION WIDGET: recommendation_carousel_widget.dart
// Băng chuyền gợi ý tài liệu học tập thông minh (Recommendation Engine UI)
// Hiển thị các tài liệu phù hợp nhất theo thuật toán Jaccard Similarity & Subject Affinity
// Tương thích responsive trên Mobile, Tablet và Desktop Web
// ==============================================================================

import 'package:flutter/material.dart';
import '../../core/services/recommendation_service.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/document_model.dart';
import 'location_picker_widget.dart';

class RecommendationCarouselWidget extends StatefulWidget {
  final List<DocumentRecommendation> recommendations;
  final ValueChanged<DocumentModel> onDocumentTap;
  final ValueChanged<String>? onTagTap;

  const RecommendationCarouselWidget({
    super.key,
    required this.recommendations,
    required this.onDocumentTap,
    this.onTagTap,
  });

  @override
  State<RecommendationCarouselWidget> createState() => _RecommendationCarouselWidgetState();
}

class _RecommendationCarouselWidgetState extends State<RecommendationCarouselWidget> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header tiêu đề băng chuyền
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Gợi ý học tập dành cho bạn',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'AI Match',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Thuật toán Content-based & Jaccard gợi ý theo môn học và thẻ tag',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isCollapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                  tooltip: _isCollapsed ? 'Mở rộng gợi ý' : 'Thu gọn gợi ý',
                  onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
                ),
              ],
            ),
          ),

          if (!_isCollapsed) ...[
            const Divider(height: 1, color: AppTheme.borderSubtle),
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                itemCount: widget.recommendations.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final rec = widget.recommendations[index];
                  return _RecommendationCard(
                    recommendation: rec,
                    onTap: () => widget.onDocumentTap(rec.document),
                    onTagTap: widget.onTagTap,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatefulWidget {
  final DocumentRecommendation recommendation;
  final VoidCallback onTap;
  final ValueChanged<String>? onTagTap;

  const _RecommendationCard({
    required this.recommendation,
    required this.onTap,
    this.onTagTap,
  });

  @override
  State<_RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<_RecommendationCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final rec = widget.recommendation;
    final doc = rec.document;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 260,
        decoration: BoxDecoration(
          color: _isHovered
              ? AppTheme.primaryColor.withValues(alpha: 0.12)
              : AppTheme.scaffoldBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered ? AppTheme.primaryColor : AppTheme.borderSubtle,
            width: 1,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Hàng trên: Độ phù hợp % và Reason Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 12, color: AppTheme.primaryColor),
                          const SizedBox(width: 2),
                          Text(
                            '${rec.matchPercentage}%',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        rec.reason,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.amber,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Tiêu đề tài liệu
                Text(
                  doc.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // Môn học & Vị trí thư viện
                Row(
                  children: [
                    const Icon(Icons.school_outlined, size: 12, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        doc.subject,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (doc.hasPhysicalLocation) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => showLocationDetailDialog(
                          context,
                          title: doc.title,
                          physicalLocation: doc.formattedLocationAddress ?? doc.displayLocationName,
                          locationName: doc.locationName,
                          building: doc.building,
                          floor: doc.floor,
                          shelf: doc.shelf,
                          latitude: doc.latitude,
                          longitude: doc.longitude,
                          notes: doc.locationNotes,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.place_rounded, size: 10, color: Colors.amber),
                              SizedBox(width: 2),
                              Text('Vị trí', style: TextStyle(fontSize: 9.5, color: Colors.amber, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                // Danh sách tags rút gọn
                if (doc.tags.isNotEmpty)
                  SizedBox(
                    height: 20,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: doc.tags.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 4),
                      itemBuilder: (context, tIdx) {
                        final tag = doc.tags[tIdx];
                        final isMatching = rec.matchingTags.contains(tag.replaceAll('#', '').toLowerCase());
                        return InkWell(
                          onTap: widget.onTagTap != null ? () => widget.onTagTap!(tag) : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isMatching
                                  ? AppTheme.primaryColor.withValues(alpha: 0.25)
                                  : AppTheme.cardBackground,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isMatching ? AppTheme.primaryColor : AppTheme.borderSubtle,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              '#$tag',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: isMatching ? AppTheme.primaryColor : AppTheme.textSecondary,
                                fontWeight: isMatching ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
