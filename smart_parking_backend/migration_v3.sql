

USE smart_parking_db;

ALTER TABLE parking_chat_messages
  ADD COLUMN procitano_admin BOOLEAN NOT NULL DEFAULT FALSE;

SELECT 'Migracija v3 završena.' AS rezultat;
