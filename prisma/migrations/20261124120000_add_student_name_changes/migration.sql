-- CreateTable
CREATE TABLE "student_name_changes" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "previous_first_name" TEXT NOT NULL,
    "previous_last_name" TEXT NOT NULL,
    "new_first_name" TEXT NOT NULL,
    "new_last_name" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "student_name_changes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "student_name_changes_user_id_created_at_idx" ON "student_name_changes"("user_id", "created_at");

-- AddForeignKey
ALTER TABLE "student_name_changes" ADD CONSTRAINT "student_name_changes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

