class CreateGames < ActiveRecord::Migration[5.0]
  def change
    create_table :games do |t|
      t.string :game_id

      t.timestamps
    end

    create_join_table :games, :summoners
  end
end
