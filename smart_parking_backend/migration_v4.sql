

USE smart_parking_db;


ALTER TABLE users MODIFY COLUMN role ENUM('user','admin','manager') NOT NULL DEFAULT 'user';

ALTER TABLE users ADD COLUMN parking_id INT NULL;


ALTER TABLE users
  ADD CONSTRAINT fk_users_parking
  FOREIGN KEY (parking_id) REFERENCES parkings(id) ON DELETE SET NULL;

ALTER TABLE users ADD INDEX idx_users_parking (parking_id);


ALTER TABLE parking_reports ADD COLUMN spot_id INT NULL;
ALTER TABLE parking_reports ADD COLUMN spot_number VARCHAR(10) NULL;
ALTER TABLE parking_reports ADD COLUMN manager_response TEXT NULL;
ALTER TABLE parking_reports ADD COLUMN resolved_at DATETIME NULL;

ALTER TABLE parking_reports
  ADD CONSTRAINT fk_reports_spot
  FOREIGN KEY (spot_id) REFERENCES parking_spots(id) ON DELETE SET NULL;

SELECT 'Migracija v4 završena.' AS rezultat;
