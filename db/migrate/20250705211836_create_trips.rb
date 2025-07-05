class CreateTrips < ActiveRecord::Migration[8.0]
  def change
    create_table :trips do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.date :start_date
      t.date :end_date
      t.string :status, default: 'planning'
      t.jsonb :trip_data, default: {}
      t.jsonb :sharing_settings, default: {}

      t.timestamps
    end

    add_index :trips, [:user_id, :status]
    add_index :trips, :trip_data, using: :gin
    add_index :trips, :sharing_settings, using: :gin
  end
end
