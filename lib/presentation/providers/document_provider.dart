// ==============================================================================
// PRESENTATION / STATE LAYER: Document Provider
// Quản lý trạng thái ứng dụng theo kiến trúc Provider & ChangeNotifier của Cashew:
// - Lắng nghe luồng dữ liệu thời gian thực (Reactive Streams) từ Repository
// - Quản lý trạng thái tìm kiếm (Search Query) và bộ lọc danh mục (Category Filter)
// - Thực hiện các thao tác CRUD bất đồng bộ với cơ chế xử lý lỗi chặt chẽ
// - Thông báo cập nhật giao diện tự động (notifyListeners) khi dữ liệu thay đổi
// ==============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/firebase/firebase_service.dart';
import '../../core/services/recommendation_service.dart';
import '../../core/supabase/supabase_service.dart';
import '../../domain/models/borrow_request_model.dart';
import '../../domain/models/category_model.dart';
import '../../domain/models/document_model.dart';
import '../../domain/models/location_model.dart';
import '../../domain/models/supabase_document_model.dart';
import '../../domain/repositories/document_repository.dart';

class DocumentProvider extends ChangeNotifier {
  final DocumentRepository _repository;

  // Trạng thái nội bộ
  List<DocumentModel> _documents = [];
  List<DocumentModel> _sharedDocuments = [];
  List<CategoryModel> _categories = CategoryModel.defaultCategories;
  String _searchQuery = '';
  String? _selectedCategoryId = 'all';
  final Set<String> _selectedTags = {};
  bool _matchAllTags = false; // false = OR (khớp bất kỳ), true = AND (khớp tất cả)
  String? _selectedLocation; // Bộ lọc theo vị trí lưu trữ (Location Filter)
  bool _isLoading = false;
  bool _isLoadingShared = false;
  String? _errorMessage;

  // Thuật toán Recommendation
  final DocumentRecommendationService _recommendationService = const DocumentRecommendationService();
  List<String> _userPreferredTags = [];

  // Quản lý mượn trả tài liệu
  List<BorrowRequestModel> _incomingBorrowRequests = [];
  List<BorrowRequestModel> _myBorrowRequests = [];
  bool _isLoadingBorrow = false;

  // Khám phá tài liệu công khai (is_discoverable)
  List<DocumentModel> _discoverableDocuments = [];
  bool _isLoadingDiscoverable = false;

  // Stream Subscriptions quản lý giải phóng tài nguyên
  StreamSubscription<List<DocumentModel>>? _documentSubscription;
  StreamSubscription<List<CategoryModel>>? _categorySubscription;
  StreamSubscription<dynamic>? _authSubscription;

  DocumentProvider({required DocumentRepository repository})
    // ignore: prefer_initializing_formals
    : _repository = repository {
    _initCategoryStream();
    if (FirebaseService.instance.isAvailable) {
      _authSubscription = FirebaseService.instance.authStateChanges.listen(
        _handleAuthState,
      );
    } else {
      _subscribeToLocalDocuments();
    }
  }

  // --- Getters công khai cho giao diện ---

  List<DocumentModel> get documents => _documents;
  List<DocumentModel> get sharedDocuments => _sharedDocuments;
  List<CategoryModel> get categories =>
      _categories.isNotEmpty ? _categories : CategoryModel.defaultCategories;
  String get searchQuery => _searchQuery;
  String? get selectedCategoryId => _selectedCategoryId;
  Set<String> get selectedTags => Set.unmodifiable(_selectedTags);
  String? get selectedTag => _selectedTags.isEmpty ? null : _selectedTags.first;
  bool get matchAllTags => _matchAllTags;
  String? get selectedLocation => _selectedLocation;
  bool get isLoading => _isLoading;
  bool get isLoadingShared => _isLoadingShared;
  String? get errorMessage => _errorMessage;

  List<String> get userPreferredTags => _userPreferredTags;
  List<BorrowRequestModel> get incomingBorrowRequests => _incomingBorrowRequests;
  List<BorrowRequestModel> get myBorrowRequests => _myBorrowRequests;
  bool get isLoadingBorrow => _isLoadingBorrow;

  List<DocumentModel> get discoverableDocuments => _discoverableDocuments;
  bool get isLoadingDiscoverable => _isLoadingDiscoverable;

  /// Danh sách tất cả các tag duy nhất hiện có trong hệ thống
  List<String> get allTags {
    final tags = <String>{};
    for (final doc in _documents) {
      for (final t in doc.tags) {
        if (t.trim().isNotEmpty) tags.add(t.trim());
      }
    }
    for (final doc in _sharedDocuments) {
      for (final t in doc.tags) {
        if (t.trim().isNotEmpty) tags.add(t.trim());
      }
    }
    for (final doc in _discoverableDocuments) {
      for (final t in doc.tags) {
        if (t.trim().isNotEmpty) tags.add(t.trim());
      }
    }
    final sorted = tags.toList();
    sorted.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  /// Danh sách tất cả các vị trí lưu trữ vật lý duy nhất trong hệ thống
  List<String> get allLocations {
    final locations = <String>{};
    // 1. Lấy từ tài liệu thực tế của người dùng, tài liệu chia sẻ và khám phá
    for (final doc in [..._documents, ..._sharedDocuments, ..._discoverableDocuments]) {
      final loc = doc.locationName?.trim();
      if (loc != null && loc.isNotEmpty) {
        locations.add(loc);
      } else if (doc.building != null && doc.building!.trim().isNotEmpty) {
        locations.add(doc.building!.trim());
      } else if (doc.hasPhysicalLocation && doc.displayLocationName != 'Chưa thiết lập vị trí') {
        locations.add(doc.displayLocationName);
      }
    }

    // 2. Bổ sung các địa điểm mẫu phổ biến (Thư viện Tạ Quang Bửu, Thư viện Trung tâm ĐHQG, Lab AI,...)
    for (final preset in PhysicalLocationModel.presetLocations) {
      locations.add(preset.name);
    }

    final sorted = locations.toList();
    sorted.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  /// Đếm số lượng tài liệu đang lưu trữ tại một vị trí cụ thể
  int countDocumentsAtLocation(String locationName) {
    final locQuery = locationName.trim().toLowerCase();
    final allDocs = [..._documents, ..._sharedDocuments, ..._discoverableDocuments];
    return allDocs.where((doc) {
      return (doc.locationName != null && doc.locationName!.toLowerCase().contains(locQuery)) ||
          (doc.physicalLocation != null && doc.physicalLocation!.toLowerCase().contains(locQuery)) ||
          (doc.building != null && doc.building!.toLowerCase().contains(locQuery)) ||
          (doc.displayLocationName.toLowerCase().contains(locQuery));
    }).map((d) => d.id).toSet().length;
  }

  /// Danh sách tài liệu được Recommendation Engine gợi ý thông minh
  List<DocumentRecommendation> get recommendedDocuments {
    return _recommendationService.getRecommendations(
      allDocuments: [..._documents, ..._sharedDocuments],
      userPreferredTags: _userPreferredTags,
      userOwnedDocuments: _documents,
    );
  }

  /// Danh sách tài liệu của người dùng được lọc theo thời gian thực (Category, Tags, Location, Search)
  List<DocumentModel> get filteredDocuments {
    return _documents.where((doc) {
      // 1. Lọc theo danh mục
      final matchesCategory =
          _selectedCategoryId == null ||
          _selectedCategoryId == 'all' ||
          doc.categoryId == _selectedCategoryId;

      if (!matchesCategory) return false;

      // 2. Lọc theo nhiều Tag (Hashtags)
      if (_selectedTags.isNotEmpty) {
        final docNormTags = doc.tags.map((t) => t.replaceAll('#', '').trim().toLowerCase()).toSet();
        if (_matchAllTags) {
          final matchesAll = _selectedTags.every((st) {
            final norm = st.replaceAll('#', '').trim().toLowerCase();
            return docNormTags.contains(norm);
          });
          if (!matchesAll) return false;
        } else {
          final matchesAny = _selectedTags.any((st) {
            final norm = st.replaceAll('#', '').trim().toLowerCase();
            return docNormTags.contains(norm);
          });
          if (!matchesAny) return false;
        }
      }

      // 3. Lọc theo Vị trí lưu trữ vật lý (Location Filter)
      if (_selectedLocation != null && _selectedLocation!.trim().isNotEmpty) {
        final locQuery = _selectedLocation!.trim().toLowerCase();
        final matchesLocation = (doc.locationName != null && doc.locationName!.toLowerCase().contains(locQuery)) ||
            (doc.physicalLocation != null && doc.physicalLocation!.toLowerCase().contains(locQuery)) ||
            (doc.building != null && doc.building!.toLowerCase().contains(locQuery)) ||
            (doc.displayLocationName.toLowerCase().contains(locQuery));
        if (!matchesLocation) return false;
      }

      // 4. Lọc theo từ khóa tìm kiếm (khớp Tiêu đề, Môn học, Tag hoặc Vị trí)
      if (_searchQuery.trim().isEmpty) return true;
      final queryLower = _searchQuery.trim().toLowerCase();
      final titleMatch = doc.title.toLowerCase().contains(queryLower);
      final subjectMatch = doc.subject.toLowerCase().contains(queryLower);
      final tagMatch = doc.tags.any((t) => t.toLowerCase().contains(queryLower));
      final locationMatch = doc.displayLocationName.toLowerCase().contains(queryLower);

      return titleMatch || subjectMatch || tagMatch || locationMatch;
    }).toList();
  }

  /// Danh sách tài liệu ĐƯỢC CHIA SẺ được lọc theo thời gian thực (Category, Tags, Location, Search)
  List<DocumentModel> get filteredSharedDocuments {
    return _sharedDocuments.where((doc) {
      // 1. Lọc theo danh mục
      final matchesCategory =
          _selectedCategoryId == null ||
          _selectedCategoryId == 'all' ||
          doc.categoryId == _selectedCategoryId;

      if (!matchesCategory) return false;

      // 2. Lọc theo nhiều Tag (Hashtags)
      if (_selectedTags.isNotEmpty) {
        final docNormTags = doc.tags.map((t) => t.replaceAll('#', '').trim().toLowerCase()).toSet();
        if (_matchAllTags) {
          final matchesAll = _selectedTags.every((st) {
            final norm = st.replaceAll('#', '').trim().toLowerCase();
            return docNormTags.contains(norm);
          });
          if (!matchesAll) return false;
        } else {
          final matchesAny = _selectedTags.any((st) {
            final norm = st.replaceAll('#', '').trim().toLowerCase();
            return docNormTags.contains(norm);
          });
          if (!matchesAny) return false;
        }
      }

      // 3. Lọc theo Vị trí lưu trữ vật lý (Location Filter)
      if (_selectedLocation != null && _selectedLocation!.trim().isNotEmpty) {
        final locQuery = _selectedLocation!.trim().toLowerCase();
        final matchesLocation = (doc.locationName != null && doc.locationName!.toLowerCase().contains(locQuery)) ||
            (doc.physicalLocation != null && doc.physicalLocation!.toLowerCase().contains(locQuery)) ||
            (doc.building != null && doc.building!.toLowerCase().contains(locQuery)) ||
            (doc.displayLocationName.toLowerCase().contains(locQuery));
        if (!matchesLocation) return false;
      }

      // 4. Lọc theo từ khóa tìm kiếm
      if (_searchQuery.trim().isEmpty) return true;
      final queryLower = _searchQuery.trim().toLowerCase();
      final titleMatch = doc.title.toLowerCase().contains(queryLower);
      final subjectMatch = doc.subject.toLowerCase().contains(queryLower);
      final tagMatch = doc.tags.any((t) => t.toLowerCase().contains(queryLower));
      final locationMatch = doc.displayLocationName.toLowerCase().contains(queryLower);

      return titleMatch || subjectMatch || tagMatch || locationMatch;
    }).toList();
  }

  /// Danh sách tài liệu KHÁM PHÁ CÔNG KHAI được lọc theo thời gian thực (Category, Tags, Location, Search)
  List<DocumentModel> get filteredDiscoverableDocuments {
    return _discoverableDocuments.where((doc) {
      final matchesCategory =
          _selectedCategoryId == null ||
          _selectedCategoryId == 'all' ||
          doc.categoryId == _selectedCategoryId;

      if (!matchesCategory) return false;

      // 2. Lọc theo nhiều Tag (Hashtags)
      if (_selectedTags.isNotEmpty) {
        final docNormTags = doc.tags.map((t) => t.replaceAll('#', '').trim().toLowerCase()).toSet();
        if (_matchAllTags) {
          final matchesAll = _selectedTags.every((st) {
            final norm = st.replaceAll('#', '').trim().toLowerCase();
            return docNormTags.contains(norm);
          });
          if (!matchesAll) return false;
        } else {
          final matchesAny = _selectedTags.any((st) {
            final norm = st.replaceAll('#', '').trim().toLowerCase();
            return docNormTags.contains(norm);
          });
          if (!matchesAny) return false;
        }
      }

      // 3. Lọc theo Vị trí lưu trữ vật lý (Location Filter)
      if (_selectedLocation != null && _selectedLocation!.trim().isNotEmpty) {
        final locQuery = _selectedLocation!.trim().toLowerCase();
        final matchesLocation = (doc.locationName != null && doc.locationName!.toLowerCase().contains(locQuery)) ||
            (doc.physicalLocation != null && doc.physicalLocation!.toLowerCase().contains(locQuery)) ||
            (doc.building != null && doc.building!.toLowerCase().contains(locQuery)) ||
            (doc.displayLocationName.toLowerCase().contains(locQuery));
        if (!matchesLocation) return false;
      }

      // 4. Lọc theo từ khóa tìm kiếm
      if (_searchQuery.trim().isEmpty) return true;
      final queryLower = _searchQuery.trim().toLowerCase();
      final titleMatch = doc.title.toLowerCase().contains(queryLower);
      final subjectMatch = doc.subject.toLowerCase().contains(queryLower);
      final tagMatch = doc.tags.any((t) => t.toLowerCase().contains(queryLower));
      final locationMatch = doc.displayLocationName.toLowerCase().contains(queryLower);

      return titleMatch || subjectMatch || tagMatch || locationMatch;
    }).toList();
  }

  // --- Khởi tạo và Lắng nghe Reactive Streams ---

  void _initCategoryStream() {
    _isLoading = true;
    notifyListeners();

    // Lắng nghe luồng danh mục
    _categorySubscription = _repository.watchAllCategories().listen(
      (cats) {
        _categories = cats.isNotEmpty ? cats : CategoryModel.defaultCategories;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (err) {
        _errorMessage = 'Lỗi nạp danh mục: $err';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Dọn dẹp triệt để trạng thái bộ nhớ và bộ nhớ đệm SQLite cục bộ khi người dùng đăng xuất
  Future<void> onUserSignedOut() async {
    _documentSubscription?.cancel();
    _documentSubscription = null;
    _documents = [];
    _sharedDocuments = [];
    _discoverableDocuments = [];
    _incomingBorrowRequests = [];
    _myBorrowRequests = [];
    _userPreferredTags = [];
    _selectedTags.clear();
    _selectedLocation = null;
    _errorMessage = null;
    _isLoading = false;
    _isLoadingShared = false;
    _isLoadingDiscoverable = false;
    _isLoadingBorrow = false;

    // Xóa sạch toàn bộ tài liệu đã cache trong Drift SQLite để không lưu vết sang tài khoản khác
    try {
      await _repository.clearAllLocalDocuments();
    } catch (e) {
      debugPrint('[DocumentProvider] Cảnh báo dọn dẹp Drift cache khi đăng xuất: $e');
    }
    notifyListeners();
  }

  void _handleAuthState(dynamic user) {
    _documentSubscription?.cancel();
    _documentSubscription = null;
    _documents = [];
    _sharedDocuments = [];
    _discoverableDocuments = [];
    _incomingBorrowRequests = [];
    _myBorrowRequests = [];
    _errorMessage = null;

    if (user == null) {
      // Khi đăng xuất: Xóa sạch bộ nhớ đệm cục bộ và KHÔNG lắng nghe SQLite cũ để tránh rò rỉ dữ liệu
      _isLoading = false;
      _isLoadingShared = false;
      _isLoadingDiscoverable = false;
      _repository.clearAllLocalDocuments().catchError((e) {
        debugPrint('[DocumentProvider] Lỗi clearAllLocalDocuments khi đăng xuất: $e');
      });
      notifyListeners();
    } else {
      // Khi đăng nhập tài khoản mới: Xóa ngay cache cũ và đặt trạng thái đang tải
      // Tuyệt đối không hiển thị tài liệu của tài khoản trước trong lúc tải dữ liệu mới
      _isLoading = true;
      _isLoadingShared = true;
      _isLoadingDiscoverable = true;
      notifyListeners();

      _repository.clearAllLocalDocuments().then((_) {
        fetchUserDocuments();
        fetchSharedDocuments();
        fetchDiscoverableDocuments();
      }).catchError((e) {
        debugPrint('[DocumentProvider] Lỗi clearAllLocalDocuments khi chuyển tài khoản: $e');
        fetchUserDocuments();
        fetchSharedDocuments();
        fetchDiscoverableDocuments();
      });
    }
  }

  void _subscribeToLocalDocuments() {
    _documentSubscription = _repository.watchAllDocuments().listen(
      (docs) {
        _documents = docs;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (err) {
        _errorMessage = 'Lỗi nạp tài liệu: $err';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Tải danh sách tài liệu cá nhân của người dùng hiện tại từ Supabase Database (public.documents)
  Future<void> fetchUserDocuments() async {
    final user = FirebaseService.instance.currentUser;
    if (user == null) {
      _documents = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (SupabaseService.instance.isAvailable) {
        // Chỉ gửi truy vấn Supabase khi tài khoản đã có custom claim role = authenticated
        final tokenResult = await user.getIdTokenResult();
        if (tokenResult.claims?['role'] != 'authenticated') {
          debugPrint('[DocumentProvider] Tài khoản chưa có claim role = authenticated. Tạm dừng fetchUserDocuments.');
          _isLoading = false;
          notifyListeners();
          return;
        }

        final cloudDocs = await SupabaseService.instance.fetchUserDocumentsForCurrentUser();
        _documents = cloudDocs;
        _errorMessage = null;

        // Xóa sạch cache cũ trước khi nạp tài liệu mới của tài khoản hiện tại vào Drift SQLite
        await _repository.clearAllLocalDocuments();
        for (final doc in cloudDocs) {
          try {
            await _repository.insertDocument(doc);
          } catch (_) {}
        }
      } else {
        // Chỉ khi Supabase hoàn toàn không khả dụng (chế độ hoàn toàn offline) mới đọc từ local
        _documents = await _repository.getAllDocuments();
        _errorMessage = null;
      }
    } catch (e) {
      debugPrint('[DocumentProvider] Lỗi khi nạp tài liệu từ Supabase: $e');
      _errorMessage = 'Không thể nạp danh sách tài liệu từ Supabase: $e';
      // Không tự động fallback đọc SQLite chung khi online vì có thể làm rò rỉ dữ liệu tài khoản cũ
      _documents = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Thao tác cập nhật bộ lọc và tìm kiếm (Filters & Search) ---

  /// Cập nhật từ khóa tìm kiếm thời gian thực
  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      notifyListeners();
    }
  }

  /// Cập nhật bộ lọc danh mục đã chọn
  void setCategoryFilter(String? categoryId) {
    if (_selectedCategoryId != categoryId) {
      _selectedCategoryId = categoryId;
      notifyListeners();
    }
  }

  /// Bật/tắt chế độ khớp tất cả tag (AND) hoặc khớp bất kỳ (OR)
  void setMatchAllTags(bool matchAll) {
    if (_matchAllTags != matchAll) {
      _matchAllTags = matchAll;
      notifyListeners();
    }
  }

  /// Bật / Tắt một thẻ Tag cụ thể trong danh sách lọc nhiều tag
  void toggleTagFilter(String tag) {
    final clean = tag.replaceAll('#', '').trim();
    if (clean.isEmpty) return;
    final existing = _selectedTags.firstWhere(
      (t) => t.toLowerCase() == clean.toLowerCase(),
      orElse: () => '',
    );
    if (existing.isNotEmpty) {
      _selectedTags.remove(existing);
    } else {
      _selectedTags.add(clean);
    }
    notifyListeners();
  }

  /// Thêm một thẻ Tag vào bộ lọc
  void addTagFilter(String tag) {
    final clean = tag.replaceAll('#', '').trim();
    if (clean.isEmpty) return;
    if (!_selectedTags.any((t) => t.toLowerCase() == clean.toLowerCase())) {
      _selectedTags.add(clean);
      notifyListeners();
    }
  }

  /// Gỡ bỏ một thẻ Tag khỏi bộ lọc
  void removeTagFilter(String tag) {
    final clean = tag.replaceAll('#', '').trim().toLowerCase();
    _selectedTags.removeWhere((t) => t.replaceAll('#', '').trim().toLowerCase() == clean);
    notifyListeners();
  }

  /// Xóa sạch tất cả các thẻ Tag đang lọc
  void clearTagFilters() {
    if (_selectedTags.isNotEmpty) {
      _selectedTags.clear();
      notifyListeners();
    }
  }

  /// Cập nhật bộ lọc Tag (Tương thích ngược: nếu null thì xóa tất cả, nếu có giá trị thì toggle)
  void setTagFilter(String? tag) {
    if (tag == null) {
      clearTagFilters();
    } else {
      toggleTagFilter(tag);
    }
  }

  /// Cập nhật bộ lọc theo Vị trí lưu trữ vật lý (null hoặc 'all' để xóa lọc)
  void setLocationFilter(String? location) {
    final clean = location?.trim();
    final effective = (clean == null || clean.isEmpty || clean.toLowerCase() == 'all') ? null : clean;
    if (_selectedLocation != effective) {
      _selectedLocation = effective;
      notifyListeners();
    }
  }

  /// Bật/tắt bộ lọc vị trí (nếu đang chọn vị trí này thì bỏ chọn, ngược lại thì chọn)
  void toggleLocationFilter(String location) {
    final clean = location.trim();
    if (_selectedLocation != null && _selectedLocation!.toLowerCase() == clean.toLowerCase()) {
      _selectedLocation = null;
    } else {
      _selectedLocation = clean;
    }
    notifyListeners();
  }

  /// Xóa sạch bộ lọc vị trí
  void clearLocationFilter() {
    if (_selectedLocation != null) {
      _selectedLocation = null;
      notifyListeners();
    }
  }

  /// Cập nhật danh sách thẻ tag sở thích người dùng cho Recommendation Engine
  void setUserPreferredTags(List<String> tags) {
    _userPreferredTags = tags;
    notifyListeners();
  }

  /// Đặt lại toàn bộ bộ lọc về trạng thái ban đầu
  void resetFilters() {
    _searchQuery = '';
    _selectedCategoryId = 'all';
    _selectedTags.clear();
    _selectedLocation = null;
    notifyListeners();
  }

  // --- Thao tác CRUD (Create - Read - Update - Delete) ---

  /// Thêm mới một tài liệu học tập
  Future<void> addDocument(DocumentModel document) async {
    try {
      await _repository.insertDocument(document);
      // Cập nhật ngay lập tức vào danh sách bộ nhớ UI (hiển thị tức thì không cần reload)
      final existingIndex = _documents.indexWhere((d) => d.id == document.id);
      if (existingIndex == -1) {
        _documents = [document, ..._documents];
      } else {
        _documents[existingIndex] = document;
      }
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi khi thêm tài liệu: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Tải danh sách các tài liệu được chia sẻ cho người dùng hiện tại từ Supabase
  Future<void> fetchSharedDocuments() async {
    if (!SupabaseService.instance.isAvailable) return;

    _isLoadingShared = true;
    notifyListeners();

    try {
      final user = FirebaseService.instance.currentUser;
      if (user != null) {
        final tokenResult = await user.getIdTokenResult();
        if (tokenResult.claims?['role'] != 'authenticated') {
          debugPrint('[DocumentProvider] Tài khoản chưa có claim role = authenticated. Tạm dừng fetchSharedDocuments.');
          _isLoadingShared = false;
          notifyListeners();
          return;
        }
      }

      final rawList = await SupabaseService.instance.fetchSharedDocumentsForCurrentUser();
      final borrowedList = await SupabaseService.instance.fetchBorrowedDocumentsForCurrentUser();

      final sharedList = rawList.map((m) {
        return DocumentModel(
          id: m['id'] as String,
          title: m['title'] as String? ?? '',
          subject: m['subject'] as String? ?? '',
          categoryId: m['category_id'] as String? ?? 'all',
          filePathOrUrl: m['storage_path'] as String?,
          notes: m['description'] as String?,
          tags: (m['tags_cache'] != null)
              ? List<String>.from(m['tags_cache'])
              : (m['tags'] != null ? List<String>.from(m['tags']) : const []),
          locationName: m['location_name'] as String?,
          building: m['building'] as String?,
          floor: m['floor'] as String?,
          shelf: m['shelf'] as String?,
          physicalLocation: m['physical_location'] as String?,
          latitude: (m['latitude'] as num?)?.toDouble(),
          longitude: (m['longitude'] as num?)?.toDouble(),
          isAvailableForBorrow: m['is_available_for_borrow'] as bool? ?? (m['is_borrowable'] as bool? ?? true),
          isDiscoverable: m['is_discoverable'] as bool? ?? false,
          isBorrowable: m['is_borrowable'] as bool? ?? (m['is_available_for_borrow'] as bool? ?? false),
          createdDate: m['created_at'] != null
              ? DateTime.tryParse(m['created_at'] as String) ?? DateTime.now()
              : DateTime.now(),
          updatedDate: m['updated_at'] != null
              ? DateTime.tryParse(m['updated_at'] as String) ?? DateTime.now()
              : DateTime.now(),
          userPermissionRole: m['user_permission_role'] as String? ?? 'viewer',
          ownerEmail: m['owner_email'] as String?,
          ownerName: m['owner_name'] as String?,
        );
      }).toList();

      final existingIds = sharedList.map((d) => d.id).toSet();
      for (final bDoc in borrowedList) {
        if (!existingIds.contains(bDoc.id)) {
          sharedList.add(bDoc);
          existingIds.add(bDoc.id);
        }
      }

      _sharedDocuments = sharedList;
      _errorMessage = null;
    } catch (e) {
      debugPrint('[DocumentProvider] Lỗi khi tải tài liệu được chia sẻ và mượn: $e');
    } finally {
      _isLoadingShared = false;
      notifyListeners();
    }
  }

  /// Làm mới toàn bộ dữ liệu từ Supabase (cả tài liệu của tôi, tài liệu được chia sẻ và khám phá)
  Future<void> refreshAll() async {
    await fetchUserDocuments();
    await fetchSharedDocuments();
    await fetchDiscoverableDocuments();
  }

  /// Cập nhật thông tin tài liệu hiện có (xử lý cả Owner và Editor)
  Future<void> updateDocument(DocumentModel document) async {
    try {
      if (document.isEditor) {
        // Người dùng là Editor: Cập nhật metadata và location trên Supabase qua PostgREST RLS
        final docUuid = SupabaseDocumentModel.toValidUuid(document.id);
        await SupabaseService.instance.updateDocumentMetadata(
          id: docUuid,
          data: {
            'title': document.title,
            'subject': document.subject,
            'category_id': document.categoryId,
            'description': document.notes,
            'tags_cache': document.tags,
            if (document.locationName != null) 'location_name': document.locationName,
            if (document.building != null) 'building': document.building,
            if (document.floor != null) 'floor': document.floor,
            if (document.shelf != null) 'shelf': document.shelf,
            if (document.physicalLocation != null) 'physical_location': document.physicalLocation,
            if (document.latitude != null) 'latitude': document.latitude,
            if (document.longitude != null) 'longitude': document.longitude,
            if (document.locationNotes != null) 'location_notes': document.locationNotes,
            'is_available_for_borrow': document.isAvailableForBorrow,
          },
        );

        // Cập nhật ngay trong danh sách bộ nhớ _sharedDocuments
        final idx = _sharedDocuments.indexWhere((d) => d.id == document.id);
        if (idx != -1) {
          _sharedDocuments[idx] = document;
        }
        notifyListeners();
      } else {
        // Người dùng là Owner: Cập nhật thông qua Repository chuẩn (Drift SQLite)
        await _repository.updateDocument(document);

        // Đồng bộ dữ liệu mới nhất (bao gồm tags_cache, location, notes) lên Supabase nếu online
        if (SupabaseService.instance.isAvailable) {
          try {
            final docUuid = SupabaseDocumentModel.toValidUuid(document.id);
            await SupabaseService.instance.updateDocumentMetadata(
              id: docUuid,
              data: {
                'title': document.title,
                'subject': document.subject,
                'category_id': document.categoryId,
                'description': document.notes,
                'tags_cache': document.tags,
                if (document.locationName != null) 'location_name': document.locationName,
                if (document.building != null) 'building': document.building,
                if (document.floor != null) 'floor': document.floor,
                if (document.shelf != null) 'shelf': document.shelf,
                if (document.physicalLocation != null) 'physical_location': document.physicalLocation,
                if (document.latitude != null) 'latitude': document.latitude,
                if (document.longitude != null) 'longitude': document.longitude,
                if (document.locationNotes != null) 'location_notes': document.locationNotes,
                'is_available_for_borrow': document.isAvailableForBorrow,
                'is_discoverable': document.isDiscoverable,
                'is_borrowable': document.isBorrowable,
              },
            );
          } catch (e) {
            debugPrint('[DocumentProvider] Lưu ý: không thể đồng bộ metadata lên Supabase ngay lúc này: $e');
          }
        }

        final idx = _documents.indexWhere((d) => d.id == document.id);
        if (idx != -1) {
          _documents[idx] = document;
        }
        _errorMessage = null;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'Lỗi khi cập nhật tài liệu: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Xóa tài liệu theo ID với quy trình đồng bộ an toàn:
  /// 0. Kiểm tra thông tin trước khi xóa: id, storage_path, owner_id, Firebase UID, bucket.
  /// 1. Xóa tệp vật lý trên Storage (nếu có tệp).
  /// 2. Xóa metadata trên Supabase public.documents.
  /// 3. Xóa trên Cloud Firestore và Drift SQLite cục bộ.
  /// 4. Loại bỏ tài liệu khỏi tất cả danh sách hiển thị và gọi notifyListeners() ngay lập tức.
  Future<void> deleteDocument(
    String id, {
    String? storagePath,
    DocumentModel? document,
  }) async {
    final user = FirebaseService.instance.currentUser;
    final docUuid = SupabaseDocumentModel.toValidUuid(id);
    final targetDoc = document ?? _documents.where((d) => d.id == id || d.id == docUuid).firstOrNull;

    // 0. Tra cứu metadata từ Supabase trước khi xóa để lấy đủ storage_path và owner_id
    SupabaseDocumentModel? supabaseDoc;
    if (user != null && SupabaseService.instance.isAvailable) {
      try {
        supabaseDoc = await SupabaseService.instance
            .getDocumentMetadata(docUuid)
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('[DELETE] Tra cứu Supabase metadata trước khi xóa: $e');
      }
    }

    final resolvedStoragePath = (supabaseDoc != null &&
            supabaseDoc.storagePath.isNotEmpty &&
            supabaseDoc.storagePath.startsWith('users/'))
        ? supabaseDoc.storagePath
        : (storagePath != null && storagePath.startsWith('users/')
            ? storagePath
            : (targetDoc?.filePathOrUrl != null && targetDoc!.filePathOrUrl!.startsWith('users/')
                ? targetDoc.filePathOrUrl
                : null));

    final ownerId = supabaseDoc?.ownerId ?? user?.uid ?? 'unknown';

    debugPrint('============================================================');
    debugPrint('[DELETE] BẮT ĐẦU XÓA TÀI LIỆU:');
    debugPrint('[DELETE]   * document.id: $id (UUID: $docUuid)');
    debugPrint('[DELETE]   * document.storage_path: ${resolvedStoragePath ?? "(không có tệp Storage)"}');
    debugPrint('[DELETE]   * document.owner_id: $ownerId');
    debugPrint('[DELETE]   * Firebase Auth UID hiện tại: ${user?.uid}');
    debugPrint('============================================================');

    try {
      // 1. Xóa tệp vật lý trên Storage (Supabase Storage)
      if (user != null && resolvedStoragePath != null && resolvedStoragePath.isNotEmpty) {
        debugPrint('[DELETE] Đang xóa tệp Storage: $resolvedStoragePath');
        try {
          await FirebaseService.instance
              .deleteStorageFile(storagePath: resolvedStoragePath)
              .timeout(const Duration(seconds: 15));
          debugPrint('[DELETE] Storage success: Đã hoàn tất xử lý xóa tệp Storage.');
        } catch (storageErr) {
          debugPrint('[DELETE] Cảnh báo lỗi tệp Storage (tiếp tục xóa metadata): $storageErr');
        }
      } else {
        debugPrint('[DELETE] Bỏ qua xóa Storage (không có tệp đính kèm trên cloud)');
      }

      // 2. Xóa metadata trên Supabase public.documents
      if (user != null && SupabaseService.instance.isAvailable) {
        try {
          await SupabaseService.instance
              .deleteDocumentMetadata(docUuid)
              .timeout(const Duration(seconds: 15));
          debugPrint('[DELETE] Supabase success: Đã xóa metadata $docUuid');
        } catch (supabaseErr) {
          debugPrint('[DELETE] Supabase failure: $supabaseErr');
          _errorMessage = 'Lỗi xóa metadata trên Supabase: $supabaseErr';
          notifyListeners();
          throw StateError(
            'Lỗi khi xóa metadata trên Supabase: $supabaseErr',
          );
        }
      } else {
        debugPrint('[DELETE] Bỏ qua xóa Supabase (chưa đăng nhập hoặc Supabase chưa khả dụng)');
      }

      // 3. Xóa trên Cloud Firestore (No-op)
      if (user != null) {
        await FirebaseService.instance.deleteFirestoreDocument(documentId: id);
      }

      // 4. Xóa trong Drift SQLite cục bộ
      try {
        await _repository.deleteDocument(id);
        if (id != docUuid) {
          await _repository.deleteDocument(docUuid);
        }
      } catch (localErr) {
        debugPrint('[DELETE] Cảnh báo xóa cục bộ Drift SQLite: $localErr');
      }

      // 5. CẬP NHẬT UI STATE NGAY LẬP TỨC
      _documents.removeWhere((doc) => doc.id == id || doc.id == docUuid);
      _sharedDocuments.removeWhere((doc) => doc.id == id || doc.id == docUuid);
      _discoverableDocuments.removeWhere((doc) => doc.id == id || doc.id == docUuid);
      _errorMessage = null;
      notifyListeners();
      debugPrint('[DELETE] UI state updated: Đã loại bỏ tài liệu $id ($docUuid) khỏi giao diện.');
    } catch (e) {
      _errorMessage = 'Lỗi khi xóa tài liệu: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Làm mới thủ công toàn bộ dữ liệu từ Supabase Database
  Future<void> refresh() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final user = FirebaseService.instance.currentUser;
      if (user == null) {
        _documents = await _repository.getAllDocuments();
      } else {
        await fetchUserDocuments();
        await fetchSharedDocuments();
      }
      _categories = await _repository.getAllCategories();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Lỗi làm mới dữ liệu: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Thao tác Quản lý Khám phá tài liệu (Discovery) ---

  /// Tải danh sách tài liệu công khai được phép khám phá
  Future<void> fetchDiscoverableDocuments({
    String? search,
    String? subject,
    String? categoryId,
    String? tag,
  }) async {
    _isLoadingDiscoverable = true;
    notifyListeners();
    try {
      final docs = await SupabaseService.instance.fetchDiscoverableDocuments(
        search: search ?? _searchQuery,
        subject: subject,
        categoryId: categoryId ?? _selectedCategoryId,
        tag: tag ?? selectedTag,
      );
      _discoverableDocuments = docs;
    } catch (e) {
      debugPrint('[DocumentProvider] Lỗi khi nạp danh sách khám phá: $e');
    } finally {
      _isLoadingDiscoverable = false;
      notifyListeners();
    }
  }

  // --- Thao tác Quản lý Mượn / Trả tài liệu (Borrow Requests) ---

  /// Tải danh sách yêu cầu mượn gửi đến tôi và yêu cầu tôi đã gửi
  Future<void> fetchBorrowRequests(String userId) async {
    _isLoadingBorrow = true;
    notifyListeners();
    try {
      final incoming = await SupabaseService.instance.fetchIncomingBorrowRequests(userId);
      final myReqs = await SupabaseService.instance.fetchMyBorrowRequests(userId);
      _incomingBorrowRequests = incoming;
      _myBorrowRequests = myReqs;
    } catch (e) {
      debugPrint('[DocumentProvider] Lỗi khi nạp borrow requests: $e');
    } finally {
      _isLoadingBorrow = false;
      notifyListeners();
    }
  }

  /// Gửi yêu cầu mượn tài liệu mới (1, 3, 7, 14 ngày)
  Future<BorrowRequestModel> createBorrowRequest({
    required String documentId,
    required String documentTitle,
    required String requesterId,
    required String requesterEmail,
    String? requesterName,
    required String ownerId,
    DateTime? dueDate,
    int requestedDays = 7,
    String? message,
    String? notes,
  }) async {
    final effectiveDays = [1, 3, 7, 14, 30].contains(requestedDays) ? requestedDays : 7;
    final effectiveDue = dueDate ?? DateTime.now().add(Duration(days: effectiveDays));
    final effectiveMsg = message ?? notes;

    final req = await SupabaseService.instance.createBorrowRequest(
      documentId: documentId,
      documentTitle: documentTitle,
      borrowerId: requesterId,
      borrowerEmail: requesterEmail,
      borrowerName: requesterName,
      ownerId: ownerId,
      requestedDays: effectiveDays,
      dueDate: effectiveDue,
      message: effectiveMsg,
    );
    _myBorrowRequests = [req, ..._myBorrowRequests.where((r) => r.id != req.id)];
    notifyListeners();
    return req;
  }

  /// Cập nhật trạng thái yêu cầu mượn (duyệt, từ chối, hủy, hoàn trả)
  Future<void> updateBorrowRequestStatus({
    required String requestId,
    required String status,
    String? ownerNotes,
  }) async {
    await SupabaseService.instance.updateBorrowRequestStatus(
      requestId: requestId,
      status: status,
      ownerNotes: ownerNotes,
    );
    // Cập nhật trạng thái cục bộ tức thì
    final inIdx = _incomingBorrowRequests.indexWhere((r) => r.id == requestId);
    if (inIdx != -1) {
      _incomingBorrowRequests[inIdx] = _incomingBorrowRequests[inIdx].copyWith(
        status: status,
        ownerNotes: ownerNotes,
        returnedAt: status == 'returned' ? DateTime.now() : null,
      );
    }
    final myIdx = _myBorrowRequests.indexWhere((r) => r.id == requestId);
    if (myIdx != -1) {
      _myBorrowRequests[myIdx] = _myBorrowRequests[myIdx].copyWith(
        status: status,
        ownerNotes: ownerNotes,
        returnedAt: status == 'returned' ? DateTime.now() : null,
      );
    }
    notifyListeners();
    // Cập nhật lại danh sách tài liệu đang mượn
    fetchSharedDocuments();
  }

  /// Hủy yêu cầu mượn tài liệu (Dành cho người mượn)
  Future<void> cancelBorrowRequest(String requestId) async {
    await updateBorrowRequestStatus(requestId: requestId, status: 'cancelled');
  }

  /// Hoàn trả tài liệu (Người mượn hoặc Chủ sở hữu)
  Future<void> returnBorrowDocument(String requestId) async {
    await updateBorrowRequestStatus(requestId: requestId, status: 'returned');
  }

  /// Phê duyệt yêu cầu mượn (Chủ sở hữu)
  Future<void> approveBorrowRequest(String requestId) async {
    await updateBorrowRequestStatus(requestId: requestId, status: 'approved');
  }

  /// Từ chối yêu cầu mượn (Chủ sở hữu)
  Future<void> rejectBorrowRequest(String requestId, {String? reason}) async {
    await updateBorrowRequestStatus(requestId: requestId, status: 'rejected', ownerNotes: reason);
  }

  @override
  void dispose() {
    _documentSubscription?.cancel();
    _categorySubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}
