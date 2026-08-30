INSERT INTO users (
  id,
  username,
  password_hash,
  nickname,
  birthday,
  school,
  class_name,
  created_at,
  updated_at
) VALUES (
  1001,
  'fixed-test-user',
  '$2a$10$fixedFixtureHashForDatabaseConnectivityOnly00000000000000',
  'Fixed Test User',
  NULL,
  NULL,
  NULL,
  '2026-08-24 00:00:00.000000',
  '2026-08-24 00:00:00.000000'
);
