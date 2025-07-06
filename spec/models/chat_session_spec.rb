require 'rails_helper'

RSpec.describe ChatSession, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      chat_session = build(:chat_session)
      expect(chat_session).to be_valid
    end

    it 'is invalid without trip' do
      chat_session = build(:chat_session, trip: nil)
      expect(chat_session).to_not be_valid
      expect(chat_session.errors[:trip]).to include('must exist')
    end

    it 'is invalid without user' do
      chat_session = build(:chat_session, user: nil)
      expect(chat_session).to_not be_valid
      expect(chat_session.errors[:user]).to include('must exist')
    end

    it 'is invalid with invalid status' do
      chat_session = build(:chat_session)
      expect { chat_session.status = 'invalid_status' }.to raise_error(ArgumentError)
    end

    it 'is valid with valid statuses' do
      %w[active completed archived].each do |status|
        chat_session = build(:chat_session, status: status)
        expect(chat_session).to be_valid
      end
    end
  end

  describe 'associations' do
    it 'belongs to trip' do
      association = described_class.reflect_on_association(:trip)
      expect(association.macro).to eq :belongs_to
    end

    it 'belongs to user' do
      association = described_class.reflect_on_association(:user)
      expect(association.macro).to eq :belongs_to
    end

    it 'has many chat messages' do
      association = described_class.reflect_on_association(:chat_messages)
      expect(association.macro).to eq :has_many
    end

    it 'destroys associated messages when chat session is destroyed' do
      chat_session = create(:chat_session)
      message = create(:chat_message, chat_session: chat_session)

      expect { chat_session.destroy }.to change(ChatMessage, :count).by(-1)
    end
  end

  describe 'scopes' do
    let!(:user) { create(:user) }
    let!(:trip) { create(:trip, user: user) }
    let!(:active_session) { create(:chat_session, trip: trip, user: user, status: 'active') }
    let!(:completed_session) { create(:chat_session, trip: trip, user: user, status: 'completed') }
    let!(:archived_session) { create(:chat_session, trip: trip, user: user, status: 'archived') }

    describe '.active' do
      it 'returns only active chat sessions' do
        expect(ChatSession.active).to contain_exactly(active_session)
      end
    end

    describe '.completed' do
      it 'returns only completed chat sessions' do
        expect(ChatSession.completed).to contain_exactly(completed_session)
      end
    end

    describe '.archived' do
      it 'returns only archived chat sessions' do
        expect(ChatSession.archived).to contain_exactly(archived_session)
      end
    end

    describe '.by_trip' do
      it 'returns chat sessions for specified trip' do
        other_trip = create(:trip, user: user)
        other_session = create(:chat_session, trip: other_trip, user: user)

        expect(ChatSession.by_trip(trip)).to match_array([active_session, completed_session, archived_session])
        expect(ChatSession.by_trip(other_trip)).to eq([other_session])
      end
    end

    describe '.recent' do
      it 'returns chat sessions ordered by created_at desc' do
        old_session = create(:chat_session, trip: trip, user: user)
        sleep(0.01) # Ensure different timestamps
        new_session = create(:chat_session, trip: trip, user: user)

        expect(ChatSession.recent.first).to eq(new_session)
      end
    end
  end

  describe 'instance methods' do
    let(:user) { create(:user) }
    let(:trip) { create(:trip, user: user) }
    let(:chat_session) { create(:chat_session, trip: trip, user: user) }

    describe '#message_count' do
      it 'returns the number of messages in the session' do
        create(:chat_message, chat_session: chat_session)
        create(:chat_message, chat_session: chat_session)
        create(:chat_message, chat_session: chat_session)

        expect(chat_session.message_count).to eq(3)
      end

      it 'returns 0 for new sessions' do
        expect(chat_session.message_count).to eq(0)
      end
    end

    describe '#last_message' do
      it 'returns the most recent message' do
        first_message = create(:chat_message, chat_session: chat_session, content: 'First')
        last_message = create(:chat_message, chat_session: chat_session, content: 'Last')

        expect(chat_session.last_message).to eq(last_message)
      end

      it 'returns nil for sessions with no messages' do
        expect(chat_session.last_message).to be_nil
      end
    end

    describe '#user_messages' do
      it 'returns only user messages' do
        user_message = create(:chat_message, chat_session: chat_session, role: 'user')
        assistant_message = create(:chat_message, chat_session: chat_session, role: 'assistant')

        expect(chat_session.user_messages).to contain_exactly(user_message)
      end
    end

    describe '#assistant_messages' do
      it 'returns only assistant messages' do
        user_message = create(:chat_message, chat_session: chat_session, role: 'user')
        assistant_message = create(:chat_message, chat_session: chat_session, role: 'assistant')

        expect(chat_session.assistant_messages).to contain_exactly(assistant_message)
      end
    end

    describe '#can_be_accessed_by?' do
      it 'returns true for the session owner' do
        expect(chat_session.can_be_accessed_by?(user)).to be true
      end

      it 'returns false for other users' do
        other_user = create(:user)
        expect(chat_session.can_be_accessed_by?(other_user)).to be false
      end

      it 'returns false for nil user' do
        expect(chat_session.can_be_accessed_by?(nil)).to be false
      end
    end

    describe '#update_context_summary' do
      it 'updates the context summary' do
        chat_session.update_context_summary('New summary')
        expect(chat_session.context_summary).to eq('New summary')
      end
    end
  end

  describe 'callbacks' do
    let(:user) { create(:user) }
    let(:trip) { create(:trip, user: user) }

    describe 'before_create' do
      it 'sets default status to active' do
        chat_session = ChatSession.create(trip: trip, user: user)
        expect(chat_session.status).to eq('active')
      end

      it 'sets default context_summary to empty string' do
        chat_session = ChatSession.create(trip: trip, user: user)
        expect(chat_session.context_summary).to eq('')
      end
    end
  end
end
