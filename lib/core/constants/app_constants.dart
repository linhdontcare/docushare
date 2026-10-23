// ==============================================================================
// CORE LAYER: App Constants (Hằng số toàn cục cho ứng dụng)
// Tương tự kiến trúc Cashew: tập trung các hằng số cấu hình, chuỗi danh mục mặc định
// để tránh hardcode và giúp dễ dàng bảo trì hoặc mở rộng sau này.
// ==============================================================================

class AppConstants {
  // Tên file cơ sở dữ liệu SQLite cục bộ
  static const String databaseName = 'eduvault_db';

  // Giới hạn ký tự dữ liệu (tương tự pattern Cashew: NAME_LIMIT, NOTE_LIMIT)
  static const int titleMaxLength = 200;
  static const int subjectMaxLength = 100;
  static const int notesMaxLength = 2000;

  // Danh mục mặc định ban đầu (Initial Categories)
  static const String catLectureNotesId = 'cat_lecture_notes';
  static const String catAssignmentsId = 'cat_assignments';
  static const String catReferencesId = 'cat_references';
  static const String catExamPrepId = 'cat_exam_prep';
  static const String catLabReportsId = 'cat_lab_reports';

  // Nhãn danh mục hiển thị
  static const Map<String, String> defaultCategoryNames = {
    catLectureNotesId: 'Bài giảng & Ghi chú',
    catAssignmentsId: 'Bài tập & Tiểu luận',
    catReferencesId: 'Tài liệu tham khảo',
    catExamPrepId: 'Đề thi & Ôn tập',
    catLabReportsId: 'Báo cáo thực hành',
  };

  // Màu sắc hex tương ứng từng danh mục (UI visual accent)
  static const Map<String, String> defaultCategoryColors = {
    catLectureNotesId: '#2563EB', // Blue
    catAssignmentsId: '#DC2626',  // Red
    catReferencesId: '#059669',   // Emerald
    catExamPrepId: '#D97706',     // Amber
    catLabReportsId: '#7C3AED',   // Purple
  };

  // Icon Material tương ứng
  static const Map<String, String> defaultCategoryIcons = {
    catLectureNotesId: 'menu_book',
    catAssignmentsId: 'assignment',
    catReferencesId: 'bookmark_border',
    catExamPrepId: 'quiz',
    catLabReportsId: 'science',
  };
}
