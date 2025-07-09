class RenameTripIsPublicToPublic < ActiveRecord::Migration[8.0]
  def change
    rename_column :trips, :is_public, :public
  end
end
