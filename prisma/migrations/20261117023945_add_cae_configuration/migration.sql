-- CreateEnum
CREATE TYPE "period_status" AS ENUM ('UPCOMING', 'ACTIVE', 'CLOSED');

-- CreateEnum
CREATE TYPE "period_closed_by" AS ENUM ('MANUAL', 'AUTOMATIC');

-- CreateEnum
CREATE TYPE "room_status" AS ENUM ('ACTIVE', 'INACTIVE');

-- CreateEnum
CREATE TYPE "item_status" AS ENUM ('ACTIVE', 'INACTIVE');

-- CreateTable
CREATE TABLE "academic_periods" (
    "id" UUID NOT NULL,
    "name" VARCHAR(50) NOT NULL,
    "starts_on" DATE NOT NULL,
    "ends_on" DATE NOT NULL,
    "status" "period_status" NOT NULL DEFAULT 'UPCOMING',
    "closed_at" TIMESTAMPTZ(6),
    "closed_by" "period_closed_by",
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),

    CONSTRAINT "academic_periods_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "locations" (
    "id" UUID NOT NULL,
    "name" VARCHAR(80) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),

    CONSTRAINT "locations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "rooms" (
    "id" UUID NOT NULL,
    "location_id" UUID NOT NULL,
    "name" VARCHAR(40) NOT NULL,
    "capacity" INTEGER NOT NULL,
    "status" "room_status" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),

    CONSTRAINT "rooms_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "dropdown_lists" (
    "id" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "name_es" TEXT NOT NULL,
    "name_en" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "dropdown_lists_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "dropdown_items" (
    "id" UUID NOT NULL,
    "list_id" UUID NOT NULL,
    "label_es" VARCHAR(80) NOT NULL,
    "label_en" VARCHAR(80) NOT NULL,
    "sort_order" INTEGER NOT NULL,
    "status" "item_status" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),

    CONSTRAINT "dropdown_items_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "rooms_location_id_idx" ON "rooms"("location_id");

-- CreateIndex
CREATE UNIQUE INDEX "dropdown_lists_key_key" ON "dropdown_lists"("key");

-- CreateIndex
CREATE INDEX "dropdown_items_list_id_sort_order_idx" ON "dropdown_items"("list_id", "sort_order");

-- AddForeignKey
ALTER TABLE "rooms" ADD CONSTRAINT "rooms_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "locations"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dropdown_items" ADD CONSTRAINT "dropdown_items_list_id_fkey" FOREIGN KEY ("list_id") REFERENCES "dropdown_lists"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- ---------------------------------------------------------------------------------------------
-- Hand-written part (spec 006): Prisma cannot model these constraints. Never regenerate this
-- migration; if `prisma migrate diff` proposes dropping them, keep them (research.md R-2, R-6).
-- Checked on creation: `prisma migrate diff --from-config-datasource --to-schema` is empty, so
-- Prisma does not try to drop these objects.
-- ---------------------------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE "academic_periods"
  ADD CONSTRAINT "academic_periods_dates_check" CHECK ("ends_on" > "starts_on");

ALTER TABLE "rooms"
  ADD CONSTRAINT "rooms_capacity_check" CHECK ("capacity" > 0);

-- At most one ACTIVE period among non-deleted ones.
CREATE UNIQUE INDEX "academic_periods_single_active_idx"
  ON "academic_periods" ((true))
  WHERE "status" = 'ACTIVE' AND "deleted_at" IS NULL;

-- No overlapping dates (closed range: end of one = start of another counts as overlap).
ALTER TABLE "academic_periods"
  ADD CONSTRAINT "academic_periods_no_overlap"
  EXCLUDE USING gist (daterange("starts_on", "ends_on", '[]') WITH &&)
  WHERE ("deleted_at" IS NULL);

-- Names unique ignoring case and surrounding spaces, only among non-deleted rows.
CREATE UNIQUE INDEX "academic_periods_name_unique_idx"
  ON "academic_periods" (lower(btrim("name")))
  WHERE "deleted_at" IS NULL;

CREATE UNIQUE INDEX "locations_name_unique_idx"
  ON "locations" (lower(btrim("name")))
  WHERE "deleted_at" IS NULL;

CREATE UNIQUE INDEX "rooms_name_per_location_unique_idx"
  ON "rooms" ("location_id", lower(btrim("name")))
  WHERE "deleted_at" IS NULL;

-- Preloaded list "Tipos de PQRS" (fixed ids so every environment has the same rows).
INSERT INTO "dropdown_lists" ("id", "key", "name_es", "name_en", "updated_at")
VALUES ('a1b2c3d4-0001-4000-8000-000000000001', 'PQRS_TYPE', 'Tipos de PQRS', 'PQRS types', CURRENT_TIMESTAMP);

INSERT INTO "dropdown_items" ("id", "list_id", "label_es", "label_en", "sort_order", "updated_at") VALUES
  ('a1b2c3d4-0002-4000-8000-000000000001', 'a1b2c3d4-0001-4000-8000-000000000001', 'Petición', 'Request', 1, CURRENT_TIMESTAMP),
  ('a1b2c3d4-0002-4000-8000-000000000002', 'a1b2c3d4-0001-4000-8000-000000000001', 'Queja', 'Complaint', 2, CURRENT_TIMESTAMP),
  ('a1b2c3d4-0002-4000-8000-000000000003', 'a1b2c3d4-0001-4000-8000-000000000001', 'Reclamo', 'Claim', 3, CURRENT_TIMESTAMP),
  ('a1b2c3d4-0002-4000-8000-000000000004', 'a1b2c3d4-0001-4000-8000-000000000001', 'Sugerencia', 'Suggestion', 4, CURRENT_TIMESTAMP);
