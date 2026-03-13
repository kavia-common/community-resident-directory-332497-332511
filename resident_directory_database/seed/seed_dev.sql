-- Resident Directory - Dev Seed Data
-- Applied by scripts/seed.sh after migrations.

BEGIN;

-- Roles
INSERT INTO app_role (name, description)
VALUES
  ('admin', 'Full administrative access'),
  ('resident', 'Standard resident access')
ON CONFLICT (name) DO NOTHING;

-- Users (password_hash is placeholder; real app should create via backend auth)
-- Note: emails are citext so case-insensitive.
INSERT INTO app_user (email, password_hash, auth_provider, is_active, is_admin, display_name)
VALUES
  ('admin@example.com', 'dev-only-placeholder-hash', 'local', true, true, 'Admin User'),
  ('alex@example.com',  'dev-only-placeholder-hash', 'local', true, false, 'Alex Chen'),
  ('maya@example.com',  'dev-only-placeholder-hash', 'local', true, false, 'Maya Patel')
ON CONFLICT (email) DO NOTHING;

-- Ensure role assignments
INSERT INTO app_user_role (user_id, role_id)
SELECT u.id, r.id
FROM app_user u
JOIN app_role r ON r.name = 'admin'
WHERE u.email = 'admin@example.com'
ON CONFLICT DO NOTHING;

INSERT INTO app_user_role (user_id, role_id)
SELECT u.id, r.id
FROM app_user u
JOIN app_role r ON r.name = 'resident'
WHERE u.email IN ('alex@example.com', 'maya@example.com')
ON CONFLICT DO NOTHING;

-- Resident profiles
INSERT INTO resident_profile (
  user_id, full_name, unit, address_line1, city, state, postal_code, phone, email_public, bio
)
SELECT u.id, 'Alex Chen', 'A-101', '123 Main St', 'Sampletown', 'CA', '90001', '555-0101', 'alex@example.com',
       'Neighbor and community volunteer.'
FROM app_user u
WHERE u.email = 'alex@example.com'
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO resident_profile (
  user_id, full_name, unit, address_line1, city, state, postal_code, phone, email_public, bio
)
SELECT u.id, 'Maya Patel', 'B-202', '123 Main St', 'Sampletown', 'CA', '90001', '555-0202', 'maya@example.com',
       'Enjoys gardening and book club.'
FROM app_user u
WHERE u.email = 'maya@example.com'
ON CONFLICT (user_id) DO NOTHING;

-- Default privacy settings for any profiles that don't yet have them
INSERT INTO resident_privacy_settings (resident_id)
SELECT rp.id
FROM resident_profile rp
LEFT JOIN resident_privacy_settings rps ON rps.resident_id = rp.id
WHERE rps.resident_id IS NULL;

-- Announcements
INSERT INTO announcement (created_by, title, body, is_pinned, visibility, published_at)
SELECT u.id,
       'Welcome to the Resident Directory',
       'This is a dev seed announcement. Use the app to create new announcements and manage profiles.',
       true,
       'all',
       now()
FROM app_user u
WHERE u.email = 'admin@example.com'
ON CONFLICT DO NOTHING;

COMMIT;
