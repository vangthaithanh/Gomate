package vn.gomate.common;

import java.time.Instant;
import java.util.*;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;
import org.springframework.security.access.AccessDeniedException;

@RestControllerAdvice
public class Errors {
    public record ErrorBody(Instant timestamp, int status, String code, String message, Map<String, String> fields) {}
    public static ErrorBody body(int status, String code, String message) {
        return new ErrorBody(Instant.now(), status, code, message, Map.of());
    }
    @ExceptionHandler(ApiException.class)
    ResponseEntity<ErrorBody> api(ApiException e) { return ResponseEntity.status(e.status).body(body(e.status, e.code, e.getMessage())); }
    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<ErrorBody> validation(MethodArgumentNotValidException e) {
        Map<String, String> fields = new LinkedHashMap<>();
        e.getBindingResult().getFieldErrors().forEach(f -> fields.put(f.getField(), f.getDefaultMessage()));
        return ResponseEntity.badRequest().body(new ErrorBody(Instant.now(), 400, "VALIDATION_ERROR", "Kiểm tra lại dữ liệu nhập.", fields));
    }
    @ExceptionHandler({HttpMessageNotReadableException.class, MethodArgumentTypeMismatchException.class})
    ResponseEntity<ErrorBody> malformed(Exception e) { return ResponseEntity.badRequest().body(body(400, "INVALID_INPUT", "JSON, mã định danh hoặc kiểu dữ liệu không hợp lệ.")); }
    @ExceptionHandler(DataIntegrityViolationException.class)
    ResponseEntity<ErrorBody> conflict(Exception e) { return ResponseEntity.status(409).body(body(409, "DATA_CONFLICT", "Dữ liệu bị trùng hoặc đang được sử dụng.")); }
    @ExceptionHandler(AccessDeniedException.class)
    ResponseEntity<ErrorBody> denied(Exception e) { return ResponseEntity.status(403).body(body(403, "FORBIDDEN", "Bạn không có quyền thực hiện thao tác này.")); }
    @ExceptionHandler(NoResourceFoundException.class)
    ResponseEntity<ErrorBody> missing(Exception e) { return ResponseEntity.status(404).body(body(404, "NOT_FOUND", "Không tìm thấy API.")); }
    @ExceptionHandler(Exception.class)
    ResponseEntity<ErrorBody> other(Exception e) {
        LoggerFactory.getLogger(Errors.class).error("Unhandled server error", e);
        return ResponseEntity.status(500).body(body(500, "INTERNAL_ERROR", "Lỗi máy chủ. Vui lòng thử lại sau."));
    }
}
