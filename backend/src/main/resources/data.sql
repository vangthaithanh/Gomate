INSERT INTO users(id, email, password_hash, role, status)
VALUES
 ('11111111-1111-1111-1111-111111111111', 'admin@gomate.local', '$2a$10$xkpNuq4Qf5nFmIwHSll1juqDJtHeA3iQJ3Pgd0tkKCELgUMEp6sDG', 'ADMIN', 'ACTIVE'),
 ('22222222-2222-2222-2222-222222222222', 'demo@gomate.local', '$2a$10$xkpNuq4Qf5nFmIwHSll1juqDJtHeA3iQJ3Pgd0tkKCELgUMEp6sDG', 'USER', 'ACTIVE')
ON CONFLICT (email) DO NOTHING;

INSERT INTO user_profiles(user_id, nickname, nickname_key, full_name, city, bio)
SELECT id, 'admin_gomate', 'admin_gomate', 'GoMate Admin', 'Ho Chi Minh City', 'Tai khoan quan tri demo cho moi truong local.'
FROM users
WHERE email = 'admin@gomate.local'
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO user_profiles(user_id, nickname, nickname_key, full_name, city, bio)
SELECT id, 'demo_gomate', 'demo_gomate', 'GoMate Demo User', 'Da Nang', 'Tai khoan nguoi dung demo cho luong dang nhap/dang ky.'
FROM users
WHERE email = 'demo@gomate.local'
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO user_settings(user_id, onboarding_completed, interest_codes)
SELECT id, TRUE, '["THIEN_NHIEN","AM_THUC","GAN_TOI"]'
FROM users
WHERE email = 'demo@gomate.local'
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO user_settings(user_id, onboarding_completed, interest_codes)
SELECT id, TRUE, '["DANG_HOT","CO_REVIEW"]'
FROM users
WHERE email = 'admin@gomate.local'
ON CONFLICT (user_id) DO NOTHING;
