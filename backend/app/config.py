"""Load configuration without exposing connection details in errors."""

from pathlib import Path
from urllib.parse import urlsplit

from pydantic import SecretStr, ValidationError, field_validator, model_validator
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
    chatbot_base_url: SecretStr | None = None
    chatbot_service_key: SecretStr | None = None

    @field_validator("chatbot_base_url")
    @classmethod
    def validate_chatbot_url(cls, value: SecretStr | None) -> SecretStr | None:
        if value is None:
            return None
        raw = value.get_secret_value().strip()
        try:
            url = urlsplit(raw)
            port = url.port
            valid = (
                (url.scheme == "https" or (
                    url.scheme == "http" and url.hostname in {"localhost", "127.0.0.1", "::1"}
                ))
                and bool(url.hostname)
                and url.username is None
                and url.password is None
                and url.path in ("", "/")
                and not url.query
                and not url.fragment
                and not any(char.isspace() or ord(char) < 32 for char in raw)
                and (port is None or port > 0)
            )
        except ValueError:
            valid = False
        if not valid:
            raise ValueError("CHATBOT_BASE_URL must be an HTTPS origin or local HTTP origin")
        return SecretStr(raw.rstrip("/"))

    @field_validator("chatbot_service_key")
    @classmethod
    def validate_chatbot_key(cls, value: SecretStr | None) -> SecretStr | None:
        if value is not None:
            key = value.get_secret_value()
            if not 1 <= len(key) <= 256 or any(not 33 <= ord(char) <= 126 for char in key):
                raise ValueError("CHATBOT_SERVICE_KEY must be a nonempty ASCII header value")
        return value

    @model_validator(mode="after")
    def validate_chatbot_pair(self) -> "Settings":
        if (self.chatbot_base_url is None) != (self.chatbot_service_key is None):
            raise ValueError("CHATBOT_BASE_URL and CHATBOT_SERVICE_KEY must be configured together")
        return self

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
            "SUPABASE_PUBLISHABLE_KEY and any CHATBOT_* settings in backend/.env."
        ) from None
