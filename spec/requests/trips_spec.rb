require 'rails_helper'

RSpec.describe "Trips", type: :request do
  let(:user) { create(:user) }
  let(:trip) { create(:trip, user: user) }

  before do
    sign_in user
  end

  describe "GET /trips" do
    it "returns http success" do
      get trips_path
      expect(response).to have_http_status(:success)
    end

    it "displays user's trips" do
      trip
      get trips_path
      expect(response.body).to include(trip.name) # Use name alias
    end
  end

  describe "GET /trips/:id" do
    it "returns http success" do
      get trip_path(trip)
      expect(response).to have_http_status(:success)
    end

    it "displays trip details" do
      get trip_path(trip)
      expect(response.body).to include(trip.name) # Use name alias
    end
  end

  describe "POST /trips" do
    it "creates a new trip and redirects to chat" do
      expect {
        post trips_path
      }.to change(Trip, :count).by(1)

      new_trip = Trip.last
      expect(response).to redirect_to(trip_chat_session_path(new_trip, new_trip.chat_sessions.first, locale: I18n.default_locale))
    end
  end

  describe "GET /trips/:id/edit" do
    it "returns http success" do
      get edit_trip_path(trip)
      expect(response).to have_http_status(:success)
    end

    it "displays the edit trip form" do
      get edit_trip_path(trip)
      expect(response.body).to include("Edit Trip")
    end
  end

  describe "PATCH /trips/:id" do
    it "updates the trip with valid params" do
      patch trip_path(trip), params: { trip: { name: "Updated Trip" } } # Use name alias
      trip.reload
      expect(trip.name).to eq("Updated Trip")
      expect(response).to redirect_to(trip_path(trip, locale: I18n.default_locale))
    end

    it "renders edit template with invalid params" do
      patch trip_path(trip), params: { trip: { name: "" } } # Use name alias
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /trips/:id" do
    it "deletes the trip" do
      trip_to_delete = create(:trip, user: user) # Create a fresh trip to delete
      expect {
        delete trip_path(trip_to_delete)
      }.to change(Trip, :count).by(-1)
      expect(response).to redirect_to(trips_path(locale: I18n.default_locale))
    end
  end

  describe "unauthorized access" do
    let(:other_user) { create(:user) }
    let(:other_trip) { create(:trip, user: other_user) }

    it "redirects when trying to access another user's trip" do
      get trip_path(other_trip)
      expect(response).to redirect_to(trips_path(locale: I18n.default_locale))
    end

    it "redirects when trying to edit another user's trip" do
      get edit_trip_path(other_trip)
      expect(response).to redirect_to(trips_path(locale: I18n.default_locale))
    end
  end

  describe "unauthenticated access" do
    it "redirects to sign in page" do
      sign_out user
      get trips_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
