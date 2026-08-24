import socket

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "localhost"

ip = get_local_ip()

print("=" * 60)
print("  📱 Flutter — API konfiguracija")
print("=" * 60)
print(f"\n  Tvoj lokalni IP: {ip}")
print(f"\n  U Flutter fajlu lib/core/constants.dart")
print(f"  promijeni baseUrl na:\n")
print(f"  static const String baseUrl = 'http://{ip}:5000/api';\n")
print("=" * 60)
print("\n  ⚠️  Laptop i telefon moraju biti na ISTOJ WiFi mreži!")
print()
