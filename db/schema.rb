# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20161129171229) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "games", force: :cascade do |t|
    t.string   "game_id"
    t.integer  "s1_id"
    t.integer  "s2_id"
    t.integer  "s3_id"
    t.integer  "s4_id"
    t.integer  "s5_id"
    t.integer  "s6_id"
    t.integer  "s7_id"
    t.integer  "s8_id"
    t.integer  "s9_id"
    t.integer  "s10_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["s10_id"], name: "index_games_on_s10_id", using: :btree
    t.index ["s1_id"], name: "index_games_on_s1_id", using: :btree
    t.index ["s2_id"], name: "index_games_on_s2_id", using: :btree
    t.index ["s3_id"], name: "index_games_on_s3_id", using: :btree
    t.index ["s4_id"], name: "index_games_on_s4_id", using: :btree
    t.index ["s5_id"], name: "index_games_on_s5_id", using: :btree
    t.index ["s6_id"], name: "index_games_on_s6_id", using: :btree
    t.index ["s7_id"], name: "index_games_on_s7_id", using: :btree
    t.index ["s8_id"], name: "index_games_on_s8_id", using: :btree
    t.index ["s9_id"], name: "index_games_on_s9_id", using: :btree
  end

  create_table "summoners", force: :cascade do |t|
    t.string   "username"
    t.string   "stripped_username"
    t.string   "region"
    t.string   "summoner_id"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
  end

end
