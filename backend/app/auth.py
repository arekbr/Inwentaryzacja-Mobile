from fastapi import Header, HTTPException, status

from app.config import settings


def require_token(authorization: str | None = Header(default=None)) -> None:
    """
    Bearer token auth. Jeśli w .env brak `API_TOKEN`, auth jest wyłączony (dev mode).
    W produkcji ustaw API_TOKEN na silny losowy string.
    """
    if settings.api_token is None:
        return

    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Bearer token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if authorization.removeprefix("Bearer ") != settings.api_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
            headers={"WWW-Authenticate": "Bearer"},
        )
