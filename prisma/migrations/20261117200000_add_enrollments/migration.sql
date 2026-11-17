-- CreateEnum
CREATE TYPE "EnrollmentStatus" AS ENUM ('ACTIVE', 'CANCELLED');

-- CreateTable
CREATE TABLE "enrollments" (
    "id" UUID NOT NULL,
    "student_id" UUID NOT NULL,
    "module_id" UUID NOT NULL,
    "status" "EnrollmentStatus" NOT NULL DEFAULT 'ACTIVE',
    "cancelled_at" TIMESTAMPTZ(6),
    "effective_until" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),

    CONSTRAINT "enrollments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "session_absences" (
    "id" UUID NOT NULL,
    "enrollment_id" UUID NOT NULL,
    "session_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),

    CONSTRAINT "session_absences_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "enrollments_module_id_status_idx" ON "enrollments"("module_id", "status");

-- CreateIndex
CREATE INDEX "enrollments_student_id_status_idx" ON "enrollments"("student_id", "status");

-- CreateIndex
CREATE INDEX "session_absences_session_id_idx" ON "session_absences"("session_id");

-- AddForeignKey
ALTER TABLE "enrollments" ADD CONSTRAINT "enrollments_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "enrollments" ADD CONSTRAINT "enrollments_module_id_fkey" FOREIGN KEY ("module_id") REFERENCES "modules"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "session_absences" ADD CONSTRAINT "session_absences_enrollment_id_fkey" FOREIGN KEY ("enrollment_id") REFERENCES "enrollments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "session_absences" ADD CONSTRAINT "session_absences_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "module_sessions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;


-- Hand-written (Prisma cannot model these): one ACTIVE enrollment per student and module,
-- coherent cancellation dates, and one live absence per enrollment and session.
CREATE UNIQUE INDEX "enrollments_one_active" ON "enrollments" ("student_id", "module_id") WHERE "status" = 'ACTIVE' AND "deleted_at" IS NULL;

ALTER TABLE "enrollments" ADD CONSTRAINT "enrollments_status_dates" CHECK (
  ("status" = 'ACTIVE' AND "cancelled_at" IS NULL AND "effective_until" IS NULL)
  OR ("status" = 'CANCELLED' AND "cancelled_at" IS NOT NULL AND "effective_until" IS NOT NULL AND "effective_until" >= "cancelled_at")
);

CREATE UNIQUE INDEX "session_absences_one_live" ON "session_absences" ("enrollment_id", "session_id") WHERE "deleted_at" IS NULL;
