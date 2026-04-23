from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Konfiguracja backendu.

    Secrety (`api_token`, `mariadb_password`, `anthropic_api_key`) **muszą** być
    ustawione w `.env` lub shell env — brak defaultów, bo deploy bez `.env`
    nie powinien cichto startować z rootem/otwartą auth.

    `environment=production` blokuje `dev_mock_identify=true` i wyłącza docs.
    """

    # Środowisko: "development" | "production". Zmienia behawior niektórych feature'ów.
    environment: str = "development"

    # MariaDB (baza zbiory — wspólna z desktopem)
    mariadb_host: str = "127.0.0.1"
    mariadb_port: int = 3306
    mariadb_user: str = "root"
    mariadb_password: str = Field(..., min_length=1)     # wymagane, brak defaultu
    mariadb_database: str = "zbiory"

    # Claude API — wymagane do /identify w trybie realnym
    anthropic_api_key: str | None = None   # None tylko w trybie DEV_MOCK

    # Dev mode — /identify zwraca mockowaną odpowiedź zamiast wołać Anthropic API.
    # BLOKADA: w production=true nie wolno mieć DEV_MOCK_IDENTIFY=true (patrz main.py).
    dev_mock_identify: bool = False

    # Bearer token dla autoryzacji apki mobilnej — wymagane zawsze, nawet w dev.
    # Brak → startup fail. Zapobiega cichemu wyłączeniu auth po deployu bez .env.
    api_token: str = Field(..., min_length=16)

    # LanceDB — indeks CLIP embeddings do similarity search
    lancedb_path: str = "data/lancedb"
    clip_model: str = "ViT-B-32-quickgelu"
    clip_pretrained: str = "openai"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    @property
    def is_production(self) -> bool:
        return self.environment.lower() == "production"


settings = Settings()
