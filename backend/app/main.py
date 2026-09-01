from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.router import api_router
from app.core.config import get_settings
from app.core.exceptions import (
    ApplicationError,
    AuthenticationError,
    ConflictError,
    ForbiddenError,
    NotFoundError,
    RequestValidationError,
)


def create_app() -> FastAPI:
    settings = get_settings()
    application = FastAPI(title=settings.app_name, version="1.0.0")

    if settings.cors_origin_list:
        application.add_middleware(
            CORSMiddleware,
            allow_origins=settings.cors_origin_list,
            allow_credentials=True,
            allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
            allow_headers=["Authorization", "Content-Type"],
        )

    application.include_router(api_router)
    register_exception_handlers(application)
    return application


def register_exception_handlers(application: FastAPI) -> None:
    @application.exception_handler(ApplicationError)
    async def handle_application_error(
        _request: Request, exc: ApplicationError
    ) -> JSONResponse:
        response_status = status.HTTP_400_BAD_REQUEST
        headers: dict[str, str] | None = None
        if isinstance(exc, ConflictError):
            response_status = status.HTTP_409_CONFLICT
        elif isinstance(exc, AuthenticationError):
            response_status = status.HTTP_401_UNAUTHORIZED
            headers = {"WWW-Authenticate": "Bearer"}
        elif isinstance(exc, NotFoundError):
            response_status = status.HTTP_404_NOT_FOUND
        elif isinstance(exc, ForbiddenError):
            response_status = status.HTTP_403_FORBIDDEN
        elif isinstance(exc, RequestValidationError):
            response_status = status.HTTP_422_UNPROCESSABLE_CONTENT
        return JSONResponse(
            status_code=response_status,
            content={"detail": str(exc)},
            headers=headers,
        )


app = create_app()
