from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.health import DatabaseHealthResponse, HealthResponse
from app.services.health_service import HealthService

router = APIRouter()
DatabaseSession = Annotated[Session, Depends(get_db)]


@router.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse()


@router.get("/health/database", response_model=DatabaseHealthResponse)
def database_health(session: DatabaseSession) -> DatabaseHealthResponse:
    try:
        HealthService(session).check_database()
    except SQLAlchemyError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database unavailable",
        ) from exc
    return DatabaseHealthResponse()
