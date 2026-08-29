CREATE DATABASE IF NOT EXISTS acceptance_test;
CREATE USER IF NOT EXISTS 'acceptance_test'@'%' IDENTIFIED BY 'test_only_password';
ALTER USER 'acceptance_test'@'%' IDENTIFIED BY 'test_only_password';
GRANT ALL PRIVILEGES ON acceptance_test.* TO 'acceptance_test'@'%';
FLUSH PRIVILEGES;
USE acceptance_test;
CREATE TABLE IF NOT EXISTS test_users (
  id BIGINT PRIMARY KEY,
  nickname VARCHAR(100) NOT NULL
);
INSERT INTO test_users (id, nickname) VALUES (1, 'fixed-test-user')
  ON DUPLICATE KEY UPDATE nickname = VALUES(nickname);
