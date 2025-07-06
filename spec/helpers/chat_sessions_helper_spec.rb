require 'rails_helper'

# Specs in this file have access to a helper object that includes
# the ChatSessionsHelper. For example:
#
# describe ChatSessionsHelper do
#   describe "string concat" do
#     it "concats two strings with spaces" do
#       expect(helper.concat_strings("this","that")).to eq("this that")
#     end
#   end
# end
RSpec.describe ChatSessionsHelper, type: :helper do
  let(:user) { create(:user, first_name: 'John', last_name: 'Doe') }
  let(:trip) { create(:trip, user: user, name: 'Paris Adventure') }
  let(:chat_session) { create(:chat_session, trip: trip, user: user) }
  let(:user_message) { create(:chat_message, chat_session: chat_session, role: 'user', content: 'Hello AI!') }
  let(:assistant_message) { create(:chat_message, chat_session: chat_session, role: 'assistant', content: 'Hello! How can I help you?') }

  describe '#message_role_class' do
    it 'returns correct class for user messages' do
      expect(helper.message_role_class(user_message)).to eq('user-message')
    end

    it 'returns correct class for assistant messages' do
      expect(helper.message_role_class(assistant_message)).to eq('assistant-message')
    end

    it 'returns correct class for system messages' do
      system_message = create(:chat_message, chat_session: chat_session, role: 'system', content: 'System message')
      expect(helper.message_role_class(system_message)).to eq('system-message')
    end
  end

  describe '#message_bubble_class' do
    it 'returns correct bubble class for user messages' do
      expect(helper.message_bubble_class(user_message)).to eq('bg-primary text-white')
    end

    it 'returns correct bubble class for assistant messages' do
      expect(helper.message_bubble_class(assistant_message)).to eq('bg-light')
    end

    it 'returns correct bubble class for system messages' do
      system_message = create(:chat_message, chat_session: chat_session, role: 'system', content: 'System message')
      expect(helper.message_bubble_class(system_message)).to eq('bg-warning')
    end
  end

  describe '#message_icon_class' do
    it 'returns correct icon for user messages' do
      expect(helper.message_icon_class(user_message)).to eq('bi-person')
    end

    it 'returns correct icon for assistant messages' do
      expect(helper.message_icon_class(assistant_message)).to eq('bi-robot')
    end

    it 'returns correct icon for system messages' do
      system_message = create(:chat_message, chat_session: chat_session, role: 'system', content: 'System message')
      expect(helper.message_icon_class(system_message)).to eq('bi-gear')
    end
  end

  describe '#message_sender_name' do
    it 'returns "You" for user messages' do
      expect(helper.message_sender_name(user_message)).to eq('You')
    end

    it 'returns "Tripyo AI" for assistant messages' do
      expect(helper.message_sender_name(assistant_message)).to eq('Tripyo AI')
    end

    it 'returns "System" for system messages' do
      system_message = create(:chat_message, chat_session: chat_session, role: 'system', content: 'System message')
      expect(helper.message_sender_name(system_message)).to eq('System')
    end
  end

  describe '#format_message_time' do
    it 'formats message time correctly' do
      message = create(:chat_message, chat_session: chat_session, created_at: Time.current)
      formatted_time = helper.format_message_time(message)
      
      expect(formatted_time).to match(/\d{2} \w{3} \d{2}:\d{2}/)
    end

    it 'handles nil created_at' do
      message = build(:chat_message, chat_session: chat_session, created_at: nil)
      expect(helper.format_message_time(message)).to eq('')
    end
  end

  describe '#message_metadata_display' do
    it 'returns empty string for messages without metadata' do
      expect(helper.message_metadata_display(user_message)).to eq('')
    end

    it 'displays metadata when present' do
      user_message.metadata = { 'tool_used' => 'get_weather', 'location' => 'Paris' }
      result = helper.message_metadata_display(user_message)
      
      expect(result).to include('tool_used')
      expect(result).to include('get_weather')
      expect(result).to include('location')
      expect(result).to include('Paris')
    end

    it 'handles empty metadata hash' do
      user_message.metadata = {}
      expect(helper.message_metadata_display(user_message)).to eq('')
    end
  end

  describe '#chat_session_status_badge' do
    it 'returns correct badge for active session' do
      chat_session.status = 'active'
      badge = helper.chat_session_status_badge(chat_session)
      
      expect(badge).to include('badge')
      expect(badge).to include('bg-success')
      expect(badge).to include('Active')
    end

    it 'returns correct badge for completed session' do
      chat_session.status = 'completed'
      badge = helper.chat_session_status_badge(chat_session)
      
      expect(badge).to include('badge')
      expect(badge).to include('bg-secondary')
      expect(badge).to include('Completed')
    end

    it 'returns correct badge for archived session' do
      chat_session.status = 'archived'
      badge = helper.chat_session_status_badge(chat_session)
      
      expect(badge).to include('badge')
      expect(badge).to include('bg-dark')
      expect(badge).to include('Archived')
    end
  end

  describe '#message_count_display' do
    it 'returns correct count for single message' do
      create(:chat_message, chat_session: chat_session)
      expect(helper.message_count_display(chat_session)).to eq('1 message')
    end

    it 'returns correct count for multiple messages' do
      create(:chat_message, chat_session: chat_session)
      create(:chat_message, chat_session: chat_session)
      create(:chat_message, chat_session: chat_session)
      expect(helper.message_count_display(chat_session)).to eq('3 messages')
    end

    it 'returns "No messages" for empty session' do
      expect(helper.message_count_display(chat_session)).to eq('No messages')
    end
  end

  describe '#last_activity_display' do
    it 'returns "Never" for session without messages' do
      expect(helper.last_activity_display(chat_session)).to eq('Never')
    end

    it 'returns formatted time for session with messages' do
      create(:chat_message, chat_session: chat_session, created_at: 1.hour.ago)
      result = helper.last_activity_display(chat_session)
      
      expect(result).to match(/\d+ hours? ago/)
    end

    it 'returns "Just now" for recent activity' do
      create(:chat_message, chat_session: chat_session, created_at: 30.seconds.ago)
      expect(helper.last_activity_display(chat_session)).to eq('Just now')
    end
  end

  describe '#chat_session_summary' do
    it 'returns summary for session with messages' do
      create(:chat_message, chat_session: chat_session, content: 'I want to go to Paris')
      create(:chat_message, chat_session: chat_session, role: 'assistant', content: 'Great! When are you planning to travel?')
      
      summary = helper.chat_session_summary(chat_session)
      expect(summary).to include('Paris')
    end

    it 'returns default summary for empty session' do
      summary = helper.chat_session_summary(chat_session)
      expect(summary).to eq('No messages yet')
    end

    it 'truncates long summaries' do
      long_content = 'A' * 200
      create(:chat_message, chat_session: chat_session, content: long_content)
      
      summary = helper.chat_session_summary(chat_session)
      expect(summary.length).to be <= 100
      expect(summary).to end_with('...')
    end
  end

  describe '#typing_indicator_html' do
    it 'returns typing indicator HTML' do
      html = helper.typing_indicator_html
      
      expect(html).to include('typing-indicator')
      expect(html).to include('dot')
      expect(html).to include('AI is typing')
    end
  end

  describe '#message_form_placeholder' do
    it 'returns appropriate placeholder for new session' do
      expect(helper.message_form_placeholder(chat_session)).to include('Tell me about your trip plans')
    end

    it 'returns contextual placeholder for ongoing session' do
      create(:chat_message, chat_session: chat_session, content: 'I want to go to Paris')
      expect(helper.message_form_placeholder(chat_session)).to include('Ask about destinations')
    end
  end
end
