Hai file PEM ở đây là khóa và chứng chỉ tự ký chỉ dùng cho unit test.
Chúng không thuộc Firebase project, không phải service account và không truy cập được dịch vụ thật.
Test dùng Firebase Admin SDK thật nhưng thay kết nối HTTP bằng phản hồi giả lập để kiểm tra chữ ký,
project, issuer, hết hạn, thu hồi token và tài khoản bị khóa/xóa mà không cần mạng hoặc khóa thật.
