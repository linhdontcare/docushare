-- ==============================================================================
-- MIGRATION: 01_init_schema_and_rls.sql (REVISED - V3)
-- DỰ ÁN: EduVault (LDC Edition)
--
-- CÁC NÂNG CẤP VÀ SỬA ĐỔI QUAN TRỌNG TRONG PHIÊN BẢN V3:
--   1. [FIX LỖI 42P01]: Chuẩn hóa thứ tự phụ thuộc chính xác 100%:
--      BƯỚC 1: Extensions
--      BƯỚC 2: Định nghĩa 3 Bảng (users -> documents -> permissions)
--      BƯỚC 3: Indexes
--      BƯỚC 4: Các hàm xác thực & kiểm tra quyền (khi các bảng đã tồn tại)
--      BƯỚC 5: Triggers & Hàm Trigger
--      BƯỚC 6: Bật RLS & Tạo Policies
--      BƯỚC 7: Phân quyền GRANT/REVOKE (Khóa hoàn toàn anon)
--   2. [CHỐNG SPOOFING USER_ID]: Các hàm kiểm tra quyền không nhận p_user_id từ
--      bên ngoài mà tự động trích xuất public.current_user_id() nội bộ:
--      - public.is_current_user_owner(p_doc_id UUID)
--      - public.has_current_user_permission(p_doc_id UUID, p_required_type TEXT)
--      Người dùng không thể truyền user_id của nạn nhân để vượt mặt RLS.
--   3. [CHỐNG RLS RECURSION]: Các hàm kiểm tra quyền chạy SECURITY DEFINER với
--      search_path cố định, truy cập bảng mục tiêu mà không kích hoạt RLS chéo.
--   4. [SIẾT CHẶT QUYỀN ANON]: Thu hồi toàn bộ quyền EXECUTE và bảng khỏi role 'anon'.
--      Chỉ cấp quyền cho role 'authenticated'.
--   5. [SIẾT CHẶT QUYỀN EDITOR]: Trigger enforce_document_update_rules ngăn Editor
--      can thiệp các trường nhạy cảm (owner_id, storage_path, file_name, file_type,
--      file_size, created_at).
--   6. [IDEMPOTENT & NON-DESTRUCTIVE]: Dùng IF NOT EXISTS, CREATE OR REPLACE,
--      DROP POLICY IF EXISTS. Tuyệt đối không xóa bảng hay làm mất dữ liệu cũ.
-- ==============================================================================

-- ==============================================================================
-- BƯỚC 1: KHỞI TẠO EXTENSIONS
-- ==============================================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- BƯỚC 2: TẠO CÁC BẢNG (THEO ĐÚNG THỨ TỰ RÀNG BUỘC KHÓA NGOẠI)
-- ==============================================================================

-- 2.1. BẢNG USERS (Đồng bộ từ Firebase Authentication)
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid TEXT UNIQUE NOT NULL,
  email TEXT UNIQUE NOT NULL,
  display_name TEXT,
  photo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

COMMENT ON TABLE public.users IS 'Thông tin người dùng đồng bộ từ Firebase Auth, định danh khóa chính UUID.';
COMMENT ON COLUMN public.users.firebase_uid IS 'Firebase UID duy nhất được kiểm chứng từ JWT token Google.';

-- 2.2. BẢNG DOCUMENTS (Metadata tài liệu học tập)
CREATE TABLE IF NOT EXISTS public.documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  subject TEXT,
  category_id TEXT DEFAULT 'all' NOT NULL,
  file_name TEXT NOT NULL,
  file_type TEXT NOT NULL,
  file_size BIGINT NOT NULL CHECK (file_size >= 0),
  storage_path TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

COMMENT ON TABLE public.documents IS 'Metadata tài liệu học tập. File nhị phân lưu tại Firebase Storage theo storage_path.';

-- 2.3. BẢNG PERMISSIONS (Phân quyền cộng tác chia sẻ)
CREATE TABLE IF NOT EXISTS public.permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id UUID NOT NULL REFERENCES public.documents(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  permission_type TEXT NOT NULL CHECK (permission_type IN ('viewer', 'editor')),
  granted_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,

  -- Ràng buộc chống tạo bản ghi quyền trùng lặp cho cùng một người dùng trên một tài liệu
  CONSTRAINT unique_document_user_permission UNIQUE (document_id, user_id)
);

COMMENT ON TABLE public.permissions IS 'Bảng phân quyền chia sẻ: viewer (chỉ xem/tải), editor (xem/sửa metadata).';

-- ==============================================================================
-- BƯỚC 3: TẠO INDEXES TỐI ƯU TRUY VẤN
-- ==============================================================================

CREATE INDEX IF NOT EXISTS idx_users_firebase_uid ON public.users(firebase_uid);
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);

CREATE INDEX IF NOT EXISTS idx_documents_owner_id ON public.documents(owner_id);
CREATE INDEX IF NOT EXISTS idx_documents_created_at ON public.documents(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_documents_category_id ON public.documents(category_id);
CREATE INDEX IF NOT EXISTS idx_documents_title ON public.documents(title);
CREATE INDEX IF NOT EXISTS idx_documents_subject ON public.documents(subject);

CREATE INDEX IF NOT EXISTS idx_permissions_doc_user ON public.permissions(document_id, user_id);
CREATE INDEX IF NOT EXISTS idx_permissions_user_id ON public.permissions(user_id);
CREATE INDEX IF NOT EXISTS idx_permissions_doc_id ON public.permissions(document_id);

-- ==============================================================================
-- BƯỚC 4: TẠO CÁC HÀM XÁC THỰC VÀ KIỂM TRA QUYỀN (KHI CÁC BẢNG ĐÃ TỒN TẠI)
-- ==============================================================================

-- 4.1. Trích xuất Firebase UID từ JWT token đã được Supabase Gateway xác minh chữ ký
CREATE OR REPLACE FUNCTION public.firebase_uid()
RETURNS TEXT AS $$
  SELECT COALESCE(
    auth.jwt() ->> 'sub',
    (current_setting('request.jwt.claims', true)::jsonb) ->> 'sub'
  );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

COMMENT ON FUNCTION public.firebase_uid() IS 'Trích xuất an toàn claim sub (Firebase UID) từ JWT được Supabase xác minh.';

-- 4.2. Lấy UUID nội bộ (public.users.id) của người dùng hiện tại
CREATE OR REPLACE FUNCTION public.current_user_id()
RETURNS UUID AS $$
  SELECT id FROM public.users
  WHERE firebase_uid = public.firebase_uid()
    AND public.firebase_uid() IS NOT NULL
  LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

COMMENT ON FUNCTION public.current_user_id() IS 'Tra cứu UUID trong bảng users tương ứng với Firebase UID đã xác thực.';

-- 4.3. Kiểm tra xem người gọi hiện tại có phải là Owner của tài liệu hay không
--      (Không nhận p_user_id từ bên ngoài để chống giả mạo danh tính, chống RLS recursion)
CREATE OR REPLACE FUNCTION public.is_current_user_owner(p_doc_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_caller_id UUID;
BEGIN
  v_caller_id := public.current_user_id();
  IF v_caller_id IS NULL THEN
    RETURN FALSE;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.documents
    WHERE id = p_doc_id AND owner_id = v_caller_id
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

-- 4.4. Kiểm tra xem người gọi hiện tại có quyền hợp lệ trên tài liệu hay không
--      (Tự trích xuất current_user_id(), bypasses permissions RLS chống recursion)
CREATE OR REPLACE FUNCTION public.has_current_user_permission(
  p_doc_id UUID,
  p_required_type TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  v_caller_id UUID;
BEGIN
  v_caller_id := public.current_user_id();
  IF v_caller_id IS NULL THEN
    RETURN FALSE;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.permissions
    WHERE document_id = p_doc_id
      AND user_id = v_caller_id
      AND (p_required_type IS NULL OR permission_type = p_required_type)
  );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

-- 4.5. Hàm RPC kiểm tra quyền tải file tại phía Server
CREATE OR REPLACE FUNCTION public.check_file_access_permission(
  p_document_id UUID
)
RETURNS TABLE (
  has_access BOOLEAN,
  role TEXT,
  storage_path TEXT,
  file_name TEXT
) AS $$
DECLARE
  v_caller_id UUID;
  v_doc RECORD;
  v_perm_type TEXT;
BEGIN
  v_caller_id := public.current_user_id();
  IF v_caller_id IS NULL THEN
    RETURN QUERY SELECT false, NULL::TEXT, NULL::TEXT, NULL::TEXT;
    RETURN;
  END IF;

  SELECT d.id, d.owner_id, d.storage_path, d.file_name
  INTO v_doc
  FROM public.documents d
  WHERE d.id = p_document_id;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, NULL::TEXT, NULL::TEXT, NULL::TEXT;
    RETURN;
  END IF;

  -- 1. Nếu caller là Owner
  IF v_doc.owner_id = v_caller_id THEN
    RETURN QUERY SELECT true, 'owner'::TEXT, v_doc.storage_path, v_doc.file_name;
    RETURN;
  END IF;

  -- 2. Nếu caller có quyền trong permissions
  SELECT p.permission_type INTO v_perm_type
  FROM public.permissions p
  WHERE p.document_id = p_document_id
    AND p.user_id = v_caller_id;

  IF FOUND THEN
    RETURN QUERY SELECT true, v_perm_type, v_doc.storage_path, v_doc.file_name;
    RETURN;
  END IF;

  -- 3. Không có quyền
  RETURN QUERY SELECT false, NULL::TEXT, NULL::TEXT, NULL::TEXT;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

-- ==============================================================================
-- BƯỚC 5: TẠO HÀM TRIGGER VÀ GẮN TRIGGER
-- ==============================================================================

-- 5.1. Trigger cập nhật trường updated_at tự động
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS set_users_updated_at ON public.users;
CREATE TRIGGER set_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_documents_updated_at ON public.documents;
CREATE TRIGGER set_documents_updated_at
  BEFORE UPDATE ON public.documents
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_permissions_updated_at ON public.permissions;
CREATE TRIGGER set_permissions_updated_at
  BEFORE UPDATE ON public.permissions
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 5.2. Trigger kiểm soát chặt chẽ quyền UPDATE tài liệu:
--      - Cấm tuyệt đối thay đổi owner_id.
--      - Editor chỉ được sửa thông tin mô tả/tiêu đề/môn học.
--      - Editor KHÔNG ĐƯỢC sửa storage_path, file_name, file_type, file_size, created_at.
CREATE OR REPLACE FUNCTION public.enforce_document_update_rules()
RETURNS TRIGGER AS $$
DECLARE
  v_caller_id UUID;
  v_is_owner BOOLEAN;
BEGIN
  v_caller_id := public.current_user_id();

  -- 1. Chống chuyển nhượng owner_id trái phép
  IF NEW.owner_id <> OLD.owner_id THEN
    RAISE EXCEPTION 'Bảo mật: Không được phép thay đổi owner_id của tài liệu.';
  END IF;

  -- 2. Kiểm tra vai trò của người gọi
  v_is_owner := (OLD.owner_id = v_caller_id);

  IF NOT v_is_owner THEN
    -- Trường hợp Editor thực hiện sửa: Khóa toàn bộ các trường nhạy cảm về file
    IF NEW.storage_path <> OLD.storage_path THEN
      RAISE EXCEPTION 'Bảo mật: Editor không được phép thay đổi storage_path của tài liệu.';
    END IF;
    IF NEW.file_name <> OLD.file_name THEN
      RAISE EXCEPTION 'Bảo mật: Editor không được phép sửa tên file vật lý (file_name).';
    END IF;
    IF NEW.file_type <> OLD.file_type THEN
      RAISE EXCEPTION 'Bảo mật: Editor không được phép sửa định dạng file (file_type).';
    END IF;
    IF NEW.file_size <> OLD.file_size THEN
      RAISE EXCEPTION 'Bảo mật: Editor không được phép sửa dung lượng file (file_size).';
    END IF;
    IF NEW.created_at <> OLD.created_at THEN
      RAISE EXCEPTION 'Bảo mật: Editor không được phép can thiệp thời gian tạo ban đầu (created_at).';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_enforce_document_update_rules ON public.documents;
CREATE TRIGGER trg_enforce_document_update_rules
  BEFORE UPDATE ON public.documents
  FOR EACH ROW EXECUTE FUNCTION public.enforce_document_update_rules();

-- 5.3. Trigger kiểm tra tính hợp lệ khi cấp quyền chia sẻ:
--      - Cấm cấp quyền cho chính Owner.
--      - Cấm người dùng tự cấp quyền cho chính mình.
--      - Chỉ Owner của tài liệu mới có quyền gán quyền.
CREATE OR REPLACE FUNCTION public.validate_permission_assignment()
RETURNS TRIGGER AS $$
DECLARE
  v_owner_id UUID;
  v_caller_id UUID;
BEGIN
  SELECT owner_id INTO v_owner_id FROM public.documents WHERE id = NEW.document_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tài liệu không tồn tại.';
  END IF;

  -- 1. Owner đã có toàn quyền, cấm tạo bản ghi trong permissions
  IF NEW.user_id = v_owner_id THEN
    RAISE EXCEPTION 'Owner đã có toàn quyền truy cập tài liệu, không thể cấp quyền trong permissions.';
  END IF;

  v_caller_id := public.current_user_id();

  -- 2. Cấm tự cấp quyền cho chính mình
  IF NEW.user_id = v_caller_id THEN
    RAISE EXCEPTION 'Bảo mật: Người dùng không được phép tự cấp quyền cho chính mình.';
  END IF;

  -- 3. Chỉ Owner của tài liệu mới có quyền gán hoặc sửa quyền
  IF v_caller_id <> v_owner_id THEN
    RAISE EXCEPTION 'Bảo mật: Chỉ Owner của tài liệu mới có quyền chia sẻ hoặc thay đổi quyền.';
  END IF;

  NEW.granted_by := v_caller_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_validate_permission_assignment ON public.permissions;
CREATE TRIGGER trg_validate_permission_assignment
  BEFORE INSERT OR UPDATE ON public.permissions
  FOR EACH ROW EXECUTE FUNCTION public.validate_permission_assignment();

-- ==============================================================================
-- BƯỚC 6: BẬT RLS VÀ TẠO POLICIES (CHỐNG RECURSION & CHỐNG GIẢ MẠO)
-- ==============================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- 6.1. RLS POLICIES CHO BẢNG USERS
-- ------------------------------------------------------------------------------

DROP POLICY IF EXISTS "users_select_authenticated" ON public.users;
CREATE POLICY "users_select_authenticated"
  ON public.users
  FOR SELECT
  USING (
    public.firebase_uid() IS NOT NULL
  );

DROP POLICY IF EXISTS "users_insert_self" ON public.users;
CREATE POLICY "users_insert_self"
  ON public.users
  FOR INSERT
  WITH CHECK (
    firebase_uid = public.firebase_uid()
    AND public.firebase_uid() IS NOT NULL
  );

DROP POLICY IF EXISTS "users_update_self" ON public.users;
CREATE POLICY "users_update_self"
  ON public.users
  FOR UPDATE
  USING (
    firebase_uid = public.firebase_uid()
    AND public.firebase_uid() IS NOT NULL
  )
  WITH CHECK (
    firebase_uid = public.firebase_uid()
    AND public.firebase_uid() IS NOT NULL
  );

DROP POLICY IF EXISTS "users_delete_deny" ON public.users;
CREATE POLICY "users_delete_deny"
  ON public.users
  FOR DELETE
  USING (false);

-- ------------------------------------------------------------------------------
-- 6.2. RLS POLICIES CHO BẢNG DOCUMENTS (SỬ DỤNG HÀM HELPER CHỐNG RECURSION)
-- ------------------------------------------------------------------------------

-- SELECT: Xem nếu là Owner hoặc có quyền (Viewer / Editor)
DROP POLICY IF EXISTS "documents_select_authorized" ON public.documents;
CREATE POLICY "documents_select_authorized"
  ON public.documents
  FOR SELECT
  USING (
    owner_id = public.current_user_id()
    OR
    public.has_current_user_permission(id)
  );

-- INSERT: Chỉ tạo tài liệu với chính mình làm Owner
DROP POLICY IF EXISTS "documents_insert_owner" ON public.documents;
CREATE POLICY "documents_insert_owner"
  ON public.documents
  FOR INSERT
  WITH CHECK (
    owner_id = public.current_user_id()
  );

-- UPDATE: Owner được sửa toàn bộ, Editor sửa metadata (được kiểm soát bởi Trigger)
DROP POLICY IF EXISTS "documents_update_owner_and_editor" ON public.documents;
CREATE POLICY "documents_update_owner_and_editor"
  ON public.documents
  FOR UPDATE
  USING (
    owner_id = public.current_user_id()
    OR
    public.has_current_user_permission(id, 'editor')
  )
  WITH CHECK (
    owner_id = public.current_user_id()
    OR
    public.has_current_user_permission(id, 'editor')
  );

-- DELETE: CHỈ DUY NHẤT Owner mới có quyền xóa tài liệu
DROP POLICY IF EXISTS "documents_delete_only_owner" ON public.documents;
CREATE POLICY "documents_delete_only_owner"
  ON public.documents
  FOR DELETE
  USING (
    owner_id = public.current_user_id()
  );

-- ------------------------------------------------------------------------------
-- 6.3. RLS POLICIES CHO BẢNG PERMISSIONS (SỬ DỤNG HÀM HELPER CHỐNG RECURSION)
-- ------------------------------------------------------------------------------

-- SELECT: Người nhận xem quyền của mình, Owner xem toàn bộ danh sách chia sẻ
DROP POLICY IF EXISTS "permissions_select_owner_and_recipient" ON public.permissions;
CREATE POLICY "permissions_select_owner_and_recipient"
  ON public.permissions
  FOR SELECT
  USING (
    user_id = public.current_user_id()
    OR
    public.is_current_user_owner(document_id)
  );

-- INSERT: CHỈ Owner của tài liệu mới được chia sẻ cho người khác
DROP POLICY IF EXISTS "permissions_insert_only_owner" ON public.permissions;
CREATE POLICY "permissions_insert_only_owner"
  ON public.permissions
  FOR INSERT
  WITH CHECK (
    public.is_current_user_owner(document_id)
    AND user_id <> public.current_user_id()
  );

-- UPDATE: CHỈ Owner của tài liệu mới được đổi vai trò (Viewer <-> Editor)
DROP POLICY IF EXISTS "permissions_update_only_owner" ON public.permissions;
CREATE POLICY "permissions_update_only_owner"
  ON public.permissions
  FOR UPDATE
  USING (
    public.is_current_user_owner(document_id)
  )
  WITH CHECK (
    public.is_current_user_owner(document_id)
    AND user_id <> public.current_user_id()
  );

-- DELETE (Thu hồi quyền):
--   - Owner thu hồi quyền của bất kỳ ai trên tài liệu của mình.
--   - Người được chia sẻ có thể tự rời khỏi tài liệu (xóa quyền của chính mình).
DROP POLICY IF EXISTS "permissions_delete_owner_or_self" ON public.permissions;
CREATE POLICY "permissions_delete_owner_or_self"
  ON public.permissions
  FOR DELETE
  USING (
    user_id = public.current_user_id()
    OR
    public.is_current_user_owner(document_id)
  );

-- ==============================================================================
-- BƯỚC 7: THIẾT LẬP QUYỀN TRUY CẬP (GRANT/REVOKE CHẶT CHẼ)
-- ==============================================================================

-- 7.1. Thu hồi toàn bộ quyền từ role 'anon' và 'public'
REVOKE ALL ON TABLE public.users FROM anon, public;
REVOKE ALL ON TABLE public.documents FROM anon, public;
REVOKE ALL ON TABLE public.permissions FROM anon, public;

REVOKE ALL ON FUNCTION public.firebase_uid() FROM anon, public;
REVOKE ALL ON FUNCTION public.current_user_id() FROM anon, public;
REVOKE ALL ON FUNCTION public.is_current_user_owner(UUID) FROM anon, public;
REVOKE ALL ON FUNCTION public.has_current_user_permission(UUID, TEXT) FROM anon, public;
REVOKE ALL ON FUNCTION public.check_file_access_permission(UUID) FROM anon, public;

-- 7.2. Cấp quyền cần thiết cho role 'authenticated' (Người dùng đã đăng nhập Firebase)
GRANT SELECT, INSERT, UPDATE ON TABLE public.users TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.documents TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.permissions TO authenticated;

GRANT EXECUTE ON FUNCTION public.firebase_uid() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_current_user_owner(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_current_user_permission(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_file_access_permission(UUID) TO authenticated;
