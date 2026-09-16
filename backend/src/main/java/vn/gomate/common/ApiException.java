package vn.gomate.common;

public class ApiException extends RuntimeException {
    public final int status;
    public final String code;
    public ApiException(int status, String code, String message) {
        super(message); this.status = status; this.code = code;
    }
    public static ApiException notFound() { return new ApiException(404, "NOT_FOUND", "Không tìm thấy dữ liệu hoặc bạn không có quyền truy cập."); }
    public static ApiException bad(String message) { return new ApiException(400, "INVALID_INPUT", message); }
    public static ApiException denied() { return new ApiException(403, "FORBIDDEN", "Bạn không có quyền thực hiện thao tác này."); }
    public static ApiException unauthorized() { return new ApiException(401, "UNAUTHORIZED", "Phiên đăng nhập không hợp lệ hoặc đã hết hạn."); }
}
