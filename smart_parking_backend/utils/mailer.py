
import os
import smtplib
import ssl
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart


def _smtp_configured() -> bool:
    return bool(os.getenv('SMTP_HOST') and os.getenv('SMTP_USER') and os.getenv('SMTP_PASSWORD'))


def send_verification_email(to_email: str, ime: str, code: str) -> bool:
    print(f"[MAIL] Verifikacioni kod za {to_email}: {code}")

    if not _smtp_configured():
        print("[MAIL] SMTP nije podešen u .env — email nije fizički poslan "
              "(koristi kod ispisan iznad za testiranje).")
        return False

    host = os.getenv('SMTP_HOST')
    port = int(os.getenv('SMTP_PORT', 587))
    user = os.getenv('SMTP_USER')
    password = os.getenv('SMTP_PASSWORD')
    sender = os.getenv('SMTP_FROM', user)

    msg = MIMEMultipart('alternative')
    msg['Subject'] = 'Smart Parking Sarajevo — potvrda naloga'
    msg['From'] = sender
    msg['To'] = to_email

    text = (
        f"Zdravo {ime},\n\n"
        f"Tvoj verifikacioni kod je: {code}\n"
        f"Kod važi 15 minuta.\n\n"
        f"Ako se nisi registrovao/la na Smart Parking Sarajevo, "
        f"slobodno ignoriši ovaj email.\n"
    )
    html = f"""
    <div style="font-family:Arial,sans-serif;background:#0A0E1A;padding:32px;color:#EEF2FF;">
      <div style="max-width:420px;margin:0 auto;background:#111827;border-radius:16px;padding:32px;">
        <h2 style="color:#00D4FF;margin-top:0;">Smart Parking Sarajevo</h2>
        <p>Zdravo {ime},</p>
        <p>Tvoj verifikacioni kod je:</p>
        <div style="font-size:32px;font-weight:700;letter-spacing:6px;
                    color:#00D4FF;background:#1C2537;border-radius:12px;
                    padding:16px;text-align:center;margin:16px 0;">{code}</div>
        <p style="color:#8B9CC8;font-size:13px;">Kod važi 15 minuta. Ako se nisi
        registrovao/la, slobodno ignoriši ovaj email.</p>
      </div>
    </div>
    """
    msg.attach(MIMEText(text, 'plain'))
    msg.attach(MIMEText(html, 'html'))

    try:
        context = ssl.create_default_context()
        with smtplib.SMTP(host, port, timeout=10) as server:
            server.starttls(context=context)
            server.login(user, password)
            server.sendmail(sender, to_email, msg.as_string())
        return True
    except Exception as e:
        print(f"[MAIL] Greška pri slanju emaila: {e}")
        return False


def send_manager_welcome_email(to_email: str, ime: str, parking_naziv: str, lozinka: str) -> bool:
    print(f"[MAIL] Nalog upravnika za {to_email} (parking: {parking_naziv}) kreiran. Lozinka: {lozinka}")

    if not _smtp_configured():
        print("[MAIL] SMTP nije podešen u .env — email nije fizički poslan.")
        return False

    host = os.getenv('SMTP_HOST')
    port = int(os.getenv('SMTP_PORT', 587))
    user = os.getenv('SMTP_USER')
    password = os.getenv('SMTP_PASSWORD')
    sender = os.getenv('SMTP_FROM', user)

    msg = MIMEMultipart('alternative')
    msg['Subject'] = f'Smart Parking Sarajevo — pristup panelu za "{parking_naziv}"'
    msg['From'] = sender
    msg['To'] = to_email

    text = (
        f"Zdravo {ime},\n\n"
        f"Dodijeljen si kao upravnik parkinga \"{parking_naziv}\" na Smart Parking Sarajevo.\n\n"
        f"Prijava (email): {to_email}\n"
        f"Lozinka: {lozinka}\n\n"
        f"Preporučujemo da lozinku promijeniš nakon prve prijave.\n"
    )
    html = f"""
    <div style="font-family:Arial,sans-serif;background:#0A0E1A;padding:32px;color:#EEF2FF;">
      <div style="max-width:460px;margin:0 auto;background:#111827;border-radius:16px;padding:32px;">
        <h2 style="color:#00D4FF;margin-top:0;">Smart Parking Sarajevo</h2>
        <p>Zdravo {ime},</p>
        <p>Dodijeljen si kao <b>upravnik parkinga</b>:</p>
        <div style="font-size:18px;font-weight:700;color:#00D4FF;background:#1C2537;
                    border-radius:12px;padding:14px;text-align:center;margin:12px 0;">
          {parking_naziv}
        </div>
        <p style="color:#8B9CC8;font-size:13px;">Prijava (email): <b style="color:#EEF2FF;">{to_email}</b><br>
        Lozinka: <b style="color:#EEF2FF;">{lozinka}</b></p>
        <p style="color:#8B9CC8;font-size:13px;">Preporučujemo da lozinku promijeniš nakon prve prijave.</p>
      </div>
    </div>
    """
    msg.attach(MIMEText(text, 'plain'))
    msg.attach(MIMEText(html, 'html'))

    try:
        context = ssl.create_default_context()
        with smtplib.SMTP(host, port, timeout=10) as server:
            server.starttls(context=context)
            server.login(user, password)
            server.sendmail(sender, to_email, msg.as_string())
        return True
    except Exception as e:
        print(f"[MAIL] Greška pri slanju emaila upravniku: {e}")
        return False
