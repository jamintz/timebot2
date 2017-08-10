class TimeType < ActiveRecord::Migration[5.0]
  def change
    change_column :entries, :time, :float
  end
end
