from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
RUNTIME_DIR = ROOT / "runtime"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=ROOT / ".env", extra="ignore")

    openai_api_key: str = ""
    chat_model: str = "gpt-5.4-mini"
    utility_model: str = "gpt-5.4-nano"
    embedding_model: str = "text-embedding-3-small"
    moderation_model: str = "omni-moderation-latest"
    chat_reasoning_effort: str = "low"
    utility_reasoning_effort: str = "low"

    database_url: str = f"sqlite:///{(RUNTIME_DIR / 'chatbot.db').as_posix()}"
    # Postgres (Supabase): tabel chatbot berada di schema ini, dibuat lewat migrations/*.sql.
    database_schema: str = "chatbot"
    # Pada Postgres, tabel tidak dibuat saat startup (ikuti migrasi). Aktifkan hanya untuk uji lokal.
    database_auto_create: bool = False
    service_api_key: str = ""
    bot_name: str = "Teman MSU"

    # Supabase Auth: token login aplikasi diverifikasi ke project ini (hanya publishable key).
    supabase_url: str = ""
    supabase_publishable_key: str = ""

    # Aplikasi mobile (/chatbot/*)
    mobile_demo_tokens: bool = True  # terima token akun demo "demo-session-<userId>"
    cors_origins: str = ""  # contoh: http://localhost:5000 (hanya untuk Flutter web)

    # Retrieval
    retrieval_top_k: int = 4
    retrieval_min_score: float = 0.30

    # Konteks percakapan
    history_turns: int = 10
    memory_update_every: int = 4  # ekstraksi memori setiap N pesan pengguna


@lru_cache
def get_settings() -> Settings:
    return Settings()
