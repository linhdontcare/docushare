
-- DocuShare - Module quản lý mượn trả
-- Chỉ tạo cấu trúc bảng, chưa thay đổi dữ liệu hiện có.

CREATE TABLE IF NOT EXISTS public."Borrowings" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    document_id uuid NOT NULL
        REFERENCES public."Documents"(id)
        ON DELETE RESTRICT,

    borrower_id text NOT NULL,
    borrower_name text NOT NULL,

    borrow_date timestamptz NOT NULL DEFAULT now(),
    due_date timestamptz NOT NULL,
    return_date timestamptz,

    status text NOT NULL DEFAULT 'pending'
        CHECK (status IN (
            'pending',
            'borrowed',
            'returned',
            'overdue',
            'rejected'
        )),

    extension_count integer NOT NULL DEFAULT 0
        CHECK (extension_count >= 0),

    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT valid_borrowing_dates
        CHECK (due_date >= borrow_date)
);

CREATE INDEX IF NOT EXISTS idx_borrowings_document
ON public."Borrowings"(document_id);

CREATE INDEX IF NOT EXISTS idx_borrowings_borrower
ON public."Borrowings"(borrower_id);

CREATE INDEX IF NOT EXISTS idx_borrowings_status
ON public."Borrowings"(status);

ALTER TABLE public."Borrowings"
ENABLE ROW LEVEL SECURITY;

-- Chưa tạo policy mở cho anon.
-- Cần xác thực và phân quyền trước khi cho phép
-- ứng dụng đọc hoặc thay đổi phiếu mượn.

NOTIFY pgrst, 'reload schema';
