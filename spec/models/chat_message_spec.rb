require 'rails_helper'

RSpec.describe ChatMessage, type: :model do
  let(:user) { create(:user) }
  let(:trip) { create(:trip, user: user) }
  let(:chat_session) { create(:chat_session, user: user, trip: trip) }
  let(:chat_message) { build(:chat_message, chat_session: chat_session) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(chat_message).to be_valid
    end

    it 'is invalid without role' do
      chat_message.role = nil
      expect(chat_message).to_not be_valid
      expect(chat_message.errors[:role]).to include(I18n.t('errors.messages.inclusion'))
    end

    it 'is invalid with invalid role' do
      chat_message.role = 'invalid_role'
      expect(chat_message).to_not be_valid
      expect(chat_message.errors[:role]).to include(I18n.t('errors.messages.inclusion'))
    end

    it 'is invalid without content' do
      chat_message.content = nil
      expect(chat_message).to_not be_valid
      expect(chat_message.errors[:content]).to include(I18n.t('errors.messages.blank'))
    end

    it 'is invalid without chat_session' do
      chat_message.chat_session = nil
      expect(chat_message).to_not be_valid
      expect(chat_message.errors[:chat_session]).to include(I18n.t('errors.messages.required'))
    end

    it 'is valid with content too long' do
      chat_message.content = 'a' * 1000
      expect(chat_message).to be_valid
    end
  end

  describe 'callbacks' do
    it 'sets default metadata on initialization' do
      message = ChatMessage.new
      expect(message.metadata).to eq({})
    end
  end

  describe 'scopes' do
    let!(:user_message) { create(:chat_message, chat_session: chat_session, role: 'user') }
    let!(:assistant_message) { create(:chat_message, chat_session: chat_session, role: 'assistant') }
    let!(:system_message) { create(:chat_message, chat_session: chat_session, role: 'system') }

    describe '.by_role' do
      it 'returns messages for specified role' do
        expect(ChatMessage.by_role('user')).to match_array([user_message])
        expect(ChatMessage.by_role('assistant')).to match_array([assistant_message])
        expect(ChatMessage.by_role('system')).to match_array([system_message])
      end
    end

    describe '.recent' do
      it 'returns messages ordered by created_at desc' do
        expect(ChatMessage.recent).to eq([system_message, assistant_message, user_message])
      end
    end

    describe '.user_messages' do
      it 'returns only user messages' do
        expect(ChatMessage.user_messages).to match_array([user_message])
      end
    end

    describe '.assistant_messages' do
      it 'returns only assistant messages' do
        expect(ChatMessage.assistant_messages).to match_array([assistant_message])
      end
    end

    describe '.system_messages' do
      it 'returns only system messages' do
        expect(ChatMessage.system_messages).to match_array([system_message])
      end
    end
  end

  describe 'instance methods' do
    let(:user_message) { create(:chat_message, chat_session: chat_session, role: 'user') }
    let(:assistant_message) { create(:chat_message, chat_session: chat_session, role: 'assistant') }
    let(:system_message) { create(:chat_message, chat_session: chat_session, role: 'system') }

    describe '#user_message?' do
      it 'returns true for user messages' do
        expect(user_message.user_message?).to be true
        expect(assistant_message.user_message?).to be false
        expect(system_message.user_message?).to be false
      end
    end

    describe '#assistant_message?' do
      it 'returns true for assistant messages' do
        expect(user_message.assistant_message?).to be false
        expect(assistant_message.assistant_message?).to be true
        expect(system_message.assistant_message?).to be false
      end
    end

    describe '#system_message?' do
      it 'returns true for system messages' do
        expect(user_message.system_message?).to be false
        expect(assistant_message.system_message?).to be false
        expect(system_message.system_message?).to be true
      end
    end

    describe '#formatted_content' do
      it 'returns content as is' do
        expect(chat_message.formatted_content).to eq(chat_message.content)
      end

      it 'returns content with line breaks as is' do
        chat_message.content = "Line 1\nLine 2\nLine 3"
        expect(chat_message.formatted_content).to eq("Line 1\nLine 2\nLine 3")
      end
    end

    describe '#metadata_value' do
      it 'returns value for existing key' do
        chat_message.metadata = { 'key' => 'value' }
        expect(chat_message.metadata_value('key')).to eq('value')
      end

      it 'returns nil for non-existent key' do
        expect(chat_message.metadata_value('nonexistent')).to be_nil
      end
    end

    describe '#set_metadata' do
      it 'adds a key-value pair to metadata' do
        chat_message.set_metadata('new_key', 'new_value')
        expect(chat_message.metadata['new_key']).to eq('new_value')
      end

      it 'initializes metadata if nil' do
        chat_message.metadata = nil
        chat_message.set_metadata('key', 'value')
        expect(chat_message.metadata).to eq({ 'key' => 'value' })
      end

      it 'overwrites existing keys' do
        chat_message.metadata = { 'key' => 'old_value' }
        chat_message.set_metadata('key', 'new_value')
        expect(chat_message.metadata['key']).to eq('new_value')
      end
    end

    describe '#ai_tool_calls' do
      it 'returns tool calls from metadata' do
        tool_calls = [{ 'name' => 'get_weather', 'arguments' => { 'location' => 'Paris' } }]
        chat_message.metadata = { 'tool_calls' => tool_calls }
        expect(chat_message.ai_tool_calls).to eq(tool_calls)
      end

      it 'returns empty array when no tool calls' do
        expect(chat_message.ai_tool_calls).to eq([])
      end
    end

    describe '#ai_tool_results' do
      it 'returns tool results from metadata' do
        tool_results = [{ 'tool' => 'get_weather', 'result' => { 'temperature' => 20 } }]
        chat_message.metadata = { 'tool_results' => tool_results }
        expect(chat_message.ai_tool_results).to eq(tool_results)
      end

      it 'returns empty array when no tool results' do
        expect(chat_message.ai_tool_results).to eq([])
      end
    end

    describe '#has_tool_calls?' do
      it 'returns true when tool calls exist' do
        chat_message.metadata = { 'tool_calls' => [{ 'name' => 'get_weather' }] }
        expect(chat_message.has_tool_calls?).to be true
      end

      it 'returns false when no tool calls' do
        expect(chat_message.has_tool_calls?).to be false
      end
    end

    describe '#has_tool_results?' do
      it 'returns true when tool results exist' do
        chat_message.metadata = { 'tool_results' => [{ 'tool' => 'get_weather' }] }
        expect(chat_message.has_tool_results?).to be true
      end

      it 'returns false when no tool results' do
        expect(chat_message.has_tool_results?).to be false
      end
    end
  end
end

