class CreateChampions < ActiveRecord::Migration[5.0]
  def change
    create_table :champions do |t|
      t.string :name
      t.string :title
      t.string :full_image_url
      t.string :sprite_image_url
      t.string :group_image_url

      t.timestamps
    end
  end
end
