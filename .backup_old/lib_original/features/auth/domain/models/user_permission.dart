/// Danh sách quyền hạn chi tiết trong hệ thống DocuShare (RBAC)
enum UserPermission {
  /// Quản trị tài khoản người dùng và gán vai trò
  manageUsers(
    title: 'Quản lý người dùng',
    description: 'Tạo, khóa, kích hoạt và phân quyền tài khoản',
  ),

  /// Cấu hình hệ thống và xem nhật ký kiểm toán (Audit Logs)
  manageSystemSettings(
    title: 'Cấu hình hệ thống',
    description: 'Thiết lập tham số hệ thống, bảo mật và xem lịch sử truy cập',
  ),

  /// Quản lý toàn bộ kho tài liệu (xóa, duyệt xuất bản)
  manageAllDocuments(
    title: 'Quản trị kho tài liệu',
    description: 'Duyệt, chỉnh sửa hoặc xóa bất kỳ tài liệu nào trên hệ thống',
  ),

  /// Tải lên và chia sẻ tài liệu học tập
  uploadDocuments(
    title: 'Tải lên tài liệu',
    description: 'Đăng tải giáo trình, đề thi, bài giảng và tài liệu tham khảo',
  ),

  /// Quản lý vị trí lưu trữ vật lý (kệ, ngăn tủ, QR định vị)
  manageStorageLocations(
    title: 'Quản lý vị trí kho',
    description: 'Định vị ngăn kệ, phòng lưu trữ và tạo mã QR vị trí sách',
  ),

  /// Phê duyệt và xử lý yêu cầu mượn - trả tài liệu
  approveBorrowRequests(
    title: 'Duyệt mượn - trả',
    description: 'Xác nhận cấp phát tài liệu, gia hạn và thu hồi tài liệu',
  ),

  /// Mượn tài liệu vật lý tại thư viện
  borrowPhysicalDocs(
    title: 'Mượn tài liệu',
    description: 'Đăng ký mượn sách giấy, giáo trình trực tiếp từ kho',
  ),

  /// Đọc tài liệu kỹ thuật số trực tuyến & tải file
  readOnlineDocs(
    title: 'Đọc & tải trực tuyến',
    description: 'Xem tài liệu số hóa dạng PDF, Word và tải về thiết bị',
  ),

  /// Tạo liên kết chia sẻ hoặc mã QR tài liệu
  shareDocuments(
    title: 'Chia sẻ tài liệu',
    description: 'Tạo liên kết nhóm học phần, chia sẻ quyền truy cập',
  ),

  /// Đánh giá, bình luận và xếp hạng tài liệu
  writeReviews(
    title: 'Đánh giá & Bình luận',
    description: 'Gửi nhận xét chất lượng tài liệu và tham gia thảo luận',
  );

  final String title;
  final String description;

  const UserPermission({
    required this.title,
    required this.description,
  });
}
