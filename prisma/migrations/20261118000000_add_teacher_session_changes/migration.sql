-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "outbox_event_type" ADD VALUE 'SESSION_RESCHEDULED';
ALTER TYPE "outbox_event_type" ADD VALUE 'SESSION_CANCELLED_TEACHER';
ALTER TYPE "outbox_event_type" ADD VALUE 'SESSION_RESTORED_TEACHER';

-- AlterEnum
ALTER TYPE "session_cancel_reason" ADD VALUE 'TEACHER';

-- CreateIndex
CREATE INDEX "module_sessions_room_id_starts_at_idx" ON "module_sessions"("room_id", "starts_at");

-- CreateIndex
CREATE INDEX "module_sessions_teacher_id_starts_at_idx" ON "module_sessions"("teacher_id", "starts_at");

