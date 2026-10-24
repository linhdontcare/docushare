// ==============================================================================
// PRESENTATION LAYER: Home Screen (EduVault - LDC Edition)
// Giao diện Responsive hoàn chỉnh cho Mobile, Tablet và Desktop Web
// Thiết kế theo phong cách Deep Tech Emerald:
// - Tích hợp AdaptiveNavigationShell (Sidebar trên Web, NavigationRail trên Tablet, BottomBar trên Mobile)
// - Danh sách tài liệu tự co giãn qua ResponsiveDocumentGrid (1 cột Mobile, 2 cột Tablet, 3-4 cột Desktop)
// - Mở tệp đa nền tảng: Download URL trên Web, Cache Temp File trên Android
// - Giữ nguyên 100% logic Firestore, Supabase RLS, Drift SQLite, Search & Filter
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../../core/firebase/firebase_service.dart';
import '../../core/responsive/app_breakpoints.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/document_model.dart';
import '../providers/document_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/adaptive_navigation.dart';
import '../widgets/borrow_request_dialog.dart';
import '../widgets/location_filter_bar_widget.dart';
import '../widgets/map/document_map_view_widget.dart';
import '../widgets/recommendation_carousel_widget.dart';
import '../widgets/responsive_document_grid.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/share_document_dialog.dart';
import '../widgets/tag_selector_widget.dart';
import 'add_edit_document_screen.dart';
import 'document_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedMainTab = 0; // 0: 'Tài liệu của tôi', 1: 'Được chia sẻ với tôi', 2: 'Khám phá tài liệu'
  bool _isMapView = false; // Chế độ xem: false = Grid/List, true = Bản đồ vị trí học tập

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentProvider>();
    final userProvider = context.watch<UserProvider>();
    final user = FirebaseService.instance.currentUser;
    final isDesktopOrTablet = !context.isMobile;

    final displayedDocs = switch (_selectedMainTab) {
      0 => provider.filteredDocuments,
      1 => provider.filteredSharedDocuments,
      _ => provider.filteredDiscoverableDocuments,
    };
    final isLoading = switch (_selectedMainTab) {
      0 => provider.isLoading,
      1 => provider.isLoadingShared,
      _ => provider.isLoadingDiscoverable,
    };

    final destinations = [
      AdaptiveNavigationItem(
        icon: Icons.folder_outlined,
        selectedIcon: Icons.folder_rounded,
        label: 'Tài liệu của tôi',
        badgeCount: provider.documents.length,
      ),
      AdaptiveNavigationItem(
        icon: Icons.people_alt_outlined,
        selectedIcon: Icons.people_alt_rounded,
        label: 'Được chia sẻ',
        badgeCount: provider.sharedDocuments.length,
      ),
      AdaptiveNavigationItem(
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore_rounded,
        label: 'Khám phá',
        badgeCount: provider.discoverableDocuments.length,
      ),
    ];

    return AdaptiveNavigationShell(
      selectedIndex: _selectedMainTab,
      onDestinationSelected: (index) {
        setState(() => _selectedMainTab = index);
        if (index == 2) {
          provider.fetchDiscoverableDocuments();
        }
      },
      destinations: destinations,
      userName: user?.displayName ?? 'Sinh viên',
      userEmail: user?.email ?? 'Chế độ Cục bộ (Offline)',
      userPhotoUrl: user?.photoURL,
      isSupabaseConnected: userProvider.isRlsVerified || userProvider.isSupabaseConfigured,
      onAddDocument: () => _navigateToAdd(context),
      onSignOut: () => _handleFirebaseAuth(context, user != null),
      onShowAbout: () => _showAboutDialog(context),
      onCheckSupabase: user != null ? () => _showSupabaseDialog(context, user, userProvider) : null,
      body: Scaffold(
        backgroundColor: AppTheme.scaffoldBackground,
        appBar: isDesktopOrTablet ? null : _buildMobileAppBar(context, user, userProvider),
        body: SafeArea(
          top: isDesktopOrTablet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header khu vực nội dung chính cho Tablet / Desktop
              if (isDesktopOrTablet) _buildDesktopContentHeader(context, provider),

              // Khối tìm kiếm cho Mobile
              if (!isDesktopOrTablet)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: CustomSearchBar(
                    initialValue: provider.searchQuery,
                    onChanged: (query) => provider.setSearchQuery(query),
                    onClear: () => provider.setSearchQuery(''),
                  ),
                ),

              // Gợi ý học tập thông minh (AI Content-based & Jaccard Matching)
              if (_selectedMainTab == 0 && provider.recommendedDocuments.isNotEmpty)
                RecommendationCarouselWidget(
                  recommendations: provider.recommendedDocuments,
                  onDocumentTap: (doc) => _navigateToDetail(context, doc),
                  onTagTap: (tag) => provider.toggleTagFilter(tag),
                ),

              // Thanh lọc Tag phân loại nằm ngang (luôn hiển thị để người dùng dễ dàng phân loại theo nhãn)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: TagFilterBarWidget(
                  tags: provider.allTags,
                  selectedTags: provider.selectedTags,
                  selectedTag: provider.selectedTag,
                  onTagToggled: (tag) => provider.toggleTagFilter(tag),
                  onTagSelected: (tag) => provider.setTagFilter(tag),
                  onClearAll: () => provider.clearTagFilters(),
                ),
              ),

              // Banner thông tin các hashtag đang lọc (Hỗ trợ nhiều tag, toggle AND/OR, xóa từng tag)
              if (provider.selectedTags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tag_rounded, size: 14, color: AppTheme.primaryColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Đang lọc ${provider.selectedTags.length} hashtag (${displayedDocs.length} tài liệu)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            // Chuyển đổi chế độ Khớp bất kỳ (OR) / Khớp tất cả (AND) nếu chọn từ 2 hashtag trở lên
                            if (provider.selectedTags.length > 1) ...[
                              InkWell(
                                onTap: () => provider.setMatchAllTags(!provider.matchAllTags),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cardBackground,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        provider.matchAllTags ? Icons.all_inclusive_rounded : Icons.alt_route_rounded,
                                        size: 12,
                                        color: AppTheme.primaryColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        provider.matchAllTags ? 'Khớp tất cả (AND)' : 'Khớp bất kỳ (OR)',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            InkWell(
                              onTap: () => provider.clearTagFilters(),
                              borderRadius: BorderRadius.circular(4),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  children: [
                                    Text(
                                      'Xóa tất cả',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 2),
                                    Icon(Icons.close_rounded, size: 13, color: Colors.redAccent),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: provider.selectedTags.map((t) {
                            return Chip(
                              padding: EdgeInsets.zero,
                              labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              backgroundColor: AppTheme.primaryColor,
                              side: BorderSide.none,
                              label: Text(
                                '#$t',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              deleteIcon: const Icon(
                                Icons.close_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              onDeleted: () => provider.removeTagFilter(t),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),

              // Thanh lọc Vị trí lưu trữ vật lý nằm ngang (Thư viện Tạ Quang Bửu, Thư viện Trung tâm, Lab AI,...)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: LocationFilterBarWidget(
                  locations: provider.allLocations,
                  selectedLocation: provider.selectedLocation,
                  onLocationSelected: (loc) => provider.setLocationFilter(loc),
                  countDocumentsAtLocation: (loc) => provider.countDocumentsAtLocation(loc),
                ),
              ),

              // Banner thông tin Vị trí đang lọc
              if (provider.selectedLocation != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.place_rounded, size: 16, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Đang lọc theo vị trí: ${provider.selectedLocation} (${displayedDocs.length} tài liệu)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () => provider.clearLocationFilter(),
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              children: [
                                Text(
                                  'Bỏ lọc vị trí',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 3),
                                Icon(Icons.close_rounded, size: 13, color: Colors.redAccent),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Thanh lọc danh mục nằm ngang
              _buildCategoryBar(provider),

              const SizedBox(height: 4),

              // Danh sách / Grid tài liệu responsive
              Expanded(
                child: (userProvider.isAssigningClaim)
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Đang tự động khởi tạo quyền tài khoản qua Cloud Function...',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : (userProvider.claimError != null && !userProvider.isClaimVerified)
                        ? _buildClaimErrorState(context, userProvider)
                        : isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primaryColor,
                                ),
                              )
                            : (provider.errorMessage != null && displayedDocs.isEmpty)
                                ? _buildErrorState(context, provider)
                                : _isMapView
                                    ? DocumentMapViewWidget(
                                        documents: displayedDocs,
                                        onDocumentTap: (doc) => _navigateToDetail(context, doc),
                                        onSwitchToListView: () => setState(() => _isMapView = false),
                                      )
                                    : ResponsiveContainer(
                                        maxWidth: AppBreakpoints.desktopContentMaxWidth,
                                        child: ResponsiveDocumentGrid(
                                          documents: displayedDocs,
                                          onRefresh: () async {
                                            if (_selectedMainTab == 0) {
                                              await provider.refresh();
                                            } else if (_selectedMainTab == 1) {
                                              await provider.fetchSharedDocuments();
                                            } else {
                                              await provider.fetchDiscoverableDocuments();
                                            }
                                          },
                                          onTap: (doc) => _navigateToDetail(context, doc),
                                          onEdit: (doc) => _navigateToEdit(context, doc),
                                          onDelete: (doc) => _confirmDelete(context, doc),
                                          onShare: (doc) => _openShareDialog(context, doc),
                                          emptyWidget: _buildEmptyState(context, provider),
                                        ),
                                      ),
              ),
            ],
          ),
        ),
        // FAB thêm tài liệu chỉ hiển thị trên Mobile ở tab "Tài liệu của tôi"
        floatingActionButton: (!isDesktopOrTablet && _selectedMainTab == 0)
            ? FloatingActionButton.extended(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                onPressed: () => _navigateToAdd(context),
                icon: const Icon(Icons.add_rounded, size: 22),
                label: const Text(
                  'Thêm tài liệu',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              )
            : null,
      ),
    );
  }

  // ============================================================================
  // HEADER KHỐI NỘI DUNG (TABLET & DESKTOP WEB)
  // ============================================================================
  Widget _buildDesktopContentHeader(BuildContext context, DocumentProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: const BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderSubtle, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      switch (_selectedMainTab) {
                        0 => 'Tài liệu của tôi',
                        1 => 'Được chia sẻ với tôi',
                        _ => 'Khám phá tài liệu',
                      },
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      switch (_selectedMainTab) {
                        0 => 'Quản lý, phân loại và đồng bộ tài liệu học tập cá nhân',
                        1 => 'Tài liệu do các thành viên khác chia sẻ với quyền Viewer hoặc Editor',
                        _ => 'Khám phá và mượn tài liệu học tập công khai từ các thành viên khác',
                      },
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Ô tìm kiếm nhanh trên Desktop Header
              SizedBox(
                width: 280,
                child: CustomSearchBar(
                  initialValue: provider.searchQuery,
                  onChanged: (query) => provider.setSearchQuery(query),
                  onClear: () => provider.setSearchQuery(''),
                ),
              ),

              const SizedBox(width: 10),

              // Toggle chuyển đổi chế độ xem: Danh sách / Bản đồ vị trí
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _isMapView = false),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: !_isMapView ? AppTheme.primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.grid_view_rounded,
                              size: 15,
                              color: !_isMapView ? Colors.white : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Danh sách',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: !_isMapView ? Colors.white : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _isMapView = true),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: _isMapView ? Colors.amber : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.map_rounded,
                              size: 15,
                              color: _isMapView ? Colors.black : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Bản đồ vị trí',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _isMapView ? Colors.black : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const BorrowManagementModal(),
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text(
                  'Mượn / Trả sách',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),

              if (_selectedMainTab == 0) ...[
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _navigateToAdd(context),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    'Tạo mới',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // APPBAR (MOBILE)
  // ============================================================================
  PreferredSizeWidget _buildMobileAppBar(
    BuildContext context,
    dynamic user,
    UserProvider userProvider,
  ) {
    final topInset = MediaQuery.paddingOf(context).top;
    return PreferredSize(
      preferredSize: Size.fromHeight(topInset + 60),
      child: Container(
        height: topInset + 60,
        decoration: const BoxDecoration(
          gradient: AppTheme.headerGradient,
          border: Border(
            bottom: BorderSide(color: AppTheme.borderSubtle, width: 1),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.emeraldPillGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.folder_special_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DocuShare',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Hệ thống Quản lý Tài liệu',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isMapView ? Icons.grid_view_rounded : Icons.map_rounded,
                    size: 20,
                  ),
                  color: _isMapView ? Colors.amber : AppTheme.primaryColor,
                  tooltip: _isMapView ? 'Xem danh sách tài liệu' : 'Xem bản đồ vị trí tài liệu',
                  onPressed: () => setState(() => _isMapView = !_isMapView),
                ),
                if (user != null)
                  IconButton(
                    icon: const Icon(Icons.shield_outlined, size: 20),
                    color: userProvider.isRlsVerified ? AppTheme.primaryColor : Colors.amber,
                    tooltip: 'Kiểm tra Supabase RLS',
                    onPressed: () => _showSupabaseDialog(context, user, userProvider),
                  ),
                IconButton(
                  icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                  color: AppTheme.primaryColor,
                  tooltip: 'Quản lý mượn/trả sách',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const BorrowManagementModal(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded, size: 20),
                  color: AppTheme.textSecondary,
                  tooltip: 'Giới thiệu',
                  onPressed: () => _showAboutDialog(context),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  color: Colors.redAccent,
                  tooltip: 'Đăng xuất',
                  onPressed: () => _handleFirebaseAuth(context, user != null),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // THANH LỌC DANH MỤC
  // ============================================================================
  Widget _buildCategoryBar(DocumentProvider provider) {
    final categories = provider.categories;
    final selectedCategoryId = provider.selectedCategoryId;

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _buildCategoryTab(
              label: 'Tất cả',
              isSelected: selectedCategoryId == null || selectedCategoryId == 'all',
              onTap: () => provider.setCategoryFilter('all'),
            ),
          ),
          ...categories.map((category) {
            final isSelected = selectedCategoryId == category.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _buildCategoryTab(
                label: category.name,
                isSelected: isSelected,
                onTap: () => provider.setCategoryFilter(category.id),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderSubtle,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // ERROR STATE (KHI TRUY VẤN THẤT BẠI - KHÔNG HIỂN THỊ "CHƯA CÓ TÀI LIỆU NÀO")
  // ============================================================================
  Widget _buildErrorState(BuildContext context, DocumentProvider provider) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 38,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Không thể tải tài liệu từ Supabase',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                provider.errorMessage ?? 'Lỗi kết nối cơ sở dữ liệu Supabase.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (_selectedMainTab == 0) {
                    provider.refresh();
                  } else if (_selectedMainTab == 1) {
                    provider.fetchSharedDocuments();
                  } else {
                    provider.fetchDiscoverableDocuments();
                  }
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // CLAIM ERROR STATE (LỖI GÁN ROLE = AUTHENTICATED QUA CLOUD FUNCTION)
  // ============================================================================
  Widget _buildClaimErrorState(BuildContext context, UserProvider userProvider) {
    final user = FirebaseService.instance.currentUser;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 38,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Chưa thể cấp quyền tài khoản DocuShare',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                userProvider.claimError ??
                    'Tài khoản chưa được gán role = authenticated qua Cloud Function. '
                    'Vui lòng kiểm tra kết nối mạng và nhấn Thử lại.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: user != null
                    ? () async {
                        await userProvider.onUserAuthenticated(user, force: true);
                        if (context.mounted && userProvider.isClaimVerified) {
                          final docProvider = context.read<DocumentProvider>();
                          docProvider.fetchUserDocuments();
                          docProvider.fetchSharedDocuments();
                        }
                      }
                    : null,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Thử lại cấp quyền'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // EMPTY STATE
  // ============================================================================
  Widget _buildEmptyState(BuildContext context, DocumentProvider provider) {
    final hasFilter = provider.searchQuery.isNotEmpty ||
        (provider.selectedCategoryId != null && provider.selectedCategoryId != 'all');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  hasFilter ? Icons.search_off_rounded : Icons.folder_open_rounded,
                  size: 40,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                hasFilter ? 'Không tìm thấy tài liệu phù hợp' : 'Chưa có tài liệu nào',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                hasFilter
                    ? 'Hãy thử thay đổi từ khóa tìm kiếm hoặc chọn danh mục khác.'
                    : 'Bắt đầu quản lý tài liệu học tập của bạn bằng cách tạo tài liệu đầu tiên.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              if (hasFilter)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    provider.setSearchQuery('');
                    provider.setCategoryFilter('all');
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Đặt lại bộ lọc'),
                )
              else if (_selectedMainTab == 0)
                FilledButton.icon(
                  onPressed: () => _navigateToAdd(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Tạo tài liệu mới'),
                )
              else if (_selectedMainTab == 2)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => provider.fetchDiscoverableDocuments(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Làm mới danh sách'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // CÁC THAO TÁC NGHIỆP VỤ (CRUD, VIEW, SHARE, AUTH)
  // ============================================================================
  void _navigateToAdd(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => const AddEditDocumentScreen()),
    );
  }

  void _navigateToDetail(BuildContext context, DocumentModel doc) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => DocumentDetailScreen(document: doc)),
    );
  }

  void _navigateToEdit(BuildContext context, DocumentModel doc) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => AddEditDocumentScreen(document: doc)),
    );
  }



  // Xác nhận xóa tài liệu với Dialog an toàn
  Future<void> _confirmDelete(BuildContext context, DocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.borderSubtle),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Xác nhận xóa tài liệu', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa tài liệu "${doc.title}"?\nThao tác này sẽ xóa đồng bộ cả trên Firebase Storage và Supabase.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text('Đang xóa "${doc.title}"...'),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );

      try {
        await context.read<DocumentProvider>().deleteDocument(
          doc.id,
          storagePath: doc.filePathOrUrl,
          document: doc,
        );
        if (context.mounted) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Text('Đã xóa thành công "${doc.title}".'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        }
      } catch (err) {
        if (context.mounted) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Text('Lỗi khi xóa tài liệu: $err'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _openShareDialog(BuildContext context, DocumentModel doc) {
    final user = FirebaseService.instance.currentUser;
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập Google để chia sẻ tài liệu.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => ShareDocumentDialog(
        document: doc,
        currentUserEmail: user.email!,
      ),
    );
  }

  Future<void> _handleFirebaseAuth(BuildContext context, bool isSignedIn) async {
    try {
      if (isSignedIn) {
        context.read<UserProvider>().onUserSignedOut();
        await context.read<DocumentProvider>().onUserSignedOut();
        await FirebaseService.instance.signOut();
      } else {
        await FirebaseService.instance.signInWithGoogle();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isSignedIn
                  ? 'Đã đăng xuất Firebase và Supabase session.'
                  : 'Đăng nhập Google thành công.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        final isCancelled = error is GoogleSignInException &&
            error.code == GoogleSignInExceptionCode.canceled;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCancelled ? 'Đã hủy đăng nhập Google.' : 'Không thể xác thực: $error',
            ),
            backgroundColor: isCancelled ? null : Colors.orange,
          ),
        );
      }
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.borderSubtle),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.emeraldPillGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'DocuShare',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: AppTheme.emeraldPillGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'LDC EDITION • RESPONSIVE CROSS-PLATFORM',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ứng dụng Quản lý Tài liệu Học tập chuẩn kiến trúc Cashew App với giao diện Deep Tech Emerald cao cấp, hỗ trợ Mobile và Chrome Web.',
              style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 14),
            const Divider(color: AppTheme.borderSubtle),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.devices_rounded, size: 16, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text('Mobile, Tablet & Desktop Web Adaptive', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(Icons.storage_rounded, size: 16, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text('Drift ORM (WASM Web & Background Isolate)', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(Icons.security_rounded, size: 16, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text('Supabase PostgreSQL RLS & Firebase Auth', style: TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
              ],
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showSupabaseDialog(BuildContext context, dynamic user, UserProvider userProvider) {
    showDialog(
      context: context,
      builder: (ctx) => Consumer<UserProvider>(
        builder: (dialogCtx, liveProvider, _) {
          final profile = liveProvider.profile;
          final isVerified = liveProvider.isRlsVerified;

          return AlertDialog(
            backgroundColor: AppTheme.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppTheme.borderSubtle),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isVerified
                        ? AppTheme.primaryColor.withValues(alpha: 0.2)
                        : Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isVerified ? Icons.verified_user_rounded : Icons.security_rounded,
                    color: isVerified ? AppTheme.primaryColor : Colors.amber,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Supabase & RLS Auth',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    label: 'Firebase UID',
                    value: user.uid as String? ?? 'N/A',
                    isMono: true,
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    label: 'Email Google',
                    value: user.email as String? ?? 'N/A',
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    label: 'Supabase User UUID (public.users)',
                    value: profile?.id ??
                        (liveProvider.isSupabaseConfigured
                            ? 'Chưa đồng bộ'
                            : 'Chưa cấu hình URL/Key qua --dart-define'),
                    isMono: true,
                    highlight: profile?.id != null,
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    label: 'Trạng thái xác thực RLS (Third-Party JWT)',
                    value: isVerified
                        ? 'Hợp lệ • Policy users_select_authenticated'
                        : (liveProvider.isSupabaseConfigured
                            ? 'Chưa đọc được hồ sơ'
                            : 'Cần khởi chạy với --dart-define'),
                    highlight: isVerified,
                  ),
                ],
              ),
            ),
            actions: [
              if (liveProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () async {
                    await liveProvider.refreshProfile(user.uid as String);
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Thử đọc lại từ Supabase'),
                ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Đóng'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    bool isMono = false,
    bool highlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: highlight
                  ? AppTheme.primaryColor.withValues(alpha: 0.5)
                  : AppTheme.borderSubtle,
            ),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: isMono ? 11 : 12,
              fontFamily: isMono ? 'monospace' : null,
              color: highlight ? AppTheme.primaryColor : AppTheme.textPrimary,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
