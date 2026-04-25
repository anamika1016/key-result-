# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_04_20_094500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "achievement_remarks", force: :cascade do |t|
    t.text "l1_remarks"
    t.float "l1_percentage"
    t.text "l2_remarks"
    t.float "l2_percentage"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "employee_remarks"
    t.bigint "achievement_id", null: false
    t.text "l3_remarks"
    t.float "l3_percentage"
    t.index ["achievement_id"], name: "index_achievement_remarks_on_achievement_id"
  end

  create_table "achievements", force: :cascade do |t|
    t.bigint "user_detail_id", null: false
    t.string "month"
    t.string "achievement"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "pending"
    t.text "l1_remarks"
    t.float "l1_percentage"
    t.text "l2_remarks"
    t.float "l2_percentage"
    t.text "employee_remarks"
    t.string "return_to"
    t.index ["month"], name: "index_achievements_on_month"
    t.index ["status", "month"], name: "index_achievements_on_status_and_month"
    t.index ["status"], name: "index_achievements_on_status"
    t.index ["user_detail_id", "month"], name: "index_achievements_on_user_detail_id_and_month"
    t.index ["user_detail_id", "status"], name: "index_achievements_on_user_detail_id_and_status"
    t.index ["user_detail_id"], name: "index_achievements_on_user_detail_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activities", force: :cascade do |t|
    t.bigint "department_id", null: false
    t.integer "activity_id"
    t.string "activity_name"
    t.string "unit"
    t.float "weight"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "theme_name"
    t.string "year", null: false
    t.index ["department_id", "activity_name", "theme_name", "year"], name: "index_activities_on_department_activity_theme_year"
    t.index ["department_id"], name: "index_activities_on_department_id"
    t.index ["year"], name: "index_activities_on_year"
  end

  create_table "departments", force: :cascade do |t|
    t.string "department_type"
    t.integer "theme_id"
    t.string "theme_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "employee_reference"
    t.integer "activities_count", default: 0, null: false
    t.index ["department_type"], name: "index_departments_on_department_type"
  end

  create_table "employee_details", force: :cascade do |t|
    t.string "employee_name"
    t.string "employee_email"
    t.string "employee_code"
    t.string "l1_code"
    t.string "l2_code"
    t.string "l1_employer_name"
    t.string "l2_employer_name"
    t.string "post"
    t.string "department"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "pending"
    t.bigint "user_id"
    t.string "mobile_number"
    t.string "l3_code"
    t.string "l3_employer_name"
    t.integer "user_details_count", default: 0, null: false
    t.boolean "assignments_managed"
    t.index ["employee_code"], name: "index_employee_details_on_employee_code"
    t.index ["employee_email"], name: "index_employee_details_on_employee_email"
    t.index ["l1_code", "status"], name: "index_employee_details_on_l1_code_and_status"
    t.index ["l1_code"], name: "index_employee_details_on_l1_code"
    t.index ["l2_code", "status"], name: "index_employee_details_on_l2_code_and_status"
    t.index ["l2_code"], name: "index_employee_details_on_l2_code"
    t.index ["l3_code", "status"], name: "index_employee_details_on_l3_code_and_status"
    t.index ["l3_code"], name: "index_employee_details_on_l3_code"
    t.index ["status"], name: "index_employee_details_on_status"
    t.index ["user_id"], name: "index_employee_details_on_user_id"
  end

  create_table "questions", force: :cascade do |t|
    t.bigint "quiz_id", null: false
    t.text "question"
    t.string "option_a"
    t.string "option_b"
    t.string "option_c"
    t.string "option_d"
    t.string "option_e"
    t.string "option_f"
    t.string "correct_answer"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["quiz_id"], name: "index_questions_on_quiz_id"
  end

  create_table "quiz_submissions", force: :cascade do |t|
    t.bigint "quiz_id", null: false
    t.bigint "user_quiz_id", null: false
    t.bigint "user_id"
    t.bigint "employee_detail_id"
    t.string "employee_code", null: false
    t.string "name", null: false
    t.string "email"
    t.string "mobile_number"
    t.string "designation"
    t.string "branch"
    t.string "sub_branch"
    t.integer "score"
    t.string "status", null: false
    t.jsonb "submitted_answers", default: {}, null: false
    t.datetime "submitted_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_detail_id"], name: "index_quiz_submissions_on_employee_detail_id"
    t.index ["quiz_id", "employee_code"], name: "index_quiz_submissions_on_quiz_id_and_employee_code", unique: true
    t.index ["quiz_id"], name: "index_quiz_submissions_on_quiz_id"
    t.index ["user_id"], name: "index_quiz_submissions_on_user_id"
    t.index ["user_quiz_id"], name: "index_quiz_submissions_on_user_quiz_id"
  end

  create_table "quizzes", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.integer "duration"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "qr_token"
    t.index ["qr_token"], name: "index_quizzes_on_qr_token", unique: true
  end

  create_table "sms_logs", force: :cascade do |t|
    t.string "quarter"
    t.boolean "sent"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "employee_detail_id", null: false
    t.string "mobile_number"
    t.string "provider_status"
    t.string "provider_code"
    t.string "provider_description"
    t.string "message_id"
    t.text "provider_response_raw"
    t.index ["employee_detail_id", "quarter"], name: "index_sms_logs_on_employee_detail_id_and_quarter"
    t.index ["employee_detail_id"], name: "index_sms_logs_on_employee_detail_id"
    t.index ["message_id"], name: "index_sms_logs_on_message_id"
    t.index ["mobile_number"], name: "index_sms_logs_on_mobile_number"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.binary "payload", null: false
    t.datetime "created_at", null: false
    t.bigint "channel_hash", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "system_settings", force: :cascade do |t|
    t.string "key"
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_system_settings_on_key"
  end

  create_table "training_questions", force: :cascade do |t|
    t.bigint "training_id", null: false
    t.text "question"
    t.string "option_a"
    t.string "option_b"
    t.string "option_c"
    t.string "option_d"
    t.string "correct_answer"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["training_id"], name: "index_training_questions_on_training_id"
  end

  create_table "trainings", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.integer "duration"
    t.integer "created_by"
    t.integer "month"
    t.integer "year"
    t.boolean "status"
    t.boolean "has_assessment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "user_details", force: :cascade do |t|
    t.bigint "department_id", null: false
    t.bigint "activity_id", null: false
    t.text "april"
    t.text "may"
    t.text "june"
    t.text "july"
    t.text "august"
    t.text "september"
    t.text "october"
    t.text "november"
    t.text "december"
    t.text "january"
    t.text "february"
    t.text "march"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "employee_detail_id"
    t.bigint "user_id"
    t.integer "achievements_count", default: 0, null: false
    t.text "q1"
    t.text "q2"
    t.text "q3"
    t.text "q4"
    t.string "year", null: false
    t.index ["activity_id"], name: "index_user_details_on_activity_id"
    t.index ["department_id"], name: "index_user_details_on_department_id"
    t.index ["employee_detail_id", "department_id", "activity_id", "year"], name: "index_user_details_on_employee_department_activity_year"
    t.index ["employee_detail_id", "department_id"], name: "index_user_details_on_employee_detail_id_and_department_id"
    t.index ["employee_detail_id"], name: "index_user_details_on_employee_detail_id"
    t.index ["user_id"], name: "index_user_details_on_user_id"
    t.index ["year"], name: "index_user_details_on_year"
  end

  create_table "user_quizzes", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "quiz_id"
    t.integer "score"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "employee_code"
    t.string "name"
    t.string "email"
    t.string "mobile_number"
    t.string "designation"
    t.string "branch"
    t.string "sub_branch"
    t.string "password"
    t.jsonb "submitted_answers", default: {}, null: false
    t.datetime "submitted_at"
    t.index ["quiz_id"], name: "index_user_quizzes_on_quiz_id"
    t.index ["user_id"], name: "index_user_quizzes_on_user_id"
  end

  create_table "user_training_assignments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "training_id", null: false
    t.bigint "employee_detail_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_detail_id"], name: "index_user_training_assignments_on_employee_detail_id"
    t.index ["training_id"], name: "index_user_training_assignments_on_training_id"
    t.index ["user_id"], name: "index_user_training_assignments_on_user_id"
  end

  create_table "user_training_progresses", force: :cascade do |t|
    t.bigint "training_id", null: false
    t.bigint "user_id", null: false
    t.string "status"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.integer "time_spent"
    t.string "financial_year"
    t.integer "score"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["training_id"], name: "index_user_training_progresses_on_training_id"
    t.index ["user_id"], name: "index_user_training_progresses_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role"
    t.string "employee_code"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["employee_code"], name: "index_users_on_employee_code"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "achievement_remarks", "achievements"
  add_foreign_key "achievements", "user_details"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "departments"
  add_foreign_key "employee_details", "users"
  add_foreign_key "questions", "quizzes"
  add_foreign_key "quiz_submissions", "employee_details"
  add_foreign_key "quiz_submissions", "quizzes"
  add_foreign_key "quiz_submissions", "user_quizzes"
  add_foreign_key "quiz_submissions", "users"
  add_foreign_key "sms_logs", "employee_details"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "training_questions", "trainings"
  add_foreign_key "user_details", "activities"
  add_foreign_key "user_details", "departments"
  add_foreign_key "user_details", "employee_details"
  add_foreign_key "user_details", "users"
  add_foreign_key "user_quizzes", "quizzes"
  add_foreign_key "user_quizzes", "users"
  add_foreign_key "user_training_assignments", "employee_details"
  add_foreign_key "user_training_assignments", "trainings"
  add_foreign_key "user_training_assignments", "users"
  add_foreign_key "user_training_progresses", "trainings"
  add_foreign_key "user_training_progresses", "users"
end
