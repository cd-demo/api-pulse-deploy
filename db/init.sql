-- API Pulse bootstrap: registry + two demo tenants (Acme, Globex)

CREATE DATABASE IF NOT EXISTS api_pulse_registry CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS tenant_acme CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS tenant_globex CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'apipulse'@'%' IDENTIFIED BY 'apipulse';
GRANT ALL PRIVILEGES ON api_pulse_registry.* TO 'apipulse'@'%';
GRANT ALL PRIVILEGES ON tenant_acme.* TO 'apipulse'@'%';
GRANT ALL PRIVILEGES ON tenant_globex.* TO 'apipulse'@'%';
FLUSH PRIVILEGES;

USE api_pulse_registry;

CREATE TABLE IF NOT EXISTS tenants (
  id INT AUTO_INCREMENT PRIMARY KEY,
  slug VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(128) NOT NULL,
  db_name VARCHAR(128) NOT NULL UNIQUE,
  theme_color VARCHAR(16) NOT NULL DEFAULT '#0F766E',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO tenants (slug, name, db_name, theme_color) VALUES
  ('acme', 'Acme Corp', 'tenant_acme', '#0F766E'),
  ('globex', 'Globex', 'tenant_globex', '#B45309')
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  db_name = VALUES(db_name),
  theme_color = VALUES(theme_color);

-- Password for both admins: password123
-- hash: $2b$10$OVCxDzhQ4l49WusLNEpvpOMZmueznQb2AwvE5VyGVaxg6HtAOo2kq

USE tenant_acme;

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(32) NOT NULL DEFAULT 'admin',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS api_metrics (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  endpoint VARCHAR(128) NOT NULL,
  latency_ms INT NOT NULL,
  status_code INT NOT NULL,
  recorded_at DATETIME NOT NULL,
  INDEX idx_metrics_recorded (recorded_at),
  INDEX idx_metrics_endpoint (endpoint)
);

CREATE TABLE IF NOT EXISTS uptime_snapshots (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  snapshot_date DATE NOT NULL UNIQUE,
  uptime_pct DECIMAL(5,2) NOT NULL
);

INSERT INTO users (email, password_hash, role) VALUES
  ('admin@acme.demo', '$2b$10$OVCxDzhQ4l49WusLNEpvpOMZmueznQb2AwvE5VyGVaxg6HtAOo2kq', 'admin')
ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash);

INSERT INTO api_metrics (endpoint, latency_ms, status_code, recorded_at) VALUES
  ('/api/users', 82, 200, DATE_SUB(NOW(), INTERVAL 1 HOUR)),
  ('/api/orders', 120, 200, DATE_SUB(NOW(), INTERVAL 2 HOUR)),
  ('/api/payments', 95, 200, DATE_SUB(NOW(), INTERVAL 3 HOUR)),
  ('/api/catalog', 140, 200, DATE_SUB(NOW(), INTERVAL 4 HOUR)),
  ('/api/users', 88, 200, DATE_SUB(NOW(), INTERVAL 5 HOUR)),
  ('/api/orders', 210, 500, DATE_SUB(NOW(), INTERVAL 6 HOUR)),
  ('/api/payments', 76, 200, DATE_SUB(NOW(), INTERVAL 7 HOUR)),
  ('/api/catalog', 101, 200, DATE_SUB(NOW(), INTERVAL 8 HOUR)),
  ('/api/users', 93, 200, DATE_SUB(NOW(), INTERVAL 9 HOUR)),
  ('/api/orders', 110, 200, DATE_SUB(NOW(), INTERVAL 10 HOUR)),
  ('/api/payments', 130, 200, DATE_SUB(NOW(), INTERVAL 11 HOUR)),
  ('/api/catalog', 98, 200, DATE_SUB(NOW(), INTERVAL 12 HOUR)),
  ('/api/users', 85, 200, DATE_SUB(NOW(), INTERVAL 13 HOUR)),
  ('/api/orders', 150, 200, DATE_SUB(NOW(), INTERVAL 14 HOUR)),
  ('/api/payments', 70, 200, DATE_SUB(NOW(), INTERVAL 15 HOUR)),
  ('/api/catalog', 160, 200, DATE_SUB(NOW(), INTERVAL 16 HOUR)),
  ('/api/users', 91, 200, DATE_SUB(NOW(), INTERVAL 17 HOUR)),
  ('/api/orders', 105, 200, DATE_SUB(NOW(), INTERVAL 18 HOUR)),
  ('/api/payments', 180, 500, DATE_SUB(NOW(), INTERVAL 19 HOUR)),
  ('/api/catalog', 112, 200, DATE_SUB(NOW(), INTERVAL 20 HOUR)),
  ('/api/users', 79, 200, DATE_SUB(NOW(), INTERVAL 21 HOUR)),
  ('/api/orders', 125, 200, DATE_SUB(NOW(), INTERVAL 22 HOUR)),
  ('/api/payments', 99, 200, DATE_SUB(NOW(), INTERVAL 23 HOUR)),
  ('/api/catalog', 118, 200, DATE_SUB(NOW(), INTERVAL 24 HOUR));

USE tenant_globex;

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(32) NOT NULL DEFAULT 'admin',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS api_metrics (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  endpoint VARCHAR(128) NOT NULL,
  latency_ms INT NOT NULL,
  status_code INT NOT NULL,
  recorded_at DATETIME NOT NULL,
  INDEX idx_metrics_recorded (recorded_at),
  INDEX idx_metrics_endpoint (endpoint)
);

CREATE TABLE IF NOT EXISTS uptime_snapshots (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  snapshot_date DATE NOT NULL UNIQUE,
  uptime_pct DECIMAL(5,2) NOT NULL
);

INSERT INTO users (email, password_hash, role) VALUES
  ('admin@globex.demo', '$2b$10$OVCxDzhQ4l49WusLNEpvpOMZmueznQb2AwvE5VyGVaxg6HtAOo2kq', 'admin')
ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash);

INSERT INTO api_metrics (endpoint, latency_ms, status_code, recorded_at) VALUES
  ('/api/inventory', 65, 200, DATE_SUB(NOW(), INTERVAL 1 HOUR)),
  ('/api/shipping', 155, 200, DATE_SUB(NOW(), INTERVAL 2 HOUR)),
  ('/api/billing', 200, 200, DATE_SUB(NOW(), INTERVAL 3 HOUR)),
  ('/api/support', 90, 200, DATE_SUB(NOW(), INTERVAL 4 HOUR)),
  ('/api/inventory', 72, 200, DATE_SUB(NOW(), INTERVAL 5 HOUR)),
  ('/api/shipping', 140, 200, DATE_SUB(NOW(), INTERVAL 6 HOUR)),
  ('/api/billing', 175, 500, DATE_SUB(NOW(), INTERVAL 7 HOUR)),
  ('/api/support', 88, 200, DATE_SUB(NOW(), INTERVAL 8 HOUR)),
  ('/api/inventory', 60, 200, DATE_SUB(NOW(), INTERVAL 9 HOUR)),
  ('/api/shipping', 132, 200, DATE_SUB(NOW(), INTERVAL 10 HOUR)),
  ('/api/billing', 168, 200, DATE_SUB(NOW(), INTERVAL 11 HOUR)),
  ('/api/support', 95, 200, DATE_SUB(NOW(), INTERVAL 12 HOUR)),
  ('/api/inventory', 70, 200, DATE_SUB(NOW(), INTERVAL 13 HOUR)),
  ('/api/shipping', 148, 200, DATE_SUB(NOW(), INTERVAL 14 HOUR)),
  ('/api/billing', 190, 200, DATE_SUB(NOW(), INTERVAL 15 HOUR)),
  ('/api/support', 84, 200, DATE_SUB(NOW(), INTERVAL 16 HOUR)),
  ('/api/inventory', 68, 200, DATE_SUB(NOW(), INTERVAL 17 HOUR)),
  ('/api/shipping', 160, 500, DATE_SUB(NOW(), INTERVAL 18 HOUR)),
  ('/api/billing', 172, 200, DATE_SUB(NOW(), INTERVAL 19 HOUR)),
  ('/api/support', 92, 200, DATE_SUB(NOW(), INTERVAL 20 HOUR)),
  ('/api/inventory', 74, 200, DATE_SUB(NOW(), INTERVAL 21 HOUR)),
  ('/api/shipping', 138, 200, DATE_SUB(NOW(), INTERVAL 22 HOUR)),
  ('/api/billing', 185, 200, DATE_SUB(NOW(), INTERVAL 23 HOUR)),
  ('/api/support', 100, 200, DATE_SUB(NOW(), INTERVAL 24 HOUR));
