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
      trip # Create the trip
      get trips_path
      expect(response.body).to include(trip.name)
    end
  end

  describe "GET /trips/:id" do
    it "returns http success" do
      get trip_path(trip)
      expect(response).to have_http_status(:success)
    end

    it "displays trip details" do
      get trip_path(trip)
      expect(response.body).to include(trip.name)
    end
  end

  describe "GET /trips/new" do
    it "returns http success" do
      get new_trip_path
      expect(response).to have_http_status(:success)
    end

    it "displays the new trip form" do
      get new_trip_path
      expect(response.body).to include("New Trip")
    end
  end

  describe "POST /trips" do
    it "creates a new trip with valid params" do
      trip_params = { trip: { name: "Test Trip", description: "A test trip" } }

      expect {
        post trips_path, params: trip_params
      }.to change(Trip, :count).by(1)

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(trip_path(Trip.last, locale: :en))
    end

    it "renders new template with invalid params" do
      trip_params = { trip: { name: "", description: "Invalid trip" } }

      post trips_path, params: trip_params
      expect(response).to have_http_status(:unprocessable_entity)
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
      trip_params = { trip: { name: "Updated Trip" } }

      patch trip_path(trip), params: trip_params
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(trip_path(trip, locale: :en))

      trip.reload
      expect(trip.name).to eq("Updated Trip")
    end

    it "renders edit template with invalid params" do
      trip_params = { trip: { name: "" } }

      patch trip_path(trip), params: trip_params
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /trips/:id" do
    it "deletes the trip" do
      trip # Create the trip first

      expect {
        delete trip_path(trip)
      }.to change(Trip, :count).by(-1)

      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(trips_path(locale: :en))
    end
  end

  describe "unauthorized access" do
    let(:other_user) { create(:user) }
    let(:other_trip) { create(:trip, user: other_user) }

    it "redirects when trying to access another user's trip" do
      get trip_path(other_trip)
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(trips_path(locale: :en))
    end

    it "redirects when trying to edit another user's trip" do
      get edit_trip_path(other_trip)
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(trips_path(locale: :en))
    end
  end

  describe "unauthenticated access" do
    it "redirects to sign in page" do
      sign_out user
      get trips_path
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
