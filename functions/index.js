// ==============================================================================
// FIREBASE CLOUD FUNCTIONS: DocuShare
// Tự động gán Firebase Custom Claim role = 'authenticated' cho người dùng mới
// ==============================================================================

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const cors = require("cors")({ origin: true });

// Khởi tạo Firebase Admin SDK với Application Default Credentials
admin.initializeApp();

/**
 * 1. HTTPS Cloud Function có hỗ trợ CORS (Dùng cho cả Flutter Web và Android qua HTTP POST)
 * Endpoint: POST https://<region>-<projectId>.cloudfunctions.net/assignUserRole
 * Header bắt buộc: Authorization: Bearer <Firebase_ID_Token>
 */
exports.assignUserRole = functions.https.onRequest((req, res) => {
  return cors(req, res, async () => {
    // Chỉ chấp nhận HTTP POST
    if (req.method !== "POST") {
      return res.status(405).json({
        success: false,
        error: "Phương thức không được hỗ trợ. Chỉ chấp nhận POST.",
      });
    }

    try {
      const authHeader = req.headers.authorization;
      if (!authHeader || !authHeader.startsWith("Bearer ")) {
        return res.status(401).json({
          success: false,
          error: "Unauthorized: Thiếu hoặc sai định dạng Authorization Bearer header.",
        });
      }

      const idToken = authHeader.split("Bearer ")[1].trim();
      if (!idToken) {
        return res.status(401).json({
          success: false,
          error: "Unauthorized: Firebase ID Token rỗng.",
        });
      }

      // 1. Xác minh chữ ký số của Firebase ID Token an toàn qua Admin SDK
      const decodedToken = await admin.auth().verifyIdToken(idToken);
      const callerUid = decodedToken.uid;

      if (!callerUid) {
        return res.status(401).json({
          success: false,
          error: "Unauthorized: Token không chứa UID hợp lệ.",
        });
      }

      // 2. Lấy thông tin user hiện tại từ Firebase Auth để bảo tồn các claims cũ
      const userRecord = await admin.auth().getUser(callerUid);
      const existingClaims = userRecord.customClaims || {};

      // 3. Nếu tài khoản đã có role = 'authenticated' thì bỏ qua (idempotent, không cập nhật lặp lại)
      if (existingClaims.role === "authenticated") {
        console.log(`[assignUserRole] Tài khoản ${userRecord.email} (${callerUid}) đã có claim role = authenticated. Bỏ qua.`);
        return res.status(200).json({
          success: true,
          message: "Tài khoản đã có role = authenticated.",
          uid: callerUid,
          email: userRecord.email,
          role: "authenticated",
          alreadyAssigned: true,
        });
      }

      // 4. Giữ nguyên mọi custom claims hiện có và bổ sung role: 'authenticated'
      // Tuyệt đối không cho client tự truyền UID hay tự cấp các quyền quản trị tùy tiện
      const updatedClaims = {
        ...existingClaims,
        role: "authenticated",
      };

      await admin.auth().setCustomUserClaims(callerUid, updatedClaims);

      console.log(`[assignUserRole] Đã tự động gán role = authenticated cho ${userRecord.email} (${callerUid}) thành công.`);

      return res.status(200).json({
        success: true,
        message: "Gán custom claim role = authenticated thành công.",
        uid: callerUid,
        email: userRecord.email,
        role: "authenticated",
        alreadyAssigned: false,
      });
    } catch (err) {
      console.error("[assignUserRole] Lỗi khi xử lý token hoặc gán claim:", err);
      return res.status(500).json({
        success: false,
        error: `Lỗi xử lý máy chủ: ${err.message || err}`,
      });
    }
  });
});

/**
 * 2. Callable Cloud Function (onCall) - Hỗ trợ chuẩn Firebase Callable Protocol
 */
exports.assignUserRoleCallable = functions.https.onCall(async (data, context) => {
  // Xác minh người gọi đã xác thực
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Yêu cầu chưa được xác thực. Cần truyền Firebase ID Token hợp lệ."
    );
  }

  const callerUid = context.auth.uid;
  const userRecord = await admin.auth().getUser(callerUid);
  const existingClaims = userRecord.customClaims || {};

  if (existingClaims.role === "authenticated") {
    return {
      success: true,
      message: "Tài khoản đã có role = authenticated.",
      uid: callerUid,
      email: userRecord.email,
      role: "authenticated",
      alreadyAssigned: true,
    };
  }

  const updatedClaims = {
    ...existingClaims,
    role: "authenticated",
  };

  await admin.auth().setCustomUserClaims(callerUid, updatedClaims);

  return {
    success: true,
    message: "Gán custom claim role = authenticated thành công.",
    uid: callerUid,
    email: userRecord.email,
    role: "authenticated",
    alreadyAssigned: false,
  };
});
