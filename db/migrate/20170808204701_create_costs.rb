class CreateCosts < ActiveRecord::Migration[5.0]
  def change
    create_table :costs do |t|
      t.integer :code
      t.string :title
      t.string :category

      t.timestamps
    end
  end
end
