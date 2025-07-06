require 'rails_helper'

RSpec.describe ChatSession, type: :model do
  let(:user) { create(:user) }
  let(:trip) { create(:trip, user: user) }
  let(:chat_session) { build(:chat_session, user: user, trip: trip) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(chat_session).to be_valid
    end

    it 'is invalid without trip' do
      chat_session.trip = nil
      expect(chat_session).to_not be_valid
      expect(chat_session.errors[:trip]).to include(I18n.t('errors.messages.required'))
    end

    it 'is invalid without user' do
      chat_session.user = nil
      expect(chat_session).to_not be_valid
      expect(chat_session.errors[:user]).to include(I18n.t('errors.messages.required'))
    end

    it 'is valid with valid statuses' do
      %w[active completed archived].each do |status|
        chat_session.status = status
        expect(chat_session).to be_valid
      end
    end
  end

  describe 'enums' do
    it 'defines status enum' do
      expect(described_class.statuses).to eq({
        'active' => 'active',
        'completed' => 'completed',
        'archived' => 'archived'
      })
    end
  end

  describe 'callbacks' do
    it 'sets default status on initialization' do
      session = ChatSession.new
      expect(session.status).to eq('active')
    end

    it 'sets default context_summary on initialization' do
      session = ChatSession.new
      expect(session.context_summary).to eq('')
    end
  end

  describe 'scopes' do
    let!(:active_session) { create(:chat_session, user: user, trip: trip, status: 'active') }
    let!(:completed_session) { create(:chat_session, user: user, trip: trip, status: 'completed') }
    let!(:archived_session) { create(:chat_session, user: user, trip: trip, status: 'archived') }

    describe '.active' do
      it 'returns only active sessions' do
        expect(ChatSession.active).to match_array([active_session])
      end
    end

    describe '.recent' do
      it 'returns sessions ordered by created_at desc' do
        expect(ChatSession.recent).to eq([archived_session, completed_session, active_session])
      end
    end

    describe '.by_trip' do
      it 'returns sessions for specified trip' do
        other_trip = create(:trip, user: user)
        other_session = create(:chat_session, user: user, trip: other_trip)
        
        expect(ChatSession.by_trip(trip)).to match_array([active_session, completed_session, archived_session])
        expect(ChatSession.by_trip(other_trip)).to eq([other_session])
      end
    end

    describe '.by_user' do
      it 'returns sessions for specified user' do
        other_user = create(:user)
        other_session = create(:chat_session, user: other_user, trip: trip)
        
        expect(ChatSession.by_user(user)).to match_array([active_session, completed_session, archived_session])
        expect(ChatSession.by_user(other_user)).to eq([other_session])
      end
    end
  end

  describe 'instance methods' do
    let(:chat_session) { create(:chat_session, user: user, trip: trip) }

    describe '#active?' do
      it 'returns true for active sessions' do
        chat_session.status = 'active'
        expect(chat_session.active?).to be true
      end

      it 'returns false for non-active sessions' do
        chat_session.status = 'completed'
        expect(chat_session.active?).to be false
        
        chat_session.status = 'archived'
        expect(chat_session.active?).to be false
      end
    end

    describe '#completed?' do
      it 'returns true for completed sessions' do
        chat_session.status = 'completed'
        expect(chat_session.completed?).to be true
      end

      it 'returns false for non-completed sessions' do
        chat_session.status = 'active'
        expect(chat_session.completed?).to be false
        
        chat_session.status = 'archived'
        expect(chat_session.completed?).to be false
      end
    end

    describe '#archived?' do
      it 'returns true for archived sessions' do
        chat_session.status = 'archived'
        expect(chat_session.archived?).to be true
      end

      it 'returns false for non-archived sessions' do
        chat_session.status = 'active'
        expect(chat_session.archived?).to be false
        
        chat_session.status = 'completed'
        expect(chat_session.archived?).to be false
      end
    end

    describe '#message_count' do
      it 'returns correct message count' do
        expect(chat_session.message_count).to eq(0)
        
        create(:chat_message, chat_session: chat_session)
        expect(chat_session.message_count).to eq(1)
        
        create(:chat_message, chat_session: chat_session)
        expect(chat_session.message_count).to eq(2)
      end
    end

    describe '#last_message' do
      it 'returns the most recent message' do
        first_message = create(:chat_message, chat_session: chat_session, created_at: 1.hour.ago)
        last_message = create(:chat_message, chat_session: chat_session, created_at: Time.current)
        
        expect(chat_session.last_message).to eq(last_message)
      end

      it 'returns nil when no messages' do
        expect(chat_session.last_message).to be_nil
      end
    end

    describe '#user_messages' do
      it 'returns only user messages' do
        user_message = create(:chat_message, chat_session: chat_session, role: 'user')
        create(:chat_message, chat_session: chat_session, role: 'assistant')
        
        expect(chat_session.user_messages).to eq([user_message])
      end
    end

    describe '#assistant_messages' do
      it 'returns only assistant messages' do
        create(:chat_message, chat_session: chat_session, role: 'user')
        assistant_message = create(:chat_message, chat_session: chat_session, role: 'assistant')
        
        expect(chat_session.assistant_messages).to eq([assistant_message])
      end
    end

    describe '#system_messages' do
      it 'returns only system messages' do
        create(:chat_message, chat_session: chat_session, role: 'user')
        system_message = create(:chat_message, chat_session: chat_session, role: 'system')
        
        expect(chat_session.system_messages).to eq([system_message])
      end
    end

    describe '#update_context_summary' do
      it 'updates the context summary' do
        chat_session.update_context_summary('New summary')
        expect(chat_session.context_summary).to eq('New summary')
      end
    end

    describe '#conversation_history' do
      it 'returns conversation history as array of role-content pairs' do
        create(:chat_message, chat_session: chat_session, role: 'user', content: 'Hello')
        create(:chat_message, chat_session: chat_session, role: 'assistant', content: 'Hi there!')
        
        history = chat_session.conversation_history
        expect(history).to eq([
          ['user', 'Hello'],
          ['assistant', 'Hi there!']
        ])
      end

      it 'returns empty array when no messages' do
        expect(chat_session.conversation_history).to eq([])
      end
    end

    describe '#conversation_for_ai' do
      it 'returns conversation formatted for AI with system message' do
        create(:chat_message, chat_session: chat_session, role: 'user', content: 'Hello')
        create(:chat_message, chat_session: chat_session, role: 'assistant', content: 'Hi there!')
        
        conversation = chat_session.conversation_for_ai
        
        expect(conversation.length).to eq(3)
        expect(conversation.first[:role]).to eq('system')
        expect(conversation.first[:content]).to include('Tripyo')
        expect(conversation[1][:role]).to eq('user')
        expect(conversation[1][:content]).to eq('Hello')
        expect(conversation[2][:role]).to eq('assistant')
        expect(conversation[2][:content]).to eq('Hi there!')
      end

      it 'returns only system message when no conversation' do
        conversation = chat_session.conversation_for_ai
        
        expect(conversation.length).to eq(1)
        expect(conversation.first[:role]).to eq('system')
        expect(conversation.first[:content]).to include('Tripyo')
      end
    end
  end
end

