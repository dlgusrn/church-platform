"""add unified video library

Revision ID: 20260904_0006
Revises: 20260903_0005
"""
from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "20260904_0006"
down_revision: str | None = "20260903_0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "video_categories",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("church_id", sa.BigInteger(), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("sort_order", sa.Integer(), server_default="0", nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["church_id"], ["churches.id"], name="fk_video_categories_church_id", ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id", name="pk_video_categories"),
        sa.UniqueConstraint("church_id", "name", name="uq_video_categories_church_name"),
    )
    op.create_table(
        "video_collections",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("church_id", sa.BigInteger(), nullable=False),
        sa.Column("category_id", sa.BigInteger(), nullable=True),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("recorded_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("sort_order", sa.Integer(), server_default="0", nullable=False),
        sa.Column("is_published", sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["church_id"], ["churches.id"], name="fk_video_collections_church_id", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["category_id"], ["video_categories.id"], name="fk_video_collections_category_id", ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id", name="pk_video_collections"),
    )
    op.create_table(
        "videos",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("church_id", sa.BigInteger(), nullable=False),
        sa.Column("category_id", sa.BigInteger(), nullable=True),
        sa.Column("collection_id", sa.BigInteger(), nullable=True),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("source_type", sa.String(length=20), nullable=False),
        sa.Column("source_ref", sa.String(length=500), nullable=False),
        sa.Column("recorded_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("duration_seconds", sa.Integer(), nullable=True),
        sa.Column("thumbnail_ref", sa.String(length=500), nullable=True),
        sa.Column("is_published", sa.Boolean(), server_default=sa.true(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["church_id"], ["churches.id"], name="fk_videos_church_id", ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["category_id"], ["video_categories.id"], name="fk_videos_category_id", ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["collection_id"], ["video_collections.id"], name="fk_videos_collection_id", ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id", name="pk_videos"),
        sa.UniqueConstraint("church_id", "source_type", "source_ref", name="uq_videos_church_source_ref"),
    )
    op.create_index("ix_videos_church_published_recorded", "videos", ["church_id", "is_published", "recorded_at"])
    op.create_index("ix_videos_church_category_recorded", "videos", ["church_id", "category_id", "recorded_at"])
    op.create_index("ix_videos_church_collection", "videos", ["church_id", "collection_id"])


def downgrade() -> None:
    op.drop_table("videos")
    op.drop_table("video_collections")
    op.drop_table("video_categories")
