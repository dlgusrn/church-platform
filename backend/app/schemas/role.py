from pydantic import BaseModel


class RoleResponse(BaseModel):
    id: int
    code: str
    name: str
    is_system: bool
    permissions: list[str]
