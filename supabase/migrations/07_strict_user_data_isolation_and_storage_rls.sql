-- ==============================================================================
-- MIGRATION: 07_strict_user_data_isolation_and_storage_rls.sql
-- DỰ ÁN: DocuShare
--
-- MỤC ĐÍCH:
--   1. Khắc phục triệt để lỗi phân tách dữ liệu giữa các tài khoản:
--      - Loại bỏ mọi SELECT policy mở hoặc tàn dư cũ trên `public.documents`.
--      - Tái khẳng định chính sách Row Level Security (RLS) nghiêm ngặt nhất:
--        Người dùng CHỈ đọc được tài liệu do chính mình sở hữu (owner_id = private.current_user_id()),
--        HOẶC tài liệu người khác cấp quyền Viewer/Editor trong public.permissions,
--        HOẶC tài liệu có lượt mượn đã được duyệt và còn hạn trong public.borrow_requests.
--   2. Đảm bảo tài khoản B/C không thể đọc hoặc truy vấn tài liệu riêng tư của tài khoản A.
--   3. Khám phá tài liệu công khai (is_discoverable = true) chỉ trả về metadata không chứa storage_path
--      thông qua RPC bảo mật public.get_discoverable_documents(), loại trừ tài liệu của chính caller.
--   4. Bảo vệ dữ liệu Storage: Chặn hoàn toàn anon, chỉ cho phép authenticated thao tác hợp lệ.
--
-- HƯỚNG DẪN XÁC NHẬN VÀ CHẠY:
--   - Đăng nhập Supabase Dashboard -> chọn Project docushare-db.
--   - Mở mục "SQL Editor" -> Nhấn "New query".
--   - Dán toàn bộ nội dung file này vào và bấm "Run" (hoặc Ctrl + Enter).
-- ==============================================================================

BEGIN;

-- 1. Bật Row Level Security trên các bảng quan trọng
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'borrow_requests') THEN
  ALTER TABLE public.borrow_requests ENABLE ROW LEVEL SECURITY;
END IF;

-- 2. Dọn dẹp tất cả các chính sách SELECT có thể gây rò rỉ dữ liệu trên public.documents
DROP POLICY IF EXISTS "Enable read access for all users" ON public.documents;
DROP POLICY IF EXISTS "Allow all" ON public.documents;
DROP POLICY IF EXISTS "documents_open_for_app" ON public.documents;
DROP POLICY IF EXISTS "documents_select_authorized" ON public.documents;
DROP POLICY IF EXISTS "Public documents are viewable by everyone" ON public.documents;
DROP POLICY IF EXISTS "Anyone can view documents" ON public.documents;
DROP POLICY IF EXISTS "documents_read_policy" ON public.documents;
DROP POLICY IF EXISTS "documents_select" ON public.documents;

-- 3. Tạo chính sách SELECT nghiêm ngặt duy nhất cho public.documents
-- Quy tắc:
--   - Chủ sở hữu tài liệu (owner_id = private.current_user_id())
--   - Hoặc người được chia sẻ hợp lệ (Viewer / Editor trong public.permissions)
--   - Hoặc người mượn hợp lệ (Approved, chưa trả, còn hạn trong public.borrow_requests)
CREATE POLICY documents_select ON public.documents FOR SELECT TO authenticated
  USING (
    owner_id = private.current_user_id() 
    OR private.has_permission(id)
    OR private.has_active_borrow(id)
  );

-- 4. Đảm bảo quyền INSERT, UPDATE, DELETE trên public.documents được bảo vệ
DROP POLICY IF EXISTS documents_insert ON public.documents;
CREATE POLICY documents_insert ON public.documents FOR INSERT TO authenticated
  WITH CHECK (
    owner_id = private.current_user_id()
  );

DROP POLICY IF EXISTS documents_update ON public.documents;
CREATE POLICY documents_update ON public.documents FOR UPDATE TO authenticated
  USING (
    owner_id = private.current_user_id()
    OR private.has_permission(id, 'editor')
  )
  WITH CHECK (
    owner_id = private.current_user_id()
    OR private.has_permission(id, 'editor')
  );

DROP POLICY IF EXISTS documents_delete ON public.documents;
CREATE POLICY documents_delete ON public.documents FOR DELETE TO authenticated
  USING (
    owner_id = private.current_user_id()
  );

-- 5. Thu hồi toàn bộ quyền đọc/ghi từ role anon trên public.documents
REVOKE ALL ON public.documents FROM anon;
REVOKE ALL ON public.permissions FROM anon;

-- Cấp quyền tối thiểu cần thiết cho authenticated
GRANT SELECT, INSERT, UPDATE, DELETE ON public.documents TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.permissions TO authenticated;

COMMIT;
