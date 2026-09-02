"""add worship schedules and live broadcasts

Revision ID: 20260902_0002
Revises: 20260901_0001
Create Date: 2026-09-02
"""
from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "20260902_0002"
down_revision: str | None = "20260901_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

live_broadcast_status = sa.Enum(
    "scheduled", "live", "ended", name="live_broadcast_status"
)


def upgrade() -> None:
    op.create_table(
        "worship_schedules",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("church_id", sa.BigInteger(), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("day_of_week", sa.Integer(), nullable=False),
        sa.Column("start_time", sa.Time(), nullable=False),
        sa.Column("display_order", sa.Integer(), server_default="0", nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint(
            "day_of_week BETWEEN 0 AND 6",
            name=op.f("ck_worship_schedules_day_range"),
        ),
        sa.ForeignKeyConstraint(
            ["church_id"], ["churches.id"], name="fk_worship_schedules_church", ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name="pk_worship_schedules"),
    )
    op.create_index(
        "ix_worship_schedules_church", "worship_schedules", ["church_id"], unique=False
    )

    op.create_table(
        "live_broadcasts",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("church_id", sa.BigInteger(), nullable=False),
        sa.Column("worship_schedule_id", sa.BigInteger(), nullable=True),
        sa.Column("broadcast_date", sa.Date(), nullable=False),
        sa.Column("title_override", sa.String(length=200), nullable=True),
        sa.Column("youtube_url", sa.String(length=500), nullable=False),
        sa.Column("status", live_broadcast_status, server_default="scheduled", nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(
            ["church_id"], ["churches.id"], name="fk_live_broadcasts_church", ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["worship_schedule_id"],
            ["worship_schedules.id"],
            name="fk_live_broadcasts_schedule",
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_live_broadcasts"),
    )
    op.create_index(
        "ix_live_broadcasts_church", "live_broadcasts", ["church_id"], unique=False
    )
    op.create_index(
        "ix_live_broadcasts_schedule",
        "live_broadcasts",
        ["worship_schedule_id"],
        unique=False,
    )
    op.create_index(
        "ix_live_broadcasts_date", "live_broadcasts", ["broadcast_date"], unique=False
    )


def downgrade() -> None:
    op.drop_table("live_broadcasts")
    op.drop_table("worship_schedules")
