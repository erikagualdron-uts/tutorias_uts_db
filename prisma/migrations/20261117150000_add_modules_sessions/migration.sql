-- Spec 010 (modules, sessions and holidays). The generated part comes from
-- `prisma migrate diff --from-config-datasource --to-schema prisma/schema.prisma --script`
-- (not `migrate dev`, which asked to reset the dev database because the spec 006 migration was
-- annotated after it was applied).

-- CreateEnum
CREATE TYPE "session_status" AS ENUM ('SCHEDULED', 'RESCHEDULED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "session_cancel_reason" AS ENUM ('HOLIDAY');

-- CreateEnum
CREATE TYPE "holiday_source" AS ENUM ('MANUAL', 'IMPORTED');

-- CreateEnum
CREATE TYPE "outbox_event_type" AS ENUM ('MODULE_TEACHER_CHANGED', 'MODULE_ROOM_CHANGED', 'SESSIONS_CANCELLED_HOLIDAY', 'SESSIONS_RESTORED_HOLIDAY');

-- CreateTable
CREATE TABLE "modules" (
    "id" UUID NOT NULL,
    "period_id" UUID NOT NULL,
    "name" VARCHAR(120) NOT NULL,
    "description" VARCHAR(1000),
    "teacher_id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),

    CONSTRAINT "modules_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "module_schedules" (
    "id" UUID NOT NULL,
    "module_id" UUID NOT NULL,
    "period_id" UUID NOT NULL,
    "teacher_id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "day_of_week" SMALLINT NOT NULL,
    "start_minute" SMALLINT NOT NULL,
    "end_minute" SMALLINT NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),

    CONSTRAINT "module_schedules_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "module_sessions" (
    "id" UUID NOT NULL,
    "module_id" UUID NOT NULL,
    "schedule_id" UUID NOT NULL,
    "teacher_id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "original_starts_at" TIMESTAMPTZ(6) NOT NULL,
    "starts_at" TIMESTAMPTZ(6) NOT NULL,
    "ends_at" TIMESTAMPTZ(6) NOT NULL,
    "status" "session_status" NOT NULL DEFAULT 'SCHEDULED',
    "cancel_reason" "session_cancel_reason",
    "holiday_id" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),

    CONSTRAINT "module_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "holidays" (
    "id" UUID NOT NULL,
    "date" DATE NOT NULL,
    "name" VARCHAR(120) NOT NULL,
    "source" "holiday_source" NOT NULL DEFAULT 'MANUAL',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),

    CONSTRAINT "holidays_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "outbox_events" (
    "id" UUID NOT NULL,
    "type" "outbox_event_type" NOT NULL,
    "module_id" UUID NOT NULL,
    "payload" JSONB NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "processed_at" TIMESTAMPTZ(6),

    CONSTRAINT "outbox_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "modules_period_id_idx" ON "modules"("period_id");

-- CreateIndex
CREATE INDEX "modules_teacher_id_idx" ON "modules"("teacher_id");

-- CreateIndex
CREATE INDEX "modules_room_id_idx" ON "modules"("room_id");

-- CreateIndex
CREATE INDEX "module_schedules_module_id_idx" ON "module_schedules"("module_id");

-- CreateIndex
CREATE INDEX "module_sessions_module_id_starts_at_idx" ON "module_sessions"("module_id", "starts_at");

-- CreateIndex
CREATE INDEX "module_sessions_starts_at_idx" ON "module_sessions"("starts_at");

-- CreateIndex
CREATE INDEX "outbox_events_processed_at_created_at_idx" ON "outbox_events"("processed_at", "created_at");

-- AddForeignKey
ALTER TABLE "modules" ADD CONSTRAINT "modules_period_id_fkey" FOREIGN KEY ("period_id") REFERENCES "academic_periods"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "modules" ADD CONSTRAINT "modules_teacher_id_fkey" FOREIGN KEY ("teacher_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "modules" ADD CONSTRAINT "modules_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "rooms"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "module_schedules" ADD CONSTRAINT "module_schedules_module_id_fkey" FOREIGN KEY ("module_id") REFERENCES "modules"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "module_sessions" ADD CONSTRAINT "module_sessions_module_id_fkey" FOREIGN KEY ("module_id") REFERENCES "modules"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "module_sessions" ADD CONSTRAINT "module_sessions_schedule_id_fkey" FOREIGN KEY ("schedule_id") REFERENCES "module_schedules"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "module_sessions" ADD CONSTRAINT "module_sessions_holiday_id_fkey" FOREIGN KEY ("holiday_id") REFERENCES "holidays"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "outbox_events" ADD CONSTRAINT "outbox_events_module_id_fkey" FOREIGN KEY ("module_id") REFERENCES "modules"("id") ON DELETE RESTRICT ON UPDATE CASCADE;


-- ---------------------------------------------------------------------------------------------
-- Hand-written part (spec 010): Prisma cannot model these constraints. Never regenerate this
-- migration; if `prisma migrate diff` proposes dropping them, keep them (research.md R-1).
-- ---------------------------------------------------------------------------------------------

-- Weekly slots are in local America/Bogota minutes from midnight; they never cross midnight.
ALTER TABLE "module_schedules"
  ADD CONSTRAINT "module_schedules_day_check" CHECK ("day_of_week" BETWEEN 1 AND 7);

ALTER TABLE "module_schedules"
  ADD CONSTRAINT "module_schedules_minutes_check"
  CHECK ("start_minute" >= 0 AND "start_minute" < "end_minute" AND "end_minute" <= 1439);

ALTER TABLE "module_sessions"
  ADD CONSTRAINT "module_sessions_dates_check" CHECK ("ends_at" > "starts_at");

ALTER TABLE "module_sessions"
  ADD CONSTRAINT "module_sessions_cancel_reason_check"
  CHECK ("status" <> 'CANCELLED' OR "cancel_reason" IS NOT NULL);

ALTER TABLE "module_sessions"
  ADD CONSTRAINT "module_sessions_holiday_check"
  CHECK ("holiday_id" IS NULL OR "cancel_reason" = 'HOLIDAY');

-- No overlap for a teacher, a room, or two slots of the same module. Half-open range [start, end):
-- a slot that ends when another starts does not overlap. Only live rows count. period_id keeps the
-- check inside one period (periods do not overlap each other).
ALTER TABLE "module_schedules"
  ADD CONSTRAINT "module_schedules_teacher_no_overlap"
  EXCLUDE USING gist (
    "teacher_id" WITH =, "period_id" WITH =, "day_of_week" WITH =,
    int4range("start_minute"::int, "end_minute"::int, '[)') WITH &&
  ) WHERE ("deleted_at" IS NULL);

ALTER TABLE "module_schedules"
  ADD CONSTRAINT "module_schedules_room_no_overlap"
  EXCLUDE USING gist (
    "room_id" WITH =, "period_id" WITH =, "day_of_week" WITH =,
    int4range("start_minute"::int, "end_minute"::int, '[)') WITH &&
  ) WHERE ("deleted_at" IS NULL);

ALTER TABLE "module_schedules"
  ADD CONSTRAINT "module_schedules_self_no_overlap"
  EXCLUDE USING gist (
    "module_id" WITH =, "day_of_week" WITH =,
    int4range("start_minute"::int, "end_minute"::int, '[)') WITH &&
  ) WHERE ("deleted_at" IS NULL);

-- Generating sessions twice never duplicates an occurrence.
CREATE UNIQUE INDEX "module_sessions_schedule_occurrence_unique_idx"
  ON "module_sessions" ("schedule_id", "original_starts_at")
  WHERE "deleted_at" IS NULL;

-- One holiday per calendar day among live rows.
CREATE UNIQUE INDEX "holidays_date_unique_idx"
  ON "holidays" ("date")
  WHERE "deleted_at" IS NULL;
