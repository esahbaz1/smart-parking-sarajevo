# Smart Parking Sarajevo

Sistem za pametno upravljanje parkinzima u Sarajevu. Vozač u realnom vremenu vidi slobodna parking mjesta u gradu, navigira do njih, rezerviše mjesto unaprijed i prijavljuje probleme, dok administrator i upravnici parkinga prate stanje sistema kroz zaseban panel. Kako u ovom trenutku ne postoji prava senzorska oprema na parkinzima, sistem uključuje i simulator koji generiše realistične promjene stanja parking mjesta i time omogućava da se cijela aplikacija testira i demonstrira bez ijednog fizičkog uređaja.

## Arhitektura

Projekat je podijeljen u četiri dijela koji rade zajedno, ali se mogu pokretati i razvijati nezavisno jedan od drugog.

**`smart_parking_system/`** je mobilna i web aplikacija napisana u Flutteru - isti kod gradi i za Android i za browser. Koristi flutter_map za prikaz karte, geolocator za GPS poziciju, OSRM za računanje rute do parkinga (sa uputama prevedenim na bosanski jezik), i google_sign_in za prijavu Google nalogom. Ovo je dio koji koriste vozači.

**`smart_parking_backend/`** je Flask servis koji drži svu poslovnu logiku: korisničke naloge i uloge, parkinge i slobodna mjesta, rezervacije, prijave oštećenja, chat poruke i komunikaciju sa bazom podataka. Autentifikacija ide preko JWT tokena (flask-jwt-extended), lozinke se čuvaju hašovane (bcrypt), a komunikacija u realnom vremenu (chat, obavještenja o promjeni stanja parkinga) preko WebSocketa (flask-socketio). Baza podataka je MySQL.

**`admin_panel/`** je samostalna administracijska stranica - čist HTML, CSS i JavaScript, bez ikakvog frameworka i bez build koraka - preko koje administrator i upravnici parkinga prate stanje sistema, pregledaju prijavljene probleme i upravljaju korisnicima.

**`smart_parking_backend/simulator/`** je IoT simulator koji oponaša senzore na parkinzima: generiše dolaske i odlaske vozila i šalje ih kroz sistem baš kao što bi to radila prava senzorska oprema. Kada se stvarni senzori postave, ovaj dio se jednostavno isključi.

## Pokretanje

Postoje dva načina da se sistem pokrene: preko Dockera, kao kompletna cjelina jednom komandom, ili ručno, dio po dio, za razvoj i izmjene koda.

### Preko Dockera (preporučeno)

Ovo podiže bazu, backend, simulator i web dio (Flutter web build i admin panel iza nginxa) kao povezane kontejnere.

```bash
cp docker/.env.example docker/.env
```

Otvoriti `docker/.env` i popuniti lozinke za bazu i `JWT_SECRET_KEY` nasumičnim, dovoljno dugačkim stringom, zatim pokrenuti:

```bash
docker compose --env-file docker/.env up -d --build
```

Nakon pokretanja, aplikacija je dostupna na `http://localhost/`, admin panel na `http://localhost/admin/`, a backend API na `http://localhost/api/`. Status kontejnera i logovi se prate uobičajenim `docker compose ps` i `docker compose logs -f` komandama, a sistem se zaustavlja sa `docker compose down`.

### Ručno, dio po dio

**Baza.** Potrebna je pokrenuta MySQL instanca. Na praznoj bazi pokrenuti `smart_parking_backend/schema.sql`, koji kreira sve tabele, administratorski nalog i nekoliko demo parkinga sa dodijeljenim upravnicima. Ako je baza već postojala prije ovih izmjena, redom pokrenuti i `migration_v2.sql`, `migration_v3.sql`, `migration_v4.sql` i `migration_v4_seed_managers.sql` - svaka migracija je bezbjedna za ponovno pokretanje i ne briše postojeće podatke.

**Backend.** Potreban je Python 3.11 ili noviji.

```bash
cd smart_parking_backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
python app.py
```

U `.env` je potrebno unijeti podatke za konekciju na bazu (`DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`) i JWT ključ. SMTP i Google prijava su opcioni - bez SMTP podataka, verifikacioni kod za registraciju se samo ispisuje u konzoli servera, pa se aplikacija i dalje može testirati bez pravog mail naloga. Backend po defaultu radi na portu 5000.

IoT simulator se pokreće zasebno i nije obavezan za rad aplikacije:

```bash
python simulator/iot_simulator.py
```

**Mobilna i web aplikacija.** Potreban je Flutter SDK.

```bash
cd smart_parking_system
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000/api
```

Za pokretanje na Android emulatoru, backend adresa treba biti `10.0.2.2` umjesto `localhost`, jer je emulator izolovan od hosta. Za pokretanje na pravom telefonu, telefon i računar moraju biti na istoj WiFi mreži, a u `smart_parking_system/lib/core/constants.dart` je potrebno postaviti lokalni IP računara (dobija se pokretanjem `smart_parking_backend/utils/get_ip.py`) u konstantu `_lanIp`. Build za distribuciju ide preko `flutter build apk --release` odnosno `flutter build web`, uz iste `--dart-define` parametre koji pokazuju na stvarnu adresu backenda.

**Admin panel.** Nema build korak.

```bash
cd admin_panel
python -m http.server 8080
```

Otvoriti `http://localhost:8080` u browseru. Adresa backend API-ja se podešava jednom preko `?api=` parametra u URL-u (npr. `http://localhost:8080/?api=http://localhost:5000/api`) i nakon toga se pamti u browseru.

## Nalozi za prijavu

Sistem razlikuje tri uloge: obični korisnik, upravnik parkinga i administrator. Nakon što se `schema.sql` pokrene na praznoj bazi, dostupni su sljedeći demo nalozi:

| Uloga | Email | Lozinka |
|---|---|---|
| Administrator | `admin@smartparking.ba` | `Admin123!` |
| Upravnik (demo, Parking BBI Centar) | `upravnik.bbi@smartparking.ba` | `Admin123!` |

Nakon pokretanja `migration_v4_seed_managers.sql`, svaki parking u bazi koji još nema dodijeljenog upravnika automatski dobija jednog, sa email adresom oblika `upravnik.parking<ID>@smartparking.ba` i istom lozinkom (`Admin123!`). Preporučuje se promjena ovih lozinki nakon prve prijave, direktno kroz admin panel (tab Upravnici → Uredi).

Obični korisnici (vozači) se registruju samostalno kroz aplikaciju; registracija zahtijeva potvrdu email adrese šestocifrenim kodom.

## Konfiguracija

Sve osjetljive vrijednosti (lozinke baze, JWT ključ, SMTP podaci, Google OAuth Client ID) čuvaju se u `.env` fajlovima koji nisu dio repozitorija - `docker/.env.example` i `smart_parking_backend/.env.example` služe kao predlošci. Google prijava i slanje pravih verifikacionih mailova su opcioni; bez podešenog `GOOGLE_CLIENT_ID` dugme za Google prijavu prikazuje jasnu poruku da prijava nije podešena na serveru, umjesto da izgleda neispravno.

## Deploy van lokalne mreže

Svaki od četiri dijela se deployuje nezavisno: backend kao standardan Flask servis uz gunicorn (Procfile je već pripremljen, pogodno za Render, Railway ili sličan servis), MySQL baza preko bilo kog hostovanog MySQL servisa, admin panel i Flutter web build kao statični sadržaj (Netlify, Vercel, Firebase Hosting), a Android aplikacija se builda kao APK. Flutter web i mobilna aplikacija se u tom slučaju buildaju sa `--dart-define=API_BASE_URL=...` i `--dart-define=WS_BASE_URL=...` parametrima koji pokazuju na javno dostupnu adresu backenda.

Za brzo javno dostupan link bez pravog hostinga, sistem pokrenut lokalno preko Dockera može se izložiti internetu preko besplatnog Cloudflare tunela (`cloudflared tunnel --url http://localhost:80` za trenutni test, ili sa vlastitom domenom za trajniju adresu).

## Poznata ograničenja

Ruta do parkinga se računa preko javnog OSRM demo servera, koji ima ograničenje broja zahtjeva i nije namijenjen za produkciju u većem obimu - za to je potrebno hostovati vlastitu OSRM instancu. Premium checkout ekran je simulacija plaćanja (validira broj kartice, datum isteka i CVV, ali ne prolazi kroz pravi platni procesor) jer prava integracija zahtijeva vlastiti trgovački nalog kod dobavljača poput Stripea. AR navigacija radi po principu "AR walking directions" (kamera uživo uz strelicu okrenutu prema GPS/kompas smjeru), ne puni ARCore/ARKit sa 3D mapiranjem prostora, i zahtijeva pravi uređaj - na desktopu i emulatoru automatski prelazi na prikaz bez kamere.

## Struktura repozitorija

```
smart_parking_backend/    Flask API, baza podataka, IoT simulator
smart_parking_system/     Flutter aplikacija (Android + web)
admin_panel/               Administracijski panel
docker/                    Docker konfiguracija i inicijalne SQL skripte
docker-compose.yml         Orkestracija svih servisa
```
