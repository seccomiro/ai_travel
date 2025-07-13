# frozen_string_literal: true

class AddOriginAndDestinationToTrips < ActiveRecord::Migration[8.0]
  def change
    add_column :trips, :origin, :string
    add_column :trips, :destination, :string
  end
end
