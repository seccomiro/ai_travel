require 'rails_helper'

RSpec.describe "ChatSessions", type: :request do
  let(:user) { create(:user) }
  let(:trip) { create(:trip, user: user) }
  let(:chat_session) { create(:chat_session, trip: trip, user: user) }

  before do
    sign_in user, scope: :user
  end

  describe "GET /trips/:trip_id/chat_sessions/:id" do
    it "returns http success" do
      get trip_chat_session_path(trip, chat_session)
      expect(response).to have_http_status(:success)
    end

    it "redirects if user doesn't own the trip" do
      other_trip = create(:trip)
      other_chat_session = create(:chat_session, trip: other_trip)

      get trip_chat_session_path(other_trip, other_chat_session)
      expect(response).to redirect_to(trips_path)
    end
  end

  describe "POST /trips/:trip_id/chat_sessions" do
    it "creates a new chat session" do
      expect {
        post trip_chat_sessions_path(trip)
      }.to change(ChatSession, :count).by(1)

      expect(response).to redirect_to(trip_chat_session_path(trip, ChatSession.last))
    end
  end

  describe "POST /trips/:trip_id/chat_sessions/:id/create_message" do
    it "creates a new message" do
      expect {
        post create_message_trip_chat_session_path(trip, chat_session), params: { content: "Hello AI!" }
      }.to change(ChatMessage, :count).by(2) # User message + AI response

      expect(response).to have_http_status(:success)
    end

    it "returns error for invalid message" do
      expect {
        post create_message_trip_chat_session_path(trip, chat_session), params: { content: "" }
      }.not_to change(ChatMessage, :count)

      expect(response).to have_http_status(:success)
    end
  end
end
