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

ActiveRecord::Schema.define(version: 20170309054724) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "champions", force: :cascade do |t|
    t.string   "name"
    t.string   "title"
    t.string   "full_image_url"
    t.string   "sprite_image_url"
    t.string   "group_image_url"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
  end

  create_table "games", force: :cascade do |t|
    t.string   "game_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id"], name: "index_games_on_game_id", unique: true, using: :btree
  end

  create_table "games_summoners", id: false, force: :cascade do |t|
    t.integer "game_id",     null: false
    t.integer "summoner_id", null: false
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
