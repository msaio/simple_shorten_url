class CreateUrls < ActiveRecord::Migration[8.0]
  def change
    create_table :urls do |t|
      t.text :original_url
      t.string :shortened_key

      t.timestamps
    end

    add_index :urls, :shortened_key, unique: true
    add_index :urls, :original_url, unique: true
  end
end
