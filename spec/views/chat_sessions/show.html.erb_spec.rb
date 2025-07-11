require 'rails_helper'

RSpec.describe "chat_sessions/show.html.erb", type: :view do
  let(:user) { create(:user) }
  let(:trip) { create(:trip, user: user, name: 'Test Trip') }
  let(:chat_session) { create(:chat_session, user: user, trip: trip) }
  let(:chat_message) { create(:chat_message, chat_session: chat_session, role: 'user', content: 'Hello AI') }

  before do
    assign(:chat_session, chat_session)
    assign(:trip, trip)
    assign(:chat_messages, [chat_message])
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:t).and_return('Chat Session')
    allow(view).to receive(:t).with('actions.back_to_trip').and_return('Back to Trip')
    allow(view).to receive(:t).with('trips.trip_info').and_return('Trip Info')
    allow(view).to receive(:t).with('trips.export_trip').and_return('Export Trip')
    allow(view).to receive(:t).with('trips.share_trip').and_return('Share Trip')
  end

  it "renders the chat interface" do
    render
    expect(rendered).to have_content('Test Trip')
    expect(rendered).to have_content('Back to Trip')
  end

  it "includes the chat messages container" do
    render
    expect(rendered).to have_css('#chat-messages')
  end

  it "includes the trip sidebar" do
    render
    expect(rendered).to have_css('#trip-sidebar')
  end

  it "includes export and share buttons" do
    render
    expect(rendered).to have_content('Export Trip')
    expect(rendered).to have_content('Share Trip')
  end

  it "includes the message form" do
    render
    expect(rendered).to have_css('.border-top')
  end

  it "includes JavaScript for auto-scrolling" do
    render
    expect(rendered).to include('document.addEventListener')
    expect(rendered).to include('turbo:frame-load')
  end
end
