// ==============================================================================
// CORE LAYER: Database Connection Helper (Multiplatform)
// Tự động phân giải kết nối Native (Android/iOS/Desktop) hoặc Web (WasmDatabase)
// ==============================================================================

export 'connection/unsupported.dart'
    if (dart.library.ffi) 'connection/native.dart'
    if (dart.library.js_interop) 'connection/web.dart';
