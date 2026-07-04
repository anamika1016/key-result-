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

ActiveRecord::Schema[8.0].define(version: 2026_07_03_091000) do
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
    t.string "position"
    t.string "office_type"
    t.string "office_name"
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

  create_table "employee_training_thematics", force: :cascade do |t|
    t.string "thematic_type", null: false
    t.string "department_name", null: false
    t.boolean "active", default: true, null: false
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["thematic_type", "department_name"], name: "index_employee_training_thematics_on_type_and_department", unique: true
  end

  create_table "employee_training_topics", force: :cascade do |t|
    t.string "thematic_department_name", null: false
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["thematic_department_name", "name"], name: "index_employee_training_topics_on_thematic_and_name", unique: true
  end

  create_table "employee_trainings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.jsonb "office_types", default: [], null: false
    t.jsonb "office_names", default: [], null: false
    t.string "thematic_department_name", null: false
    t.date "training_date", null: false
    t.string "topic", null: false
    t.string "other_topic"
    t.text "details", null: false
    t.string "training_location", null: false
    t.integer "asa_participants", default: 0, null: false
    t.integer "other_participants", default: 0, null: false
    t.string "qr_id", null: false
    t.jsonb "employee_detail_ids", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_employee_trainings_on_created_at"
    t.index ["thematic_department_name"], name: "index_employee_trainings_on_thematic_department_name"
    t.index ["training_date"], name: "index_employee_trainings_on_training_date"
    t.index ["user_id"], name: "index_employee_trainings_on_user_id"
  end

  create_table "guest_house_booking_guests", force: :cascade do |t|
    t.bigint "guest_house_booking_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "aadhaar_number", null: false
    t.string "mobile_number"
    t.string "email"
    t.string "gender"
    t.integer "age"
    t.string "organization"
    t.string "designation"
    t.text "purpose"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "checkin_date", null: false
    t.time "checkin_time", null: false
    t.date "checkout_date", null: false
    t.time "checkout_time", null: false
    t.string "stay_status", default: "pending", null: false
    t.datetime "checked_in_at"
    t.datetime "checked_out_at"
    t.string "id_proof_type"
    t.string "id_proof_number"
    t.text "checkin_remark"
    t.text "checkout_remark"
    t.decimal "room_charge_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "other_services_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.text "other_services_details"
    t.decimal "gst_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "total_bill_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.text "bill_note"
    t.datetime "billed_at"
    t.string "payment_status", default: "pending", null: false
    t.string "transaction_id"
    t.text "payment_details"
    t.string "payment_qr_token"
    t.datetime "paid_at"
    t.string "approval_status", default: "pending", null: false
    t.bigint "accepted_by_id"
    t.datetime "accepted_at"
    t.text "approval_remark"
    t.text "rejection_remark"
    t.string "payment_receipt_number"
    t.boolean "room_charge_overridden", default: false, null: false
    t.index ["aadhaar_number"], name: "index_guest_house_booking_guests_on_aadhaar_number"
    t.index ["accepted_by_id"], name: "index_guest_house_booking_guests_on_accepted_by_id"
    t.index ["approval_status"], name: "index_guest_house_booking_guests_on_approval_status"
    t.index ["guest_house_booking_id", "stay_status"], name: "index_gh_booking_guests_on_booking_status"
    t.index ["guest_house_booking_id"], name: "index_gh_booking_guests_on_booking_id"
    t.index ["payment_receipt_number"], name: "index_guest_house_booking_guests_on_payment_receipt_number", unique: true
    t.index ["payment_status"], name: "index_guest_house_booking_guests_on_payment_status"
    t.check_constraint "age IS NULL OR age > 0", name: "gh_booking_guests_age_positive"
    t.check_constraint "approval_status::text = ANY (ARRAY['pending'::character varying, 'accepted'::character varying, 'rejected'::character varying]::text[])", name: "gh_booking_guests_approval_status_valid"
    t.check_constraint "payment_status::text = ANY (ARRAY['pending'::character varying, 'generated'::character varying, 'uploaded'::character varying, 'paid'::character varying, 'waived'::character varying]::text[])", name: "gh_booking_guests_payment_status_valid"
    t.check_constraint "room_charge_amount >= 0::numeric AND other_services_amount >= 0::numeric AND gst_amount >= 0::numeric AND total_bill_amount >= 0::numeric", name: "gh_booking_guests_bill_amounts_non_negative"
    t.check_constraint "stay_status::text = ANY (ARRAY['pending'::character varying, 'checked_in'::character varying, 'checked_out'::character varying]::text[])", name: "gh_booking_guests_stay_status_valid"
  end

  create_table "guest_house_bookings", force: :cascade do |t|
    t.bigint "guest_house_id", null: false
    t.bigint "user_id", null: false
    t.bigint "accepted_by_id"
    t.string "booking_reference", null: false
    t.date "booking_date", null: false
    t.time "checkin_time", null: false
    t.time "checkout_time", null: false
    t.integer "rooms_count", default: 1, null: false
    t.string "status", default: "pending", null: false
    t.text "admin_remark"
    t.datetime "accepted_at"
    t.datetime "checked_in_at"
    t.datetime "checked_out_at"
    t.date "extended_checkout_date"
    t.time "extended_checkout_time"
    t.decimal "bill_amount", precision: 10, scale: 2
    t.string "payment_status", default: "pending", null: false
    t.text "payment_note"
    t.string "payment_qr_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "checkout_date", null: false
    t.text "rejection_remark"
    t.string "id_proof_type"
    t.string "id_proof_number"
    t.text "checkin_remark"
    t.text "guest_complaint"
    t.datetime "complaint_submitted_at"
    t.string "complaint_status", default: "open", null: false
    t.decimal "room_charge_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "other_services_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.text "other_services_details"
    t.decimal "gst_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "total_bill_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.string "transaction_id"
    t.text "payment_details"
    t.datetime "admin_reminder_sent_at"
    t.datetime "checkin_sms_sent_at"
    t.string "room_type", default: "sharing", null: false
    t.string "guest_gender"
    t.string "booking_for", default: "self", null: false
    t.integer "feedback_rating"
    t.text "feedback_comment"
    t.datetime "feedback_submitted_at"
    t.text "cancellation_reason"
    t.datetime "cancelled_at"
    t.bigint "cancelled_by_id"
    t.string "payment_receipt_number"
    t.datetime "paid_at"
    t.boolean "room_charge_overridden", default: false, null: false
    t.index ["accepted_by_id"], name: "index_guest_house_bookings_on_accepted_by_id"
    t.index ["booking_for"], name: "index_guest_house_bookings_on_booking_for"
    t.index ["booking_reference"], name: "index_guest_house_bookings_on_booking_reference", unique: true
    t.index ["cancelled_by_id"], name: "index_guest_house_bookings_on_cancelled_by_id"
    t.index ["guest_house_id", "booking_date", "checkout_date", "status", "room_type", "guest_gender"], name: "index_gh_bookings_on_room_allocation"
    t.index ["guest_house_id", "booking_date", "checkout_date", "status"], name: "index_gh_bookings_on_house_date_range_status"
    t.index ["guest_house_id", "booking_date", "status"], name: "index_gh_bookings_on_house_date_status"
    t.index ["guest_house_id"], name: "index_guest_house_bookings_on_guest_house_id"
    t.index ["payment_receipt_number"], name: "index_guest_house_bookings_on_payment_receipt_number", unique: true
    t.index ["user_id"], name: "index_guest_house_bookings_on_user_id"
    t.check_constraint "feedback_rating IS NULL OR feedback_rating >= 1 AND feedback_rating <= 5", name: "guest_house_booking_feedback_rating_range"
    t.check_constraint "room_charge_amount >= 0::numeric AND other_services_amount >= 0::numeric AND gst_amount >= 0::numeric AND total_bill_amount >= 0::numeric", name: "guest_house_booking_amounts_non_negative"
    t.check_constraint "rooms_count > 0", name: "guest_house_bookings_rooms_positive"
  end

  create_table "guest_house_facilities", force: :cascade do |t|
    t.bigint "guest_house_id", null: false
    t.string "name", null: false
    t.decimal "rate", precision: 10, scale: 2, default: "0.0", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["guest_house_id", "name"], name: "index_guest_house_facilities_on_guest_house_id_and_name", unique: true
    t.index ["guest_house_id"], name: "index_guest_house_facilities_on_guest_house_id"
    t.check_constraint "rate >= 0::numeric", name: "guest_house_facilities_rate_non_negative"
  end

  create_table "guest_house_notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "guest_house_booking_id", null: false
    t.bigint "actor_id"
    t.string "event_type", null: false
    t.string "title", null: false
    t.text "message", null: false
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "guest_house_waitlist_id"
    t.index ["actor_id"], name: "index_guest_house_notifications_on_actor_id"
    t.index ["guest_house_booking_id"], name: "index_guest_house_notifications_on_guest_house_booking_id"
    t.index ["guest_house_waitlist_id"], name: "index_guest_house_notifications_on_guest_house_waitlist_id"
    t.index ["user_id", "read_at", "created_at"], name: "index_gh_notifications_on_user_read_created"
    t.index ["user_id"], name: "index_guest_house_notifications_on_user_id"
  end

  create_table "guest_house_waitlists", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "guest_house_id", null: false
    t.date "booking_date", null: false
    t.time "checkin_time", null: false
    t.date "checkout_date", null: false
    t.time "checkout_time", null: false
    t.integer "rooms_count", null: false
    t.string "room_type", null: false
    t.string "guest_gender", null: false
    t.string "booking_for", null: false
    t.jsonb "occupant_gender_counts", default: {}, null: false
    t.string "status", default: "waiting", null: false
    t.datetime "notified_at"
    t.datetime "fulfilled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["guest_house_id", "status", "booking_date"], name: "index_gh_waitlists_on_house_status_date"
    t.index ["guest_house_id"], name: "index_guest_house_waitlists_on_guest_house_id"
    t.index ["user_id", "guest_house_id", "booking_date", "checkin_time", "checkout_date", "checkout_time", "room_type", "booking_for"], name: "index_gh_waitlists_on_request"
    t.index ["user_id"], name: "index_guest_house_waitlists_on_user_id"
    t.check_constraint "status::text = ANY (ARRAY['waiting'::character varying, 'notified'::character varying, 'fulfilled'::character varying, 'expired'::character varying]::text[])", name: "gh_waitlists_status_valid"
  end

  create_table "guest_houses", force: :cascade do |t|
    t.string "name", null: false
    t.integer "total_rooms", default: 1, null: false
    t.boolean "active", default: true, null: false
    t.bigint "manager_user_id"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "room_charge_per_day", precision: 10, scale: 2, default: "0.0", null: false
    t.text "facility_rates"
    t.index "lower((name)::text)", name: "index_guest_houses_on_lower_name", unique: true
    t.index ["created_by_id"], name: "index_guest_houses_on_created_by_id"
    t.index ["manager_user_id"], name: "index_guest_houses_on_manager_user_id"
    t.check_constraint "room_charge_per_day >= 0::numeric", name: "guest_houses_room_charge_non_negative"
    t.check_constraint "total_rooms > 0", name: "guest_houses_total_rooms_positive"
  end

  create_table "help_desk_question_masters", force: :cascade do |t|
    t.bigint "department_id", null: false
    t.string "request_type", null: false
    t.text "question_text", null: false
    t.integer "position", default: 1, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["department_id", "request_type", "active"], name: "index_help_desk_question_masters_on_context_and_active"
    t.index ["department_id", "request_type", "position"], name: "index_help_desk_question_masters_on_context_and_position"
    t.index ["department_id"], name: "index_help_desk_question_masters_on_department_id"
  end

  create_table "help_desk_requester_remarks", force: :cascade do |t|
    t.bigint "help_desk_ticket_id", null: false
    t.bigint "user_id"
    t.text "message", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["help_desk_ticket_id", "created_at"], name: "index_help_desk_requester_remarks_on_ticket_and_created_at"
    t.index ["help_desk_ticket_id"], name: "index_help_desk_requester_remarks_on_ticket_id"
    t.index ["user_id"], name: "index_help_desk_requester_remarks_on_user_id"
  end

  create_table "help_desk_support_updates", force: :cascade do |t|
    t.bigint "help_desk_ticket_id", null: false
    t.bigint "user_id"
    t.text "message", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["help_desk_ticket_id", "created_at"], name: "index_help_desk_support_updates_on_ticket_and_created_at"
    t.index ["help_desk_ticket_id"], name: "index_help_desk_support_updates_on_ticket_id"
    t.index ["user_id"], name: "index_help_desk_support_updates_on_user_id"
  end

  create_table "help_desk_tickets", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "department_id", null: false
    t.string "request_type", null: false
    t.string "status", default: "submitted", null: false
    t.string "requester_name", null: false
    t.string "requester_email", null: false
    t.string "requester_employee_code"
    t.text "message", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "assigned_to_user_id"
    t.bigint "responded_by_user_id"
    t.integer "current_escalation_position", default: 1, null: false
    t.datetime "assigned_at"
    t.datetime "escalation_due_at"
    t.text "response_message"
    t.datetime "responded_at"
    t.bigint "submitted_by_user_id"
    t.boolean "raised_on_behalf", default: false, null: false
    t.datetime "requester_response_due_at"
    t.text "requester_remark"
    t.datetime "closed_at"
    t.boolean "closed_automatically", default: false, null: false
    t.bigint "closed_by_user_id"
    t.bigint "help_desk_question_master_id"
    t.text "question_subject"
    t.bigint "approval_user_id"
    t.string "final_action_mode"
    t.integer "reopen_count", default: 0, null: false
    t.datetime "request_received_at"
    t.jsonb "failed_response_counts", default: {}, null: false
    t.index ["approval_user_id"], name: "index_help_desk_tickets_on_approval_user_id"
    t.index ["assigned_to_user_id", "status"], name: "index_help_desk_tickets_on_assignee_and_status"
    t.index ["assigned_to_user_id"], name: "index_help_desk_tickets_on_assigned_to_user_id"
    t.index ["closed_by_user_id"], name: "index_help_desk_tickets_on_closed_by_user_id"
    t.index ["department_id"], name: "index_help_desk_tickets_on_department_id"
    t.index ["escalation_due_at"], name: "index_help_desk_tickets_on_escalation_due_at"
    t.index ["help_desk_question_master_id"], name: "index_help_desk_tickets_on_help_desk_question_master_id"
    t.index ["request_type"], name: "index_help_desk_tickets_on_request_type"
    t.index ["requester_response_due_at"], name: "index_help_desk_tickets_on_requester_response_due_at"
    t.index ["responded_by_user_id"], name: "index_help_desk_tickets_on_responded_by_user_id"
    t.index ["status"], name: "index_help_desk_tickets_on_status"
    t.index ["submitted_by_user_id"], name: "index_help_desk_tickets_on_submitted_by_user_id"
    t.index ["user_id", "created_at"], name: "index_help_desk_tickets_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_help_desk_tickets_on_user_id"
  end

  create_table "helpdesk_escalation_levels", force: :cascade do |t|
    t.bigint "helpdesk_escalation_matrix_id", null: false
    t.bigint "user_id", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["helpdesk_escalation_matrix_id", "position"], name: "index_helpdesk_levels_on_matrix_and_position", unique: true
    t.index ["helpdesk_escalation_matrix_id"], name: "index_helpdesk_levels_on_matrix_id"
    t.index ["user_id"], name: "index_helpdesk_escalation_levels_on_user_id"
  end

  create_table "helpdesk_escalation_matrices", force: :cascade do |t|
    t.bigint "department_id", null: false
    t.bigint "l1_user_id"
    t.bigint "l2_user_id"
    t.bigint "l3_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["department_id"], name: "index_helpdesk_escalation_matrices_on_department_id", unique: true
    t.index ["l1_user_id"], name: "index_helpdesk_escalation_matrices_on_l1_user_id"
    t.index ["l2_user_id"], name: "index_helpdesk_escalation_matrices_on_l2_user_id"
    t.index ["l3_user_id"], name: "index_helpdesk_escalation_matrices_on_l3_user_id"
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
    t.decimal "total_weightage", precision: 8, scale: 2
    t.decimal "weightage_q1", precision: 8, scale: 2
    t.decimal "weightage_q2", precision: 8, scale: 2
    t.decimal "weightage_q3", precision: 8, scale: 2
    t.decimal "weightage_q4", precision: 8, scale: 2
    t.text "annual_target"
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
  add_foreign_key "employee_trainings", "users"
  add_foreign_key "guest_house_booking_guests", "guest_house_bookings"
  add_foreign_key "guest_house_booking_guests", "users", column: "accepted_by_id"
  add_foreign_key "guest_house_bookings", "guest_houses"
  add_foreign_key "guest_house_bookings", "users"
  add_foreign_key "guest_house_bookings", "users", column: "accepted_by_id"
  add_foreign_key "guest_house_bookings", "users", column: "cancelled_by_id"
  add_foreign_key "guest_house_facilities", "guest_houses"
  add_foreign_key "guest_house_notifications", "guest_house_bookings"
  add_foreign_key "guest_house_notifications", "guest_house_waitlists"
  add_foreign_key "guest_house_notifications", "users"
  add_foreign_key "guest_house_notifications", "users", column: "actor_id"
  add_foreign_key "guest_house_waitlists", "guest_houses"
  add_foreign_key "guest_house_waitlists", "users"
  add_foreign_key "guest_houses", "users", column: "created_by_id"
  add_foreign_key "guest_houses", "users", column: "manager_user_id"
  add_foreign_key "help_desk_question_masters", "departments"
  add_foreign_key "help_desk_requester_remarks", "help_desk_tickets"
  add_foreign_key "help_desk_requester_remarks", "users"
  add_foreign_key "help_desk_support_updates", "help_desk_tickets"
  add_foreign_key "help_desk_support_updates", "users"
  add_foreign_key "help_desk_tickets", "departments"
  add_foreign_key "help_desk_tickets", "help_desk_question_masters", on_delete: :nullify
  add_foreign_key "help_desk_tickets", "users"
  add_foreign_key "help_desk_tickets", "users", column: "approval_user_id"
  add_foreign_key "help_desk_tickets", "users", column: "assigned_to_user_id"
  add_foreign_key "help_desk_tickets", "users", column: "closed_by_user_id"
  add_foreign_key "help_desk_tickets", "users", column: "responded_by_user_id"
  add_foreign_key "help_desk_tickets", "users", column: "submitted_by_user_id"
  add_foreign_key "helpdesk_escalation_levels", "helpdesk_escalation_matrices"
  add_foreign_key "helpdesk_escalation_levels", "users"
  add_foreign_key "helpdesk_escalation_matrices", "departments"
  add_foreign_key "helpdesk_escalation_matrices", "users", column: "l1_user_id"
  add_foreign_key "helpdesk_escalation_matrices", "users", column: "l2_user_id"
  add_foreign_key "helpdesk_escalation_matrices", "users", column: "l3_user_id"
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
