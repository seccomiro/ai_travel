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

ActiveRecord::Schema[8.0].define(version: 2025_07_06_010109) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "chat_messages", force: :cascade do |t|
    t.bigint "chat_session_id", null: false
    t.string "role"
    t.text "content"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_session_id"], name: "index_chat_messages_on_chat_session_id"
  end

  create_table "chat_sessions", force: :cascade do |t|
    t.bigint "trip_id", null: false
    t.bigint "user_id", null: false
    t.text "context_summary"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["trip_id"], name: "index_chat_sessions_on_trip_id"
    t.index ["user_id"], name: "index_chat_sessions_on_user_id"
  end

  create_table "trips", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.text "description"
    t.date "start_date"
    t.date "end_date"
    t.string "status", default: "planning"
    t.jsonb "trip_data", default: {}
    t.jsonb "sharing_settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_public", default: false, null: false
    t.index ["sharing_settings"], name: "index_trips_on_sharing_settings", using: :gin
    t.index ["trip_data"], name: "index_trips_on_trip_data", using: :gin
    t.index ["user_id", "status"], name: "index_trips_on_user_id_and_status"
    t.index ["user_id"], name: "index_trips_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "first_name"
    t.string "last_name"
    t.string "preferred_language", default: "en"
    t.string "timezone", default: "UTC"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "chat_messages", "chat_sessions"
  add_foreign_key "chat_sessions", "trips"
  add_foreign_key "chat_sessions", "users"
  add_foreign_key "trips", "users"
end
