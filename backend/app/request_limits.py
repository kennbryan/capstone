"""Bound check-in JSON before FastAPI parses it, without logging request data."""

import asyncio
import json

from starlette.responses import JSONResponse

from .auth import MESSAGES

MAX_BODY_BYTES = 4096


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON key")
        result[key] = value
    return result


class CheckInBodyLimit:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http" or scope["path"].rstrip("/") != "/checkins" or scope["method"] != "POST":
            await self.app(scope, receive, send)
            return

        async def reject(status, code):
            response = JSONResponse(
                status_code=status,
                content={"error": code, "message": MESSAGES[code]},
                headers={"Cache-Control": "private, no-store, max-age=0", "Pragma": "no-cache"},
            )
            await response(scope, receive, send)

        types = [v for k, v in scope["headers"] if k.lower() == b"content-type"]
        if len(types) != 1 or types[0].split(b";", 1)[0].strip().lower() != b"application/json":
            await reject(415, "UNSUPPORTED_MEDIA_TYPE")
            return
        chunks, size = [], 0
        try:
            async with asyncio.timeout(10):
                while True:
                    message = await receive()
                    if message["type"] == "http.disconnect":
                        return
                    chunk = message.get("body", b"")
                    size += len(chunk)
                    if size > MAX_BODY_BYTES:
                        await reject(413, "PAYLOAD_TOO_LARGE")
                        return
                    chunks.append(chunk)
                    if not message.get("more_body", False):
                        break
        except TimeoutError:
            await reject(408, "REQUEST_TIMEOUT")
            return

        body = b"".join(chunks)
        try:
            json.loads(body, object_pairs_hook=unique_object)
        except (ValueError, UnicodeError, RecursionError):
            await reject(422, "VALIDATION_ERROR")
            return

        delivered = False

        async def replay():
            nonlocal delivered
            if not delivered:
                delivered = True
                return {"type": "http.request", "body": body, "more_body": False}
            return await receive()

        await self.app(scope, replay, send)
