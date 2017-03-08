class CreateGames < ActiveRecord::Migration[5.0]
  def change
    create_table :games do |t|
      t.string :game_id

      t.timestamps
    end
    add_index :games, :game_id, unique: true
    create_join_table :games, :summoners
  end
end
