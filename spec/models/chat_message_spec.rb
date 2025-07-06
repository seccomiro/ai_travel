require 'rails_helper'

RSpec.describe ChatMessage, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      chat_message = build(:chat_message)
      expect(chat_message).to be_valid
    end

    it 'is invalid without chat session' do
      chat_message = build(:chat_message, chat_session: nil)
      expect(chat_message).to_not be_valid
      expect(chat_message.errors[:chat_session]).to include('must exist')
    end

    it 'is invalid without content' do
      chat_message = build(:chat_message, content: nil)
      expect(chat_message).to_not be_valid
      expect(chat_message.errors[:content]).to include("can't be blank")
    end

    it 'is invalid with empty content' do
      chat_message = build(:chat_message, content: '')
      expect(chat_message).to_not be_valid
      expect(chat_message.errors[:content]).to include("can't be blank")
    end

    it 'is invalid with whitespace-only content' do
      chat_message = build(:chat_message, content: '   ')
      expect(chat_message).to_not be_valid
      expect(chat_message.errors[:content]).to include("can't be blank")
    end

    it 'is invalid without role' do
      chat_message = build(:chat_message, role: nil)
      expect(chat_message).to_not be_valid
      expect(chat_message.errors[:role]).to include("can't be blank")
    end

    it 'is invalid with invalid role' do
      chat_message = build(:chat_message)
      expect { chat_message.role = 'invalid_role' }.to raise_error(ArgumentError)
    end

    it 'is valid with valid roles' do
      %w[user assistant system].each do |role|
        chat_message = build(:chat_message, role: role)
        expect(chat_message).to be_valid
      end
    end

    it 'is invalid with content too long' do
      chat_message = build(:chat_message, content: 'a' * 10001)
      expect(chat_message).to_not be_valid
      expect(chat_message.errors[:content]).to include('is too long (maximum is 10000 characters)')
    end
  end

  describe 'associations' do
    it 'belongs to chat session' do
      association = described_class.reflect_on_association(:chat_session)
      expect(association.macro).to eq :belongs_to
    end
  end

  describe 'scopes' do
    let!(:chat_session) { create(:chat_session) }
    let!(:user_message) { create(:chat_message, chat_session: chat_session, role: 'user') }
    let!(:assistant_message) { create(:chat_message, chat_session: chat_session, role: 'assistant') }
    let!(:system_message) { create(:chat_message, chat_session: chat_session, role: 'system') }

    describe '.user_messages' do
      it 'returns only user messages' do
        expect(ChatMessage.user_messages).to contain_exactly(user_message)
      end
    end

    describe '.assistant_messages' do
      it 'returns only assistant messages' do
        expect(ChatMessage.assistant_messages).to contain_exactly(assistant_message)
      end
    end

    describe '.system_messages' do
      it 'returns only system messages' do
        expect(ChatMessage.system_messages).to contain_exactly(system_message)
      end
    end

    describe '.by_session' do
      it 'returns messages for specified chat session' do
        other_session = create(:chat_session)
        other_message = create(:chat_message, chat_session: other_session)

        expect(ChatMessage.by_session(chat_session)).to match_array([user_message, assistant_message, system_message])
        expect(ChatMessage.by_session(other_session)).to eq([other_message])
      end
    end

    describe '.recent' do
      it 'returns messages ordered by created_at desc' do
        old_message = create(:chat_message, chat_session: chat_session)
        sleep(0.01) # Ensure different timestamps
        new_message = create(:chat_message, chat_session: chat_session)

        expect(ChatMessage.recent.first).to eq(new_message)
      end
    end
  end

  describe 'instance methods' do
    let(:chat_session) { create(:chat_session) }
    let(:chat_message) { create(:chat_message, chat_session: chat_session) }

    describe '#user_message?' do
      it 'returns true for user messages' do
        chat_message.role = 'user'
        expect(chat_message.user_message?).to be true
      end

      it 'returns false for non-user messages' do
        chat_message.role = 'assistant'
        expect(chat_message.user_message?).to be false

        chat_message.role = 'system'
        expect(chat_message.user_message?).to be false
      end
    end

    describe '#assistant_message?' do
      it 'returns true for assistant messages' do
        chat_message.role = 'assistant'
        expect(chat_message.assistant_message?).to be true
      end

      it 'returns false for non-assistant messages' do
        chat_message.role = 'user'
        expect(chat_message.assistant_message?).to be false

        chat_message.role = 'system'
        expect(chat_message.assistant_message?).to be false
      end
    end

    describe '#system_message?' do
      it 'returns true for system messages' do
        chat_message.role = 'system'
        expect(chat_message.system_message?).to be true
      end

      it 'returns false for non-system messages' do
        chat_message.role = 'user'
        expect(chat_message.system_message?).to be false

        chat_message.role = 'assistant'
        expect(chat_message.system_message?).to be false
      end
    end

    describe '#formatted_content' do
      it 'returns content with line breaks converted to HTML' do
        chat_message.content = "Line 1\nLine 2\nLine 3"
        expect(chat_message.formatted_content).to eq("Line 1<br>Line 2<br>Line 3")
      end

      it 'returns content unchanged when no line breaks' do
        chat_message.content = "Single line content"
        expect(chat_message.formatted_content).to eq("Single line content")
      end
    end

    describe '#metadata_value' do
      it 'returns the value for a given key' do
        chat_message.metadata = { 'key1' => 'value1', 'key2' => 'value2' }
        expect(chat_message.metadata_value('key1')).to eq('value1')
        expect(chat_message.metadata_value('key2')).to eq('value2')
      end

      it 'returns nil for non-existent key' do
        chat_message.metadata = { 'key1' => 'value1' }
        expect(chat_message.metadata_value('nonexistent')).to be_nil
      end

      it 'returns nil when metadata is nil' do
        chat_message.metadata = nil
        expect(chat_message.metadata_value('key1')).to be_nil
      end
    end

    describe '#add_metadata' do
      it 'adds a key-value pair to metadata' do
        chat_message.metadata = { 'existing' => 'value' }
        chat_message.add_metadata('new_key', 'new_value')

        expect(chat_message.metadata).to eq({
          'existing' => 'value',
          'new_key' => 'new_value'
        })
      end

      it 'initializes metadata if nil' do
        chat_message.metadata = nil
        chat_message.add_metadata('key', 'value')

        expect(chat_message.metadata).to eq({ 'key' => 'value' })
      end

      it 'overwrites existing keys' do
        chat_message.metadata = { 'key' => 'old_value' }
        chat_message.add_metadata('key', 'new_value')

        expect(chat_message.metadata['key']).to eq('new_value')
      end
    end
  end

  describe 'callbacks' do
    let(:chat_session) { create(:chat_session) }

    describe 'before_validation' do
      it 'strips whitespace from content' do
        chat_message = ChatMessage.new(
          chat_session: chat_session,
          role: 'user',
          content: '  content with spaces  '
        )
        chat_message.valid?
        expect(chat_message.content).to eq('content with spaces')
      end
    end

    describe 'before_create' do
      it 'sets default metadata to empty hash' do
        chat_message = ChatMessage.create(
          chat_session: chat_session,
          role: 'user',
          content: 'Test message'
        )
        expect(chat_message.metadata).to eq({})
      end
    end
  end

  describe 'factory traits' do
    let(:chat_session) { create(:chat_session) }

    it 'creates assistant message with trait' do
      message = create(:chat_message, :assistant, chat_session: chat_session)
      expect(message.role).to eq('assistant')
      expect(message.content).to include('help you plan your trip')
    end

    it 'creates system message with trait' do
      message = create(:chat_message, :system, chat_session: chat_session)
      expect(message.role).to eq('system')
      expect(message.content).to include('travel planning assistant')
    end
  end
end
