class RenameTripPublicToPublicTrip < ActiveRecord::Migration[8.0]
  def change
    rename_column :trips, :public, :public_trip
  end
end
