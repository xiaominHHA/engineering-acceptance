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
CREATE TABLE IF NOT EXISTS users (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(100) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  nickname VARCHAR(100) NOT NULL,
  birthday DATE,
  school VARCHAR(150),
  class_name VARCHAR(100),
  created_at TIMESTAMP(6) NOT NULL,
  updated_at TIMESTAMP(6) NOT NULL
);
