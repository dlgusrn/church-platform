"""separate worship guide from live worship type

Revision ID: 20260902_0003
Revises: 20260902_0002
Create Date: 2026-09-02
"""
from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "20260902_0003"
down_revision: str | None = "20260902_0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

live_worship_type = sa.Enum(
    "day", "night", "prayer_11", "special", "custom", name="live_worship_type"
)


def upgrade() -> None:
    op.add_column(
        "worship_schedules", sa.Column("day_label", sa.String(length=100), nullable=True)
    )
    op.execute(
        """
        UPDATE worship_schedules
        SET day_label = ELT(day_of_week + 1,
            '월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일')
        """
    )
    op.alter_column(
        "worship_schedules",
        "name",
        new_column_name="title",
        existing_type=sa.String(length=100),
        existing_nullable=False,
        nullable=False,
    )
    op.alter_column(
        "worship_schedules",
        "start_time",
        new_column_name="time",
        existing_type=sa.Time(),
        existing_nullable=False,
        nullable=False,
    )
    op.alter_column(
        "worship_schedules", "day_label", existing_type=sa.String(length=100), nullable=False
    )
    # 0002 used op.f() when creating this constraint.  Passing its plain name
    # here makes Alembic apply Base.metadata's `ck` convention a second time.
    op.drop_constraint(
        op.f("ck_worship_schedules_day_range"),
        "worship_schedules",
        type_="check",
    )
    op.drop_column("worship_schedules", "day_of_week")

    op.add_column(
        "live_broadcasts",
        sa.Column("worship_type", live_worship_type, nullable=True),
    )
    op.add_column(
        "live_broadcasts", sa.Column("custom_worship_name", sa.String(length=100), nullable=True)
    )
    op.execute(
        """
        UPDATE live_broadcasts AS broadcast
        LEFT JOIN worship_schedules AS schedule
            ON schedule.id = broadcast.worship_schedule_id
        SET broadcast.worship_type = CASE schedule.title
            WHEN '낮예배' THEN 'day'
            WHEN '밤예배' THEN 'night'
            WHEN '11시기도' THEN 'prayer_11'
            WHEN '11시 기도' THEN 'prayer_11'
            WHEN '특별성회' THEN 'special'
            ELSE CASE
                WHEN schedule.title IS NULL THEN 'special'
                ELSE 'custom'
            END
        END,
        broadcast.custom_worship_name = CASE
            WHEN schedule.title IS NOT NULL
                 AND schedule.title NOT IN ('낮예배', '밤예배', '11시기도', '11시 기도', '특별성회')
            THEN schedule.title
            ELSE NULL
        END
        """
    )
    op.alter_column(
        "live_broadcasts", "worship_type", existing_type=live_worship_type, nullable=False
    )
    op.drop_constraint("fk_live_broadcasts_schedule", "live_broadcasts", type_="foreignkey")
    op.drop_index("ix_live_broadcasts_schedule", table_name="live_broadcasts")
    op.drop_column("live_broadcasts", "worship_schedule_id")


def downgrade() -> None:
    op.add_column(
        "live_broadcasts", sa.Column("worship_schedule_id", sa.BigInteger(), nullable=True)
    )
    op.create_index(
        "ix_live_broadcasts_schedule", "live_broadcasts", ["worship_schedule_id"], unique=False
    )
    op.create_foreign_key(
        "fk_live_broadcasts_schedule",
        "live_broadcasts",
        "worship_schedules",
        ["worship_schedule_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.drop_column("live_broadcasts", "custom_worship_name")
    op.drop_column("live_broadcasts", "worship_type")

    op.add_column(
        "worship_schedules", sa.Column("day_of_week", sa.Integer(), nullable=True)
    )
    op.execute("UPDATE worship_schedules SET day_of_week = 6")
    op.alter_column(
        "worship_schedules", "day_of_week", existing_type=sa.Integer(), nullable=False
    )
    op.create_check_constraint(
        "ck_worship_schedules_day_range",
        "worship_schedules",
        "day_of_week BETWEEN 0 AND 6",
    )
    op.alter_column(
        "worship_schedules",
        "title",
        new_column_name="name",
        existing_type=sa.String(length=100),
    )
    op.alter_column(
        "worship_schedules",
        "time",
        new_column_name="start_time",
        existing_type=sa.Time(),
    )
    op.drop_column("worship_schedules", "day_label")
