-- ============================================================================
-- DocuShare - Schema Supabase cho module Documents + Tagging (phần của Đài)
-- Chạy 1 lần trong Supabase SQL Editor của project nhóm.
--
-- Ghi chú kiến trúc (để viết báo cáo):
--  App đăng nhập bằng Firebase Auth + dùng Supabase ANON KEY (không có
--  Supabase session) nên RLS dùng policy MỞ; logic ai được sửa/xóa tài liệu
--  của ai thực hiện ở tầng app (chỉ chủ sở hữu mới thấy nút Sửa/Xóa).
-- ============================================================================

-- 1. Bảng tài liệu -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public."Documents" (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id    text NOT NULL,                    -- id người đăng (AuthService.currentUser.id)
  owner_email text NOT NULL DEFAULT '',
  title       text NOT NULL,
  author      text NOT NULL DEFAULT '',         -- tác giả / nguồn tài liệu
  category    text NOT NULL DEFAULT 'Khác',
  description text NOT NULL DEFAULT '',
  file_url    text NOT NULL DEFAULT '',         -- public URL trên Supabase Storage
  file_name   text NOT NULL DEFAULT '',
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_documents_owner ON public."Documents"(owner_id);

-- 2. Bảng thẻ tag ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public."Tags" (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name       text UNIQUE NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 3. Bảng nối tài liệu - tag (nhiều - nhiều) -------------------------------------
CREATE TABLE IF NOT EXISTS public."DocumentTags" (
  document_id uuid NOT NULL REFERENCES public."Documents"(id) ON DELETE CASCADE,
  tag_id      uuid NOT NULL REFERENCES public."Tags"(id) ON DELETE CASCADE,
  PRIMARY KEY (document_id, tag_id)
);
CREATE INDEX IF NOT EXISTS idx_doctags_doc ON public."DocumentTags"(document_id);
CREATE INDEX IF NOT EXISTS idx_doctags_tag ON public."DocumentTags"(tag_id);

-- 4. Bật RLS + policy mở ---------------------------------------------------------
ALTER TABLE public."Documents"    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."Tags"         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."DocumentTags" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "documents_open_for_app" ON public."Documents";
DROP POLICY IF EXISTS "tags_open_for_app"      ON public."Tags";
DROP POLICY IF EXISTS "doctags_open_for_app"   ON public."DocumentTags";

CREATE POLICY "documents_open_for_app"
  ON public."Documents" FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "tags_open_for_app"
  ON public."Tags" FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "doctags_open_for_app"
  ON public."DocumentTags" FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);

-- 5. Storage: bucket "documents" (public) -----------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('documents', 'documents', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "documents_open_for_app" ON storage.objects;
CREATE POLICY "documents_open_for_app"
  ON storage.objects FOR ALL TO anon, authenticated
  USING (bucket_id = 'documents') WITH CHECK (bucket_id = 'documents');

-- 6. Nạp lại schema ----------------------------------------------------------------
NOTIFY pgrst, 'reload schema';
