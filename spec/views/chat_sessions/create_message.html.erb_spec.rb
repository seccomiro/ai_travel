require 'rails_helper'

RSpec.describe "chat_sessions/create_message.html.erb", type: :view do
  let(:user) { create(:user) }
  let(:trip) { create(:trip, user: user) }
  let(:chat_session) { create(:chat_session, user: user, trip: trip) }

  before do
    assign(:chat_session, chat_session)
    assign(:trip, trip)
    allow(view).to receive(:current_user).and_return(user)
  end

  it "displays the create message page title" do
    render
    expect(rendered).to have_content("ChatSessions#create_message")
  end

  it "includes the template location information" do
    render
    expect(rendered).to have_content("Find me in app/views/chat_sessions/create_message.html.erb")
  end
end
