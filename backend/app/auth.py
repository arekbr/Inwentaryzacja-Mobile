import hmac

from fastapi import Header, HTTPException, status

from app.config import settings


def require_token(authorization: str | None = Header(default=None)) -> None:
    """
    Bearer token auth. `API_TOKEN` jest wymagane w `.env` — przy starcie
    aplikacji brak tej wartości wywali pydantic ValidationError (patrz
    config.py). Nie ma już opcji "auth off".

    Porównanie tokena przez `hmac.compare_digest` — constant-time, eliminuje
    timing attack (kiedyś różnica ~2-3x, mierzalna w logach).
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Bearer token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    provided = authorization.removeprefix("Bearer ").encode("utf-8")
    expected = settings.api_token.encode("utf-8")
    if not hmac.compare_digest(provided, expected):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
            headers={"WWW-Authenticate": "Bearer"},
        )
