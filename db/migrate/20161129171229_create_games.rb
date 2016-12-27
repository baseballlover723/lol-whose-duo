class CreateGames < ActiveRecord::Migration[5.0]
  def change
    create_table :games do |t|
      t.string :game_id
      t.references :s1, index: true
      t.references :s2, index: true
      t.references :s3, index: true
      t.references :s4, index: true
      t.references :s5, index: true
      t.references :s6, index: true
      t.references :s7, index: true
      t.references :s8, index: true
      t.references :s9, index: true
      t.references :s10, index: true

      t.timestamps
    end
    # add_index :games, :summoner
  end
end
