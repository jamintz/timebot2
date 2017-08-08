class CreateEntries < ActiveRecord::Migration[5.0]
  def change
    create_table :entries do |t|
      t.integer :user_id
      t.string :email
      t.datetime :date
      t.integer :deal_id
      t.string :kind
      t.text :note
      t.integer :activity_id
      t.integer :time
      t.string :title
      t.string :user_name

      t.timestamps
    end
  end
end