class CreateSummoners < ActiveRecord::Migration[5.0]
  def change
    create_table :summoners do |t|
      t.string :username
      t.string :stripped_username
      t.string :region
      t.string :summoner_id

      t.timestamps
    end
  end
end
