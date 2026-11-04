"""Synthetic settings and an in-process client: no .env or external services."""

import asyncio
from contextlib import asynccontextmanager, contextmanager

import httpx

from app.config import Settings

USER_A = "11111111-1111-4111-8111-111111111111"
USER_B = "22222222-2222-4222-8222-222222222222"
TOKEN_A = "synthetic.user-a.token"
TOKEN_B = "synthetic.user-b.token"
KEY = "sb_publishable_synthetic_testing_only"


class LocalClient:
    def __init__(self, runner, client):
        self._runner, self._client = runner, client

    def get(self, *args, **kwargs):
        return self._runner.run(self._client.get(*args, **kwargs))

    def post(self, *args, **kwargs):
        return self._runner.run(self._client.post(*args, **kwargs))


@contextmanager
def local_client(application):
    @asynccontextmanager
    async def started_client():
        async with application.router.lifespan_context(application):
            async with httpx.AsyncClient(
                transport=httpx.ASGITransport(app=application), base_url="http://test",
            ) as client:
                yield client

    with asyncio.Runner() as runner:
        context = started_client()
        client = runner.run(context.__aenter__())
        try:
            yield LocalClient(runner, client)
        finally:
            runner.run(context.__aexit__(None, None, None))


def settings(**updates):
    return Settings(
        _env_file=None,
        **{
            "supabase_url": "https://project.example.invalid",
            "supabase_publishable_key": KEY,
            **updates,
        },
    )
