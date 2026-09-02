"""add church notices

Revision ID: 20260903_0004
Revises: 20260902_0003
Create Date: 2026-09-03
"""
from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "20260903_0004"
down_revision: str | None = "20260902_0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "notices",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("church_id", sa.BigInteger(), nullable=False),
        sa.Column("author_membership_id", sa.BigInteger(), nullable=False),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("is_pinned", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(
            ["church_id"], ["churches.id"], name="fk_notices_church", ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["author_membership_id"],
            ["church_memberships.id"],
            name="fk_notices_author_membership",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_notices"),
    )
    op.create_index(
        "ix_notices_church_pinned_published",
        "notices",
        ["church_id", "is_pinned", "published_at"],
        unique=False,
    )
    op.create_index(
        "ix_notices_author_membership",
        "notices",
        ["author_membership_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_table("notices")
