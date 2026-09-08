"""add popup notices

Revision ID: 20260903_0005
Revises: 20260903_0004
Create Date: 2026-09-03
"""
from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "20260903_0005"
down_revision: str | None = "20260903_0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "popup_notices",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("church_id", sa.BigInteger(), nullable=False),
        sa.Column("author_membership_id", sa.BigInteger(), nullable=False),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("image_storage_key", sa.String(length=512), nullable=True),
        sa.Column("image_content_type", sa.String(length=100), nullable=True),
        sa.Column("image_size", sa.BigInteger(), nullable=True),
        sa.Column("starts_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ends_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default=sa.false(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("starts_at < ends_at", name="ck_popup_notices_starts_before_ends"),
        sa.ForeignKeyConstraint(["church_id"], ["churches.id"], name="fk_popup_notices_church", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["author_membership_id"], ["church_memberships.id"], name="fk_popup_notices_author_membership"),
        sa.PrimaryKeyConstraint("id", name="pk_popup_notices"),
    )
    op.create_index("ix_popup_notices_church_active_window", "popup_notices", ["church_id", "is_active", "starts_at", "ends_at"], unique=False)
    op.create_index("ix_popup_notices_author_membership", "popup_notices", ["author_membership_id"], unique=False)


def downgrade() -> None:
    op.drop_table("popup_notices")
