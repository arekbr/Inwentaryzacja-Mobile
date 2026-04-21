from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # MariaDB (baza zbiory — wspólna z desktopem)
    mariadb_host: str = "127.0.0.1"
    mariadb_port: int = 3306
    mariadb_user: str = "root"
    mariadb_password: str = "mariadb"
    mariadb_database: str = "zbiory"

    # Claude API (do /identify w kolejnym kroku)
    anthropic_api_key: str | None = None

    # Dev mode — /identify zwraca mockowaną odpowiedź zamiast wołać Anthropic API.
    # Oszczędza $ podczas iteracyjnego debugu UI. Ustaw DEV_MOCK_IDENTIFY=true w .env.
    dev_mock_identify: bool = False

    # Bearer token dla autoryzacji apki mobilnej
    api_token: str | None = None

    # LanceDB — indeks CLIP embeddings do similarity search
    lancedb_path: str = "data/lancedb"
    clip_model: str = "ViT-B-32-quickgelu"  # QuickGELU match OpenAI pretrained weights
    clip_pretrained: str = "openai"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )


settings = Settings()
