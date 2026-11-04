"""Run from backend/: python -m uvicorn app.main:app --port 8001."""

import re
from contextlib import asynccontextmanager
from typing import Annotated

import httpx
from fastapi import Depends, FastAPI, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .auth import ApiError, MESSAGES, ProfileService, unauthorized
from .config import Settings, load_settings
from .checkins import CheckInInput, CheckInRange, CheckInResponse, CheckInService
from .request_limits import CheckInBodyLimit
from .schemas import ErrorResponse, MeResponse

bearer = HTTPBearer(auto_error=False)
PRIVATE_HEADERS = {"Cache-Control": "private, no-store, max-age=0", "Pragma": "no-cache"}


def access_token(
    request: Request,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
) -> str:
    if (
        credentials is None
        or len(request.headers.getlist("authorization")) != 1
        or len(credentials.credentials) > 8192
        or re.fullmatch(r"[A-Za-z0-9._~-]+", credentials.credentials) is None
    ):
        raise unauthorized()
    return credentials.credentials


def profile_service(request: Request) -> ProfileService:
    return request.app.state.profile_service


def checkin_service(request: Request) -> CheckInService:
    return request.app.state.checkin_service


def create_app(
    settings: Settings | None = None,
    *,
    transport: httpx.AsyncBaseTransport | None = None,
) -> FastAPI:
    @asynccontextmanager
    async def lifespan(application: FastAPI):
        configured = settings if settings is not None else load_settings()
        async with httpx.AsyncClient(
            timeout=httpx.Timeout(5.0),
            follow_redirects=False,
            trust_env=False,
            limits=httpx.Limits(max_connections=20, max_keepalive_connections=10),
            transport=transport,
        ) as client:
            application.state.profile_service = ProfileService(configured, client)
            application.state.checkin_service = CheckInService(
                configured, client, application.state.profile_service,
            )
            yield

    application = FastAPI(title="MSU Well-being Backend", version="0.2.0", lifespan=lifespan)
    application.add_middleware(CheckInBodyLimit)

    @application.middleware("http")
    async def private_response(request: Request, call_next):
        response = await call_next(request)
        response.headers.update(PRIVATE_HEADERS)
        return response

    @application.exception_handler(ApiError)
    async def api_error_handler(request: Request, error: ApiError):
        headers = dict(PRIVATE_HEADERS)
        if error.status_code == 401:
            headers["WWW-Authenticate"] = "Bearer"
        if error.status_code == 503:
            headers["Retry-After"] = "5"
        return JSONResponse(
            status_code=error.status_code,
            content={"error": error.code, "message": MESSAGES[error.code]},
            headers=headers,
        )

    @application.exception_handler(RequestValidationError)
    async def validation_error_handler(request: Request, error: RequestValidationError):
        # Default FastAPI validation details may echo a private note or token.
        return JSONResponse(
            status_code=422,
            content={"error": "VALIDATION_ERROR", "message": MESSAGES["VALIDATION_ERROR"]},
            headers=PRIVATE_HEADERS,
        )

    @application.get(
        "/me",
        response_model=MeResponse,
        responses={code: {"model": ErrorResponse} for code in (401, 403, 503)},
        summary="Profil pengguna terverifikasi",
    )
    async def me(
        token: Annotated[str, Depends(access_token)],
        service: Annotated[ProfileService, Depends(profile_service)],
    ) -> MeResponse:
        return await service.me(token)

    checkin_errors = {code: {"model": ErrorResponse} for code in (401, 403, 422, 503)}

    @application.get(
        "/checkins", response_model=list[CheckInResponse], response_model_exclude_none=True,
        responses=checkin_errors, summary="Riwayat check-in pengguna sendiri",
        description="Rentang tanggal YYYY-MM-DD inklusif, maksimal 366 hari. Urutan tanggal menaik.",
    )
    async def list_checkins(
        request: Request,
        period: Annotated[CheckInRange, Query()],
        token: Annotated[str, Depends(access_token)],
        service: Annotated[CheckInService, Depends(checkin_service)],
    ) -> list[CheckInResponse]:
        keys = [key for key, _ in request.query_params.multi_items()]
        if len(keys) != len(set(keys)):
            raise ApiError(422, "VALIDATION_ERROR")
        return await service.list(token, period)

    @application.post(
        "/checkins", response_model=CheckInResponse, response_model_exclude_none=True,
        responses={**checkin_errors, **{code: {"model": ErrorResponse} for code in (408, 413, 415)}},
        summary="Simpan atau ganti check-in pengguna sendiri",
        description="Selalu 200 saat berhasil. Tanggal yang sama mengganti mood dan catatan. "
                    "Catatan tidak dikirim/null/kosong menghapus catatan sebelumnya; maksimal 200 karakter.",
    )
    async def save_checkin(
        request: Request,
        body: CheckInInput,
        token: Annotated[str, Depends(access_token)],
        service: Annotated[CheckInService, Depends(checkin_service)],
    ) -> CheckInResponse:
        if request.query_params:
            raise ApiError(422, "VALIDATION_ERROR")
        return await service.save(token, body)

    return application


app = create_app()
