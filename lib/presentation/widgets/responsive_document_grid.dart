// ==============================================================================
// PRESENTATION LAYER: Responsive Document Grid / List
// Tự động phân chia layout danh sách tài liệu theo kích thước màn hình:
// - Mobile (< 600px): ListView 1 cột
// - Tablet (600 - 1024px): GridView 2 cột
// - Desktop (1024 - 1440px): GridView 3 cột
// - Màn hình lớn (>= 1440px): GridView 4 cột
// ==============================================================================

import 'package:flutter/material.dart';
import '../../core/responsive/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/document_model.dart';
import 'document_card.dart';

class ResponsiveDocumentGrid extends StatelessWidget {
  final List<DocumentModel> documents;
  final Future<void> Function() onRefresh;
  final void Function(DocumentModel doc) onTap;
  final void Function(DocumentModel doc) onEdit;
  final void Function(DocumentModel doc) onDelete;
  final void Function(DocumentModel doc)? onShare;
  final Widget? emptyWidget;

  const ResponsiveDocumentGrid({
    super.key,
    required this.documents,
    required this.onRefresh,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onShare,
    this.emptyWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty && emptyWidget != null) {
      return emptyWidget!;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        // Tính toán số cột hiển thị theo chiều rộng khả dụng thực tế
        final int crossAxisCount;
        final double childAspectRatio;

        if (availableWidth < AppBreakpoints.mobileMax) {
          crossAxisCount = 1;
          childAspectRatio = 1.0; // Không dùng trong ListView
        } else if (availableWidth < AppBreakpoints.tabletMax) {
          crossAxisCount = 2;
          childAspectRatio = 1.18;
        } else if (availableWidth < 1440) {
          crossAxisCount = 3;
          childAspectRatio = 1.15;
        } else {
          crossAxisCount = 4;
          childAspectRatio = 1.12;
        }

        final padding = EdgeInsets.symmetric(
          horizontal: context.responsive(
            mobile: 16.0,
            tablet: 20.0,
            desktop: 24.0,
          ),
          vertical: 12.0,
        );

        // Mobile: Dùng ListView cho trải nghiệm cuộn tự nhiên
        if (crossAxisCount == 1) {
          return RefreshIndicator(
            color: AppTheme.primaryColor,
            backgroundColor: AppTheme.cardBackground,
            onRefresh: onRefresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: padding.copyWith(bottom: 96),
              itemCount: documents.length,
              itemBuilder: (context, index) {
                final doc = documents[index];
                return DocumentCard(
                  document: doc,
                  onTap: () => onTap(doc),
                  onEdit: () => onEdit(doc),
                  onDelete: () => onDelete(doc),
                  onShare: doc.canShare && onShare != null
                      ? () => onShare!(doc)
                      : null,
                );
              },
            ),
          );
        }

        // Tablet & Desktop: Dùng GridView với khoảng cách cân đối
        return RefreshIndicator(
          color: AppTheme.primaryColor,
          backgroundColor: AppTheme.cardBackground,
          onRefresh: onRefresh,
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding.copyWith(bottom: 96),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final doc = documents[index];
              return DocumentCard(
                document: doc,
                onTap: () => onTap(doc),
                onEdit: () => onEdit(doc),
                onDelete: () => onDelete(doc),
                onShare: doc.canShare && onShare != null
                    ? () => onShare!(doc)
                    : null,
              );
            },
          ),
        );
      },
    );
  }
}
