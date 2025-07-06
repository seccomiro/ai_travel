require 'rails_helper'

RSpec.describe 'ChatSessions', type: :request do
  let(:user) { create(:user) }
  let(:trip) { create(:trip, user: user) }
  let(:chat_session) { create(:chat_session, user: user, trip: trip) }

  before do
    sign_in user, scope: :user
  end

  describe 'GET /trips/:trip_id/chat_sessions/:id' do
    it 'returns http success' do
      get trip_chat_session_path(trip, chat_session)
      expect(response).to have_http_status(:success)
    end

    it 'displays the chat session' do
      get trip_chat_session_path(trip, chat_session)
      expect(response.body).to include('chat')
    end

    it 'redirects if user doesn\'t own the trip' do
      other_trip = create(:trip, user: create(:user))
      other_session = create(:chat_session, user: other_trip.user, trip: other_trip)
      
      get trip_chat_session_path(other_trip, other_session)
      expect(response).to redirect_to(trips_path + '?locale=en')
    end
  end

  describe 'POST /trips/:trip_id/chat_sessions' do
    it 'creates a new chat session' do
      expect {
        post trip_chat_sessions_path(trip)
      }.to change(ChatSession, :count).by(1)

      expect(response).to redirect_to(trip_chat_session_path(trip, ChatSession.last) + '?locale=en')
    end

    it 'associates the session with the correct trip and user' do
      post trip_chat_sessions_path(trip)
      
      new_session = ChatSession.last
      expect(new_session.trip).to eq(trip)
      expect(new_session.user).to eq(user)
    end
  end

  describe 'POST /trips/:trip_id/chat_sessions/:id/create_message' do
    let(:valid_params) { { content: 'Hello AI!' } }

    it 'creates a new message' do
      expect {
        post create_message_trip_chat_session_path(trip, chat_session), 
             params: valid_params, 
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      }.to change(ChatMessage, :count).by(2) # user + assistant

      expect(response).to have_http_status(:success)
    end

    it 'associates the message with the correct session' do
      post create_message_trip_chat_session_path(trip, chat_session), 
           params: valid_params, 
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      
      user_message = ChatMessage.order(:created_at).first
      expect(user_message.chat_session).to eq(chat_session)
      expect(user_message.role).to eq('user')
      expect(user_message.content).to eq('Hello AI!')
    end

    it 'returns error for invalid message' do
      invalid_params = { content: '' }
      
      expect {
        post create_message_trip_chat_session_path(trip, chat_session), 
             params: invalid_params, 
             headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      }.not_to change(ChatMessage, :count)

      expect(response).to have_http_status(:success)
    end

    it 'redirects if user doesn\'t own the trip' do
      other_trip = create(:trip, user: create(:user))
      other_session = create(:chat_session, user: other_trip.user, trip: other_trip)
      
      post create_message_trip_chat_session_path(other_trip, other_session), 
           params: valid_params, 
           headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      expect(response).to redirect_to(trips_path + '?locale=en')
    end
  end
end
