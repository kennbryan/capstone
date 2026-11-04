"""Load configuration without exposing connection details in errors."""

from pathlib import Path
from urllib.parse import urlsplit

from pydantic import SecretStr, ValidationError, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=BACKEND_DIR / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
        hide_input_in_errors=True,
    )

    supabase_url: SecretStr
    supabase_publishable_key: SecretStr

    @field_validator("supabase_url")
    @classmethod
    def validate_url(cls, value: SecretStr) -> SecretStr:
        raw = value.get_secret_value().strip()
        try:
            url = urlsplit(raw)
            valid = (
                url.scheme == "https"
                and bool(url.hostname)
                and url.username is None
                and url.password is None
                and url.path in ("", "/")
                and not url.query
                and not url.fragment
                and not any(char.isspace() for char in raw)
            )
            _ = url.port
        except ValueError:
            valid = False
        if not valid:
            raise ValueError("SUPABASE_URL must be an HTTPS project base URL")
        return SecretStr(raw.rstrip("/"))

    @field_validator("supabase_publishable_key")
    @classmethod
    def validate_key(cls, value: SecretStr) -> SecretStr:
        raw = value.get_secret_value().strip()
        if (
            not raw.startswith("sb_publishable_")
            or len(raw) <= len("sb_publishable_")
            or any(char.isspace() for char in raw)
        ):
            raise ValueError("A Supabase publishable key is required")
        return SecretStr(raw)


def load_settings() -> Settings:
    try:
        return Settings()
    except (ValidationError, OSError, ValueError):
        # Do not chain errors: they can contain environment values.
        raise RuntimeError(
            "Invalid backend configuration. Check SUPABASE_URL and "
            "SUPABASE_PUBLISHABLE_KEY in backend/.env."
        ) from None
