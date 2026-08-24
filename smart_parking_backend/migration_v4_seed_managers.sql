

USE smart_parking_db;

INSERT INTO users (ime, prezime, email, lozinka, telefon, role, email_verified, parking_id)
SELECT
  'Upravnik',
  TRIM(REPLACE(p.naziv, 'Parking ', '')) AS prezime,
  CONCAT('upravnik.parking', p.id, '@smartparking.ba') AS email,
  '$2b$12$.YJ8NIybyVEisAJz1mHHRuPP08csfhOCSXl0TBXGuTFfNy4uB7HEW' AS lozinka,
  CONCAT('+38761', LPAD(p.id, 6, '0')) AS telefon,
  'manager',
  TRUE,
  p.id
FROM parkings p
WHERE NOT EXISTS (
  SELECT 1 FROM users u
  WHERE u.parking_id = p.id AND u.role = 'manager'
);

SELECT
  CONCAT('upravnik.parking', p.id, '@smartparking.ba') AS email,
  p.naziv AS parking,
  'Admin123!' AS lozinka
FROM parkings p
JOIN users u ON u.parking_id = p.id AND u.role = 'manager'
ORDER BY p.id;
