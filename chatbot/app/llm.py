"""Pembungkus tipis untuk OpenAI. Pipeline hanya bergantung pada kelas ini,
sehingga penyedia model dapat diganti atau dipalsukan saat pengujian."""

from typing import TypeVar

import numpy as np
from openai import AsyncOpenAI
from pydantic import BaseModel

from .config import Settings

T = TypeVar("T", bound=BaseModel)


class LLMClient:
    def __init__(self, settings: Settings):
        self.settings = settings
        self._client = AsyncOpenAI(api_key=settings.openai_api_key, timeout=30.0, max_retries=2)

    async def structured(
        self,
        schema: type[T],
        system: str,
        messages: list[dict],
        *,
        model: str | None = None,
        reasoning_effort: str | None = None,
    ) -> T:
        """Memanggil model dan mem-parse keluaran ke skema Pydantic (structured output)."""
        model = model or self.settings.chat_model
        kwargs = {}
        effort = reasoning_effort or self.settings.chat_reasoning_effort
        if effort and model.startswith(("gpt-5", "o")):
            kwargs["reasoning_effort"] = effort
        completion = await self._client.chat.completions.parse(
            model=model,
            messages=[{"role": "system", "content": system}, *messages],
            response_format=schema,
            **kwargs,
        )
        message = completion.choices[0].message
        if message.parsed is None:
            raise RuntimeError(f"Model menolak atau gagal mengikuti skema: {message.refusal!r}")
        return message.parsed

    async def embed(self, texts: list[str]) -> np.ndarray:
        vectors = []
        for start in range(0, len(texts), 96):
            batch = texts[start : start + 96]
            response = await self._client.embeddings.create(
                model=self.settings.embedding_model, input=batch
            )
            vectors.extend(item.embedding for item in response.data)
        matrix = np.asarray(vectors, dtype=np.float32)
        return matrix / np.linalg.norm(matrix, axis=1, keepdims=True)

    async def moderate(self, text: str) -> dict:
        response = await self._client.moderations.create(
            model=self.settings.moderation_model, input=text
        )
        result = response.results[0]
        return {
            "flagged": result.flagged,
            "categories": result.categories.model_dump(by_alias=True),
            "scores": result.category_scores.model_dump(by_alias=True),
        }
