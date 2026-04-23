"""
Security headers middleware — standardowe hardening headery.

HSTS dodaje reverse proxy (Caddy auto, nginx ręcznie). Te headery są
app-level: zapobiegają MIME sniffing, clickjacking, leakowaniu Referer,
blokują embedding jako iframe.
"""
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        # Zapobiega zgadywaniu Content-Type przez przeglądarkę (XSS via response body).
        response.headers["X-Content-Type-Options"] = "nosniff"
        # Blokuje embedding w <iframe> z innych domen (clickjacking).
        response.headers["X-Frame-Options"] = "DENY"
        # Nie wysyłaj Referer z kliknięć out-of-site.
        response.headers["Referrer-Policy"] = "no-referrer"
        # Blokuje legacy XSS auditor w starych przeglądarkach (może cause XS-Leaks).
        response.headers["X-XSS-Protection"] = "0"
        # Blokuje użycie APIs przeglądarki (geolocation, camera etc) gdy iframe.
        response.headers["Permissions-Policy"] = (
            "geolocation=(), camera=(), microphone=(), payment=()"
        )
        return response
