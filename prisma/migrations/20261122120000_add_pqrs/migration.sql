-- CreateEnum
CREATE TYPE "pqrs_status" AS ENUM ('FILED', 'IN_REVIEW', 'RESOLVED');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "outbox_event_type" ADD VALUE 'PQRS_IN_REVIEW';
ALTER TYPE "outbox_event_type" ADD VALUE 'PQRS_RESPONDED';
ALTER TYPE "outbox_event_type" ADD VALUE 'PQRS_RESOLVED';

-- AlterTable
ALTER TABLE "notifications" ADD COLUMN     "pqrs_id" UUID,
ALTER COLUMN "module_id" DROP NOT NULL;

-- AlterTable
ALTER TABLE "outbox_events" ADD COLUMN     "pqrs_id" UUID,
ALTER COLUMN "module_id" DROP NOT NULL;

-- CreateTable
CREATE TABLE "pqrs" (
    "id" UUID NOT NULL,
    "author_id" UUID NOT NULL,
    "type_id" UUID NOT NULL,
    "subject" VARCHAR(200) NOT NULL,
    "description" VARCHAR(4000) NOT NULL,
    "status" "pqrs_status" NOT NULL DEFAULT 'FILED',
    "client_request_id" UUID NOT NULL,
    "reviewed_at" TIMESTAMPTZ(6),
    "resolved_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),

    CONSTRAINT "pqrs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "pqrs_messages" (
    "id" UUID NOT NULL,
    "pqrs_id" UUID NOT NULL,
    "author_id" UUID NOT NULL,
    "body" VARCHAR(4000) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMPTZ(6),

    CONSTRAINT "pqrs_messages_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "pqrs_status_created_at_idx" ON "pqrs"("status", "created_at" DESC);

-- CreateIndex
CREATE INDEX "pqrs_author_id_created_at_idx" ON "pqrs"("author_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "pqrs_type_id_idx" ON "pqrs"("type_id");

-- CreateIndex
CREATE UNIQUE INDEX "pqrs_author_id_client_request_id_key" ON "pqrs"("author_id", "client_request_id");

-- CreateIndex
CREATE INDEX "pqrs_messages_pqrs_id_created_at_idx" ON "pqrs_messages"("pqrs_id", "created_at");

-- AddForeignKey
ALTER TABLE "outbox_events" ADD CONSTRAINT "outbox_events_pqrs_id_fkey" FOREIGN KEY ("pqrs_id") REFERENCES "pqrs"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_pqrs_id_fkey" FOREIGN KEY ("pqrs_id") REFERENCES "pqrs"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pqrs" ADD CONSTRAINT "pqrs_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pqrs" ADD CONSTRAINT "pqrs_type_id_fkey" FOREIGN KEY ("type_id") REFERENCES "dropdown_items"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pqrs_messages" ADD CONSTRAINT "pqrs_messages_pqrs_id_fkey" FOREIGN KEY ("pqrs_id") REFERENCES "pqrs"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "pqrs_messages" ADD CONSTRAINT "pqrs_messages_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;


-- A module event or notice names exactly one subject: a module or a PQRS.
ALTER TABLE "outbox_events" ADD CONSTRAINT "outbox_events_subject_check" CHECK (num_nonnulls("module_id", "pqrs_id") = 1);
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_subject_check" CHECK (num_nonnulls("module_id", "pqrs_id") = 1);
