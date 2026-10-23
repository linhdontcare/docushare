-- ==============================================================================
-- MIGRATION: 04_ensure_authenticated_role_grants.sql
-- DỰ ÁN: EduVault (LDC Edition)
--
-- MỤC ĐÍCH:
--   1. Xác nhận và củng cố toàn bộ quyền GRANT cho role `authenticated` trên
--      các bảng: public.users, public.documents, public.permissions.
--   2. Đảm bảo hàm private.firebase_uid() và private.current_user_id() thực thi
--      an toàn với JWT có claim { role: 'authenticated' } từ Firebase Third-Party Auth.
--   3. Đảm bảo RLS policies cho phép bất kỳ tài khoản Google hợp lệ nào đăng nhập
--      được tự động tạo hồ sơ của chính mình trong public.users, đọc danh sách
--      người dùng để phục vụ chia sẻ tài liệu, và quản lý tài liệu của mình.
--   4. Chống tuyệt đối việc giả mạo UID hoặc sửa đổi dữ liệu của người khác.
--
-- CÁCH CHẠY:
--   Copy toàn bộ nội dung file này và chạy trong Supabase SQL Editor (role: postgres).
-- ==============================================================================

BEGIN;

-- 1. Cấp quyền truy cập Schema
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA private TO authenticated;

-- 2. Cấp quyền thao tác bảng dữ liệu cho role authenticated
GRANT SELECT, INSERT, UPDATE ON public.users TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.documents TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.permissions TO authenticated;

-- Thu hồi quyền từ anon và public để đảm bảo bảo mật RLS
REVOKE ALL ON public.users, public.documents, public.permissions FROM PUBLIC, anon;

-- 3. Cập nhật hàm private.firebase_uid() an toàn
CREATE OR REPLACE FUNCTION private.firebase_uid()
RETURNS text LANGUAGE sql STABLE SECURITY INVOKER SET search_path = '' AS $$
  SELECT CASE 
    WHEN (SELECT auth.role()) = 'authenticated'
      THEN NULLIF(COALESCE(
        (SELECT auth.jwt()) ->> 'sub',
        (current_setting('request.jwt.claims', true)::jsonb) ->> 'sub'
      ), '')
    ELSE NULL 
  END;
$$;

-- 4. Cấp quyền thực thi các hàm bảo mật cho authenticated
GRANT EXECUTE ON FUNCTION private.firebase_uid() TO authenticated;
GRANT EXECUTE ON FUNCTION private.current_user_id() TO authenticated;
GRANT EXECUTE ON FUNCTION private.is_owner(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION private.has_permission(uuid, text) TO authenticated;

-- 5. Củng cố các chính sách Row Level Security (RLS) trên public.users
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS users_select ON public.users;
DROP POLICY IF EXISTS users_insert ON public.users;
DROP POLICY IF EXISTS users_update ON public.users;

-- Người dùng đã xác thực được xem danh sách users (để tìm kiếm email khi chia sẻ tài liệu)
CREATE POLICY users_select ON public.users FOR SELECT TO authenticated
  USING (private.firebase_uid() IS NOT NULL);

-- Người dùng chỉ được tạo hồ sơ có firebase_uid trùng với token của chính mình
CREATE POLICY users_insert ON public.users FOR INSERT TO authenticated
  WITH CHECK (firebase_uid = private.firebase_uid() AND private.firebase_uid() IS NOT NULL);

-- Người dùng chỉ được cập nhật hồ sơ của chính mình
CREATE POLICY users_update ON public.users FOR UPDATE TO authenticated
  USING (firebase_uid = private.firebase_uid())
  WITH CHECK (firebase_uid = private.firebase_uid());

COMMIT;
