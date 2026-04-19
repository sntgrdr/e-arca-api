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

ActiveRecord::Schema[8.1].define(version: 2026_04_14_190003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "batch_invoice_process_clients", force: :cascade do |t|
    t.bigint "batch_invoice_process_id", null: false
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["batch_invoice_process_id", "client_id"], name: "index_bip_clients_on_bip_id_and_client_id", unique: true
    t.index ["batch_invoice_process_id"], name: "idx_on_batch_invoice_process_id_c1f137dd10"
    t.index ["client_id"], name: "index_batch_invoice_process_clients_on_client_id"
  end

  create_table "batch_invoice_process_items", force: :cascade do |t|
    t.bigint "batch_invoice_process_id", null: false
    t.datetime "created_at", null: false
    t.bigint "item_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["batch_invoice_process_id", "item_id"], name: "index_bip_items_on_bip_id_and_item_id", unique: true
    t.index ["batch_invoice_process_id"], name: "index_batch_invoice_process_items_on_batch_invoice_process_id"
    t.index ["item_id"], name: "index_batch_invoice_process_items_on_item_id"
  end

  create_table "batch_invoice_processes", force: :cascade do |t|
    t.bigint "client_group_id"
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.jsonb "error_details", default: []
    t.text "error_message"
    t.integer "failed_invoices", default: 0, null: false
    t.string "invoice_type"
    t.bigint "item_id"
    t.boolean "pdf_generated", default: false, null: false
    t.date "period", null: false
    t.string "process_type", default: "per_client", null: false
    t.integer "processed_invoices", default: 0, null: false
    t.integer "quantity"
    t.bigint "sell_point_id", null: false
    t.string "status", default: "pending", null: false
    t.integer "total_invoices", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["client_group_id"], name: "index_batch_invoice_processes_on_client_group_id"
    t.index ["item_id"], name: "index_batch_invoice_processes_on_item_id"
    t.index ["sell_point_id"], name: "index_batch_invoice_processes_on_sell_point_id"
    t.index ["user_id"], name: "index_batch_invoice_processes_on_user_id"
  end

  create_table "client_groups", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "details"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_client_groups_on_user_id"
  end

  create_table "clients", force: :cascade do |t|
    t.boolean "active", default: true
    t.bigint "client_group_id"
    t.datetime "created_at", null: false
    t.string "dni"
    t.boolean "final_client", default: false, null: false
    t.bigint "iva_id"
    t.string "legal_name", default: "", null: false
    t.string "legal_number", default: "", null: false
    t.string "name"
    t.integer "tax_condition", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["client_group_id"], name: "index_clients_on_client_group_id"
    t.index ["iva_id"], name: "index_clients_on_iva_id"
    t.index ["legal_name"], name: "index_clients_on_legal_name", opclass: :gin_trgm_ops, using: :gin
    t.index ["name"], name: "index_clients_on_name", opclass: :gin_trgm_ops, using: :gin
    t.index ["user_id", "active"], name: "index_clients_on_user_id_and_active"
    t.index ["user_id", "final_client"], name: "index_clients_on_user_id_final_client_unique", unique: true, where: "(final_client = true)"
    t.index ["user_id", "legal_name"], name: "index_clients_on_user_id_and_legal_name"
    t.index ["user_id"], name: "index_clients_on_user_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.datetime "afip_authorized_at"
    t.string "afip_invoice_number"
    t.text "afip_response_xml"
    t.string "afip_result"
    t.string "afip_status", default: "draft", null: false
    t.bigint "batch_invoice_process_id"
    t.string "cae"
    t.date "cae_expiration"
    t.bigint "client_id", null: false
    t.bigint "client_invoice_id"
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.text "details"
    t.datetime "discarded_at"
    t.string "invoice_type", default: "C", null: false
    t.string "number", null: false
    t.date "period", null: false
    t.bigint "sell_point_id", null: false
    t.decimal "total_price", precision: 15, scale: 4
    t.string "type"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["afip_status"], name: "index_invoices_on_afip_status"
    t.index ["batch_invoice_process_id"], name: "index_invoices_on_batch_invoice_process_id"
    t.index ["client_id"], name: "index_invoices_on_client_id"
    t.index ["client_invoice_id"], name: "index_invoices_on_client_invoice_id"
    t.index ["discarded_at"], name: "index_invoices_on_discarded_at"
    t.index ["sell_point_id", "type", "invoice_type", "number"], name: "idx_unique_sellpoint_type_invoice_type_number", unique: true, where: "((discarded_at IS NULL) OR (cae IS NOT NULL))"
    t.index ["sell_point_id"], name: "index_invoices_on_sell_point_id"
    t.index ["user_id", "client_id"], name: "index_invoices_on_user_id_and_client_id"
    t.index ["user_id", "type", "created_at"], name: "index_invoices_on_user_id_type_created_at"
    t.index ["user_id", "type", "date"], name: "index_invoices_on_user_id_type_date"
    t.index ["user_id"], name: "index_invoices_on_user_id"
  end

  create_table "item_groups", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "details"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "name"], name: "index_item_groups_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_item_groups_on_user_id"
  end

  create_table "items", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code"
    t.datetime "created_at", null: false
    t.bigint "item_group_id"
    t.bigint "iva_id"
    t.string "name"
    t.decimal "price", precision: 15, scale: 4
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["item_group_id"], name: "index_items_on_item_group_id"
    t.index ["iva_id"], name: "index_items_on_iva_id"
    t.index ["user_id", "active"], name: "index_items_on_user_id_and_active"
    t.index ["user_id"], name: "index_items_on_user_id"
  end

  create_table "ivas", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.decimal "percentage", precision: 5, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["user_id"], name: "index_ivas_on_user_id"
  end

  create_table "jwt_denylists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "exp", null: false
    t.string "jti", null: false
    t.datetime "updated_at", null: false
    t.index ["jti"], name: "index_jwt_denylists_on_jti"
  end

  create_table "lines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.decimal "final_price", precision: 15, scale: 4
    t.bigint "item_id"
    t.bigint "iva_id"
    t.bigint "lineable_id"
    t.string "lineable_type"
    t.decimal "quantity", precision: 6, scale: 2
    t.decimal "unit_price", precision: 15, scale: 4
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["item_id"], name: "index_lines_on_item_id"
    t.index ["iva_id"], name: "index_lines_on_iva_id"
    t.index ["user_id"], name: "index_lines_on_user_id"
  end

  create_table "sell_points", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.boolean "default", default: false, null: false
    t.string "name"
    t.string "number", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["user_id"], name: "index_sell_points_on_user_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "account_number", default: "", null: false
    t.boolean "active", default: true
    t.date "activity_start"
    t.string "address"
    t.string "alias_account", default: "", null: false
    t.text "arca_sign"
    t.text "arca_token"
    t.datetime "arca_token_expires_at"
    t.string "cai", default: "", null: false
    t.string "city"
    t.string "country"
    t.datetime "created_at", null: false
    t.string "dni"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.string "legal_name", default: "", null: false
    t.string "legal_number", default: "", null: false
    t.datetime "locked_at"
    t.string "name", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "state"
    t.integer "tax_condition", default: 0, null: false
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.string "zip_code"
    t.index ["dni"], name: "index_users_on_dni", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["legal_name"], name: "index_users_on_legal_name", unique: true
    t.index ["legal_number"], name: "index_users_on_legal_number_unique_except_ones", unique: true, where: "((legal_number)::text <> '11-11111111-1'::text)"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.text "object_changes"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "batch_invoice_process_clients", "batch_invoice_processes"
  add_foreign_key "batch_invoice_process_clients", "clients"
  add_foreign_key "batch_invoice_process_items", "batch_invoice_processes"
  add_foreign_key "batch_invoice_process_items", "items"
  add_foreign_key "batch_invoice_processes", "client_groups"
  add_foreign_key "batch_invoice_processes", "items"
  add_foreign_key "batch_invoice_processes", "sell_points"
  add_foreign_key "batch_invoice_processes", "users"
  add_foreign_key "client_groups", "users"
  add_foreign_key "clients", "client_groups"
  add_foreign_key "clients", "ivas"
  add_foreign_key "clients", "users"
  add_foreign_key "invoices", "batch_invoice_processes"
  add_foreign_key "invoices", "clients"
  add_foreign_key "invoices", "invoices", column: "client_invoice_id"
  add_foreign_key "invoices", "sell_points"
  add_foreign_key "invoices", "users"
  add_foreign_key "item_groups", "users"
  add_foreign_key "items", "item_groups"
  add_foreign_key "ivas", "users"
  add_foreign_key "sell_points", "users"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
