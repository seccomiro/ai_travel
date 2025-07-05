class AddIsPublicToTrips < ActiveRecord::Migration[8.0]
  def change
    add_column :trips, :is_public, :boolean, default: false, null: false
  end
end
