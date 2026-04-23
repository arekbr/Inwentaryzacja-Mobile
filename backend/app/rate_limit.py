"""
Rate limiting via slowapi (per IP).

Limity:
- `/identify` (Claude Opus = $$$): 10/min per IP. Ktoś próbujący wypompować
  konto Anthropic napotyka próg zanim wywali kilka $.
- `/exhibits` POST (zapis do DB + BLOB): 20/min per IP.
- `/similar` (CLIP + LanceDB — tanie, ale DB hit per call): 30/min.
- Pozostałe endpointy (dictionaries, health, exhibit detail): 60/min.

Limity są per-IP, co na LAN (jedna apka za NAT) wystarczy — na publicznym
deploy może wymagać modyfikacji (per-token?), ale token jest współdzielony
w MVP więc per-IP jest sensowne.
"""
from slowapi import Limiter
from slowapi.util import get_remote_address

# Default limit applies gdy handler nie ma swojego @limiter.limit.
limiter = Limiter(key_func=get_remote_address, default_limits=["60/minute"])
