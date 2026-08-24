

USE smart_parking_db;


ALTER TABLE users ADD COLUMN email_verified BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN verification_code VARCHAR(10);
ALTER TABLE users ADD COLUMN verification_expires DATETIME;
ALTER TABLE users ADD COLUMN failed_attempts INT NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN locked_until DATETIME;


UPDATE users SET email_verified = TRUE WHERE email_verified = FALSE;

CREATE TABLE IF NOT EXISTS parking_reports (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  user_id       INT NOT NULL,
  parking_id    INT NOT NULL,
  opis          TEXT,
  photo_path    VARCHAR(255),
  status        ENUM('nova','u_obradi','rijesena') NOT NULL DEFAULT 'nova',
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (parking_id) REFERENCES parkings(id) ON DELETE CASCADE,
  INDEX idx_reports_parking (parking_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS parking_chat_messages (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  user_id       INT NOT NULL,
  parking_id    INT NOT NULL,
  sender        ENUM('user','parking') NOT NULL DEFAULT 'user',
  poruka        TEXT NOT NULL,
  procitano     BOOLEAN NOT NULL DEFAULT FALSE,
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

SELECT 'Migracija v2 završena.' AS rezultat;
