// ==============================================================================
// DOMAIN MODEL: borrow_request_model.dart
// Đại diện cho yêu cầu mượn/trả tài liệu giữa người dùng trong EduVault (LDC Edition)
// Hỗ trợ đầy đủ 6 trạng thái nghiệp vụ TH2:
// pending | approved | rejected | cancelled | returned | expired
// ==============================================================================

class BorrowRequestModel {
  final String id;
  final String documentId;
  final String documentTitle;
  final String borrowerId;
  final String borrowerEmail;
  final String? borrowerName;
  final String ownerId;
  final String? ownerEmail;
  final String? ownerName;
  final String status; // 'pending' | 'approved' | 'rejected' | 'cancelled' | 'returned' | 'expired'
  final int requestedDays; // 1, 3, 7, 14
  final String? message;
  final String? ownerNotes;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final DateTime dueAt;
  final DateTime? returnedAt;
  final DateTime? updatedAt;

  BorrowRequestModel({
    required this.id,
    required this.documentId,
    required this.documentTitle,
    String? borrowerId,
    String? requesterId,
    String? borrowerEmail,
    String? requesterEmail,
    String? borrowerName,
    String? requesterName,
    required this.ownerId,
    this.ownerEmail,
    this.ownerName,
    this.status = 'pending',
    int requestedDays = 7,
    String? message,
    String? notes,
    this.ownerNotes,
    DateTime? requestedAt,
    DateTime? requestDate,
    this.approvedAt,
    DateTime? dueAt,
    DateTime? dueDate,
    DateTime? returnedAt,
    DateTime? returnDate,
    this.updatedAt,
  }) : borrowerId = borrowerId ?? requesterId ?? '',
       borrowerEmail = borrowerEmail ?? requesterEmail ?? '',
       borrowerName = borrowerName ?? requesterName,
       requestedDays = requestedDays,
       message = message ?? notes,
       requestedAt = requestedAt ?? requestDate ?? DateTime.now(),
       dueAt = dueAt ?? dueDate ?? DateTime.now().add(Duration(days: requestedDays)),
       returnedAt = returnedAt ?? returnDate;

  // Alias tương thích ngược cho mã nguồn cũ
  String get requesterId => borrowerId;
  String get requesterEmail => borrowerEmail;
  String? get requesterName => borrowerName;
  DateTime get requestDate => requestedAt;
  DateTime get dueDate => dueAt;
  DateTime? get returnDate => returnedAt;
  String? get notes => message;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
  bool get isReturned => status == 'returned';

  /// Kiểm tra có đang trong trạng thái mượn (được duyệt và chưa trả)
  bool get isCurrentlyBorrowed => isApproved && returnedAt == null;

  /// Kiểm tra xem lượt mượn đã quá hạn hay chưa
  bool get isOverdue {
    if (isReturned || isCancelled) return false;
    if (status == 'expired') return true;
    return isApproved && DateTime.now().isAfter(dueAt);
  }

  bool get isExpired => status == 'expired' || isOverdue;

  /// Hành động được phép thực hiện
  bool get canCancel => isPending;
  bool get canReturn => isApproved && !isReturned && !isOverdue;
  bool get canViewDocument => isApproved && !isReturned && !isOverdue;

  /// Số ngày còn lại trước khi hết hạn (âm nếu quá hạn)
  int get remainingDays {
    if (returnedAt != null) return 0;
    return dueAt.difference(DateTime.now()).inDays;
  }

  int get daysRemaining => remainingDays;

  String get statusLabel {
    if (isOverdue && status == 'approved') return 'Hết hạn mượn';
    switch (status) {
      case 'approved':
        return 'Đang mượn';
      case 'rejected':
        return 'Bị từ chối';
      case 'cancelled':
        return 'Đã hủy';
      case 'returned':
        return 'Đã hoàn trả';
      case 'expired':
        return 'Hết hạn';
      case 'pending':
      default:
        return 'Chờ duyệt';
    }
  }

  String get statusDisplay => statusLabel;

  BorrowRequestModel copyWith({
    String? id,
    String? documentId,
    String? documentTitle,
    String? borrowerId,
    String? borrowerEmail,
    String? borrowerName,
    String? ownerId,
    String? ownerEmail,
    String? ownerName,
    String? status,
    int? requestedDays,
    String? message,
    String? ownerNotes,
    DateTime? requestedAt,
    DateTime? approvedAt,
    DateTime? dueAt,
    DateTime? returnedAt,
    DateTime? updatedAt,
  }) {
    return BorrowRequestModel(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      documentTitle: documentTitle ?? this.documentTitle,
      borrowerId: borrowerId ?? this.borrowerId,
      borrowerEmail: borrowerEmail ?? this.borrowerEmail,
      borrowerName: borrowerName ?? this.borrowerName,
      ownerId: ownerId ?? this.ownerId,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      ownerName: ownerName ?? this.ownerName,
      status: status ?? this.status,
      requestedDays: requestedDays ?? this.requestedDays,
      message: message ?? this.message,
      ownerNotes: ownerNotes ?? this.ownerNotes,
      requestedAt: requestedAt ?? this.requestedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      dueAt: dueAt ?? this.dueAt,
      returnedAt: returnedAt ?? this.returnedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'document_id': documentId,
      'document_title': documentTitle,
      'borrower_id': borrowerId,
      'borrower_email': borrowerEmail,
      'borrower_name': borrowerName,
      'owner_id': ownerId,
      'owner_email': ownerEmail,
      'owner_name': ownerName,
      'status': status,
      'requested_days': requestedDays,
      'message': message,
      'owner_notes': ownerNotes,
      'requested_at': requestedAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'due_at': dueAt.toIso8601String(),
      'returned_at': returnedAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      // Hỗ trợ tương thích ngược
      'requester_id': borrowerId,
      'requester_email': borrowerEmail,
      'requester_name': borrowerName,
      'request_date': requestedAt.toIso8601String(),
      'due_date': dueAt.toIso8601String(),
      'return_date': returnedAt?.toIso8601String(),
      'notes': message,
    };
  }

  Map<String, dynamic> toJsonForInsert() {
    return {
      'id': id,
      'document_id': documentId,
      'borrower_id': borrowerId,
      'requester_id': borrowerId,
      'owner_id': ownerId,
      'status': 'pending',
      'requested_days': requestedDays,
      'message': message,
      'notes': message,
      'requested_at': requestedAt.toIso8601String(),
      'request_date': requestedAt.toIso8601String(),
      'due_at': dueAt.toIso8601String(),
      'due_date': dueAt.toIso8601String(),
    };
  }

  factory BorrowRequestModel.fromJson(Map<String, dynamic> json) {
    final borrowerMap = json['borrower'] as Map<String, dynamic>? ?? json['requester'] as Map<String, dynamic>?;
    final ownerMap = json['owner'] as Map<String, dynamic>?;
    final docMap = json['documents'] as Map<String, dynamic>?;

    final DateTime reqAt = (json['requested_at'] != null
        ? DateTime.tryParse(json['requested_at'] as String)
        : (json['request_date'] != null ? DateTime.tryParse(json['request_date'] as String) : null)) ?? DateTime.now();

    final int reqDays = (json['requested_days'] as num?)?.toInt() ?? 7;

    final DateTime due = (json['due_at'] != null
        ? DateTime.tryParse(json['due_at'] as String)
        : (json['due_date'] != null ? DateTime.tryParse(json['due_date'] as String) : null)) ?? reqAt.add(Duration(days: reqDays));

    return BorrowRequestModel(
      id: json['id'] as String? ?? '',
      documentId: json['document_id'] as String? ?? '',
      documentTitle: json['document_title'] as String? ?? (docMap != null ? docMap['title'] as String? : null) ?? 'Tài liệu',
      borrowerId: json['borrower_id'] as String? ?? json['requester_id'] as String? ?? '',
      borrowerEmail: json['borrower_email'] as String? ?? json['requester_email'] as String? ?? (borrowerMap != null ? borrowerMap['email'] as String? : null) ?? '',
      borrowerName: json['borrower_name'] as String? ?? json['requester_name'] as String? ?? (borrowerMap != null ? borrowerMap['display_name'] as String? : null),
      ownerId: json['owner_id'] as String? ?? '',
      ownerEmail: json['owner_email'] as String? ?? (ownerMap != null ? ownerMap['email'] as String? : null),
      ownerName: json['owner_name'] as String? ?? (ownerMap != null ? ownerMap['display_name'] as String? : null),
      status: json['status'] as String? ?? 'pending',
      requestedDays: reqDays,
      message: json['message'] as String? ?? json['notes'] as String?,
      ownerNotes: json['owner_notes'] as String?,
      requestedAt: reqAt,
      approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at'] as String) : null,
      dueAt: due,
      returnedAt: json['returned_at'] != null
          ? DateTime.tryParse(json['returned_at'] as String)
          : (json['return_date'] != null ? DateTime.tryParse(json['return_date'] as String) : null),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }
}
