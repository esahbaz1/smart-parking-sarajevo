

CREATE DATABASE IF NOT EXISTS smart_parking_db
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE smart_parking_db;


CREATE TABLE IF NOT EXISTS users (
  id                    INT AUTO_INCREMENT PRIMARY KEY,
  ime                   VARCHAR(100) NOT NULL,
  prezime               VARCHAR(100) NOT NULL,
  email                 VARCHAR(190) NOT NULL UNIQUE,
  lozinka               VARCHAR(255) NOT NULL,
  telefon               VARCHAR(30),
  premium               BOOLEAN DEFAULT FALSE,
  role                  ENUM('user','admin','manager') NOT NULL DEFAULT 'user',
  
  
  parking_id            INT NULL,
  status                ENUM('active','blocked') NOT NULL DEFAULT 'active',
  
  email_verified        BOOLEAN NOT NULL DEFAULT FALSE,
  verification_code     VARCHAR(10),
  verification_expires  DATETIME,
  
  failed_attempts       INT NOT NULL DEFAULT 0,
  locked_until          DATETIME,
  created_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS vehicles (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  user_id     INT NOT NULL,
  tablice     VARCHAR(20) NOT NULL UNIQUE,
  vrsta       VARCHAR(30) DEFAULT 'automobil',
  marka       VARCHAR(50),
  model       VARCHAR(50),
  boja        VARCHAR(30),
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS parkings (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  naziv            VARCHAR(150) NOT NULL UNIQUE,
  adresa           VARCHAR(255),
  lat              DECIMAL(10,7) NOT NULL,
  lng              DECIMAL(10,7) NOT NULL,
  total_spots      INT NOT NULL DEFAULT 0,
  available_spots  INT NOT NULL DEFAULT 0,
  price_per_hour   DECIMAL(6,2) NOT NULL DEFAULT 2.00,
  lambda_val       DECIMAL(6,3) NOT NULL DEFAULT 1.500,
  mu_val           DECIMAL(6,3) NOT NULL DEFAULT 0.500,
  radno_vrijeme    VARCHAR(30) NOT NULL DEFAULT '00:00 - 24:00',
  aktivno          BOOLEAN NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;


ALTER TABLE users
  ADD CONSTRAINT fk_users_parking
  FOREIGN KEY (parking_id) REFERENCES parkings(id) ON DELETE SET NULL,
  ADD INDEX idx_users_parking (parking_id);


CREATE TABLE IF NOT EXISTS parking_spots (
  id                INT AUTO_INCREMENT PRIMARY KEY,
  parking_id        INT NOT NULL,
  spot_number       VARCHAR(10) NOT NULL,
  zaueto            BOOLEAN NOT NULL DEFAULT FALSE,
  vehicle_tablice   VARCHAR(20),
  zauzeto_od        DATETIME,
  sensor_id         VARCHAR(50),
  FOREIGN KEY (parking_id) REFERENCES parkings(id) ON DELETE CASCADE,
  UNIQUE KEY uq_spot (parking_id, spot_number)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS sensor_logs (
  id            BIGINT AUTO_INCREMENT PRIMARY KEY,
  parking_id    INT NOT NULL,
  spot_id       INT,
  event_type    VARCHAR(20) NOT NULL,
  sensor_data   JSON,
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (parking_id) REFERENCES parkings(id) ON DELETE CASCADE,
  INDEX idx_sensor_parking_time (parking_id, created_at)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS parking_history (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  user_id         INT NOT NULL,
  parking_id      INT NOT NULL,
  ulaz_vrijeme    DATETIME NOT NULL,
  izlaz_vrijeme   DATETIME,
  trajanje_min    INT DEFAULT 0,
  cijena          DECIMAL(8,2) DEFAULT 0,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (parking_id) REFERENCES parkings(id) ON DELETE CASCADE
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS reservations (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  user_id         INT NOT NULL,
  parking_id      INT NOT NULL,
  vehicle_id      INT NOT NULL,
  status          ENUM('confirmed','completed','cancelled') NOT NULL DEFAULT 'confirmed',
  start_time      DATETIME NOT NULL,
  end_time        DATETIME NOT NULL,
  duration_min    INT NOT NULL,
  total_price     DECIMAL(8,2) NOT NULL,
  qr_code         VARCHAR(30) NOT NULL UNIQUE,
  created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (parking_id) REFERENCES parkings(id) ON DELETE CASCADE,
  FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS audit_log (
  id            BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id       INT NULL,
  actor_email   VARCHAR(190),
  action        VARCHAR(60) NOT NULL,       
  details       JSON,
  ip_address    VARCHAR(45),
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
  INDEX idx_audit_time (created_at)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS parking_reports (
  id                INT AUTO_INCREMENT PRIMARY KEY,
  user_id           INT NOT NULL,
  parking_id        INT NOT NULL,
  spot_id           INT NULL,
  spot_number       VARCHAR(10) NULL,
  opis              TEXT,
  photo_path        VARCHAR(255),
  status            ENUM('nova','u_obradi','rijesena') NOT NULL DEFAULT 'nova',
  manager_response  TEXT NULL,
  resolved_at       DATETIME NULL,
  created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (parking_id) REFERENCES parkings(id) ON DELETE CASCADE,
  FOREIGN KEY (spot_id) REFERENCES parking_spots(id) ON DELETE SET NULL,
  INDEX idx_reports_parking (parking_id)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS parking_chat_messages (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  user_id       INT NOT NULL,
  parking_id    INT NOT NULL,
  sender        ENUM('user','parking') NOT NULL DEFAULT 'user',
  poruka        TEXT NOT NULL,
  procitano     BOOLEAN NOT NULL DEFAULT FALSE,
  procitano_admin BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (parking_id) REFERENCES parkings(id) ON DELETE CASCADE,
  INDEX idx_chat_thread (user_id, parking_id, created_at)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS favorites (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  user_id       INT NOT NULL,
  parking_id    INT NOT NULL,
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (parking_id) REFERENCES parkings(id) ON DELETE CASCADE,
  UNIQUE KEY uq_favorite (user_id, parking_id)
) ENGINE=InnoDB;


DROP VIEW IF EXISTS parking_status;
CREATE VIEW parking_status AS
SELECT
  id, naziv, adresa, lat, lng,
  total_spots, available_spots,
  price_per_hour,
  lambda_val AS `lambda`,
  mu_val     AS `mu`,
  radno_vrijeme, aktivno, created_at,
  ROUND(100 * (total_spots - available_spots) / GREATEST(total_spots,1), 1) AS occupancy_pct
FROM parkings;


INSERT INTO users (ime, prezime, email, lozinka, telefon, premium, role, email_verified)
VALUES ('Admin', 'Admin', 'admin@smartparking.ba',
        '$2b$12$.YJ8NIybyVEisAJz1mHHRuPP08csfhOCSXl0TBXGuTFfNy4uB7HEW',
        '+38761000000', TRUE, 'admin', TRUE)
ON DUPLICATE KEY UPDATE role='admin', email_verified=TRUE;


INSERT INTO parkings (naziv, adresa, lat, lng, total_spots, available_spots, price_per_hour, lambda_val, mu_val, radno_vrijeme)
VALUES
('Parking BBI Centar',   'Trg djece Sarajeva bb', 43.858000, 18.413600, 350, 42,  3.0, 2.8, 0.5, '00:00 - 24:00'),
('Parking Skenderija',   'Terezija 1, Sarajevo',  43.853500, 18.420000, 200, 128, 2.0, 1.5, 0.4, '06:00 - 23:00'),
('Parking Baščaršija',   'Bravadžiluk 2, Sarajevo',43.860000, 18.431000, 120, 4,   2.5, 3.2, 0.3, '00:00 - 24:00'),
('Parking City Center',  'Džemala Bijedića 185',  43.849000, 18.395000, 500, 215, 2.0, 2.0, 0.6, '00:00 - 24:00'),
('Parking Hotel Holiday','Zmaja od Bosne 4',      43.847000, 18.389000, 150, 89,  3.5, 1.2, 0.45,'00:00 - 24:00')
ON DUPLICATE KEY UPDATE naziv=naziv;


INSERT INTO users (ime, prezime, email, lozinka, telefon, role, email_verified, parking_id)
SELECT 'Upravnik', slug.prezime, slug.email,
       '$2b$12$.YJ8NIybyVEisAJz1mHHRuPP08csfhOCSXl0TBXGuTFfNy4uB7HEW',
       CONCAT('+3876100000', p.id), 'manager', TRUE, p.id
FROM parkings p
JOIN (
  SELECT 'Parking BBI Centar'      AS naziv, 'BBI'            AS prezime, 'upravnik.bbi@smartparking.ba'         AS email
  UNION ALL SELECT 'Parking Skenderija',    'Skenderija',    'upravnik.skenderija@smartparking.ba'
  UNION ALL SELECT 'Parking Baščaršija',    'Baščaršija',    'upravnik.bascarsija@smartparking.ba'
  UNION ALL SELECT 'Parking City Center',   'City Center',   'upravnik.citycenter@smartparking.ba'
  UNION ALL SELECT 'Parking Hotel Holiday', 'Hotel Holiday', 'upravnik.holiday@smartparking.ba'
) AS slug ON slug.naziv = p.naziv
ON DUPLICATE KEY UPDATE role='manager', parking_id=VALUES(parking_id), email_verified=TRUE;


INSERT INTO parking_spots (parking_id, spot_number, zaueto)
SELECT p.id, CONCAT('A', n.n), FALSE
FROM parkings p, (SELECT 1 n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5
      UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10
      UNION SELECT 11 UNION SELECT 12 UNION SELECT 13 UNION SELECT 14 UNION SELECT 15
      UNION SELECT 16 UNION SELECT 17 UNION SELECT 18 UNION SELECT 19 UNION SELECT 20) n
ON DUPLICATE KEY UPDATE spot_number = spot_number;
