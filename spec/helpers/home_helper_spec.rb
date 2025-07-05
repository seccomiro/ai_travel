require 'rails_helper'

# Specs in this file have access to a helper object that includes
# the HomeHelper. For example:
#
# describe HomeHelper do
#   describe "string concat" do
#     it "concats two strings with spaces" do
#       expect(helper.concat_strings("this","that")).to eq("this that")
#     end
#   end
# end

RSpec.describe HomeHelper, type: :helper do
  describe '#welcome_message_for_time' do
    before do
      allow(helper).to receive(:t).with('home.good_morning').and_return('Good morning')
      allow(helper).to receive(:t).with('home.good_afternoon').and_return('Good afternoon')
      allow(helper).to receive(:t).with('home.good_evening').and_return('Good evening')
      allow(helper).to receive(:t).with('home.good_night').and_return('Good night')
    end

    it 'returns good morning for morning hours' do
      allow(Time).to receive(:current).and_return(Time.new(2024, 1, 1, 8, 0, 0))
      expect(helper.welcome_message_for_time).to eq('Good morning')
    end

    it 'returns good afternoon for afternoon hours' do
      allow(Time).to receive(:current).and_return(Time.new(2024, 1, 1, 14, 0, 0))
      expect(helper.welcome_message_for_time).to eq('Good afternoon')
    end

    it 'returns good evening for evening hours' do
      allow(Time).to receive(:current).and_return(Time.new(2024, 1, 1, 19, 0, 0))
      expect(helper.welcome_message_for_time).to eq('Good evening')
    end

    it 'returns good night for night hours' do
      allow(Time).to receive(:current).and_return(Time.new(2024, 1, 1, 23, 0, 0))
      expect(helper.welcome_message_for_time).to eq('Good night')
    end

    it 'returns good night for early morning hours' do
      allow(Time).to receive(:current).and_return(Time.new(2024, 1, 1, 2, 0, 0))
      expect(helper.welcome_message_for_time).to eq('Good night')
    end
  end

  describe '#user_greeting' do
    let(:user) { double('User', display_name: 'John Doe') }

    before do
      allow(helper).to receive(:t).with('home.welcome_guest').and_return('Welcome, Guest!')
      allow(helper).to receive(:welcome_message_for_time).and_return('Good morning')
    end

    it 'returns personalized greeting for logged in user' do
      expect(helper.user_greeting(user)).to eq('Good morning, John Doe!')
    end

    it 'returns guest greeting for nil user' do
      expect(helper.user_greeting(nil)).to eq('Welcome, Guest!')
    end
  end

  describe '#feature_highlights' do
    before do
      allow(helper).to receive(:t).with('home.features.ai_planning.title').and_return('AI Planning')
      allow(helper).to receive(:t).with('home.features.ai_planning.description').and_return('Smart trip planning')
      allow(helper).to receive(:t).with('home.features.interactive_maps.title').and_return('Interactive Maps')
      allow(helper).to receive(:t).with('home.features.interactive_maps.description').and_return('Visual trip planning')
      allow(helper).to receive(:t).with('home.features.collaboration.title').and_return('Collaboration')
      allow(helper).to receive(:t).with('home.features.collaboration.description').and_return('Plan together')
      allow(helper).to receive(:t).with('home.features.export.title').and_return('Export')
      allow(helper).to receive(:t).with('home.features.export.description').and_return('Download guides')
    end

    it 'returns array of feature highlights' do
      features = helper.feature_highlights
      expect(features).to be_an(Array)
      expect(features.length).to eq(4)
    end

    it 'includes AI planning feature' do
      features = helper.feature_highlights
      ai_feature = features.find { |f| f[:icon] == 'bi-chat-dots' }
      expect(ai_feature[:title]).to eq('AI Planning')
      expect(ai_feature[:description]).to eq('Smart trip planning')
    end

    it 'includes interactive maps feature' do
      features = helper.feature_highlights
      map_feature = features.find { |f| f[:icon] == 'bi-map' }
      expect(map_feature[:title]).to eq('Interactive Maps')
      expect(map_feature[:description]).to eq('Visual trip planning')
    end

    it 'includes collaboration feature' do
      features = helper.feature_highlights
      collab_feature = features.find { |f| f[:icon] == 'bi-people' }
      expect(collab_feature[:title]).to eq('Collaboration')
      expect(collab_feature[:description]).to eq('Plan together')
    end

    it 'includes export feature' do
      features = helper.feature_highlights
      export_feature = features.find { |f| f[:icon] == 'bi-download' }
      expect(export_feature[:title]).to eq('Export')
      expect(export_feature[:description]).to eq('Download guides')
    end
  end

  describe '#platform_stats' do
    let!(:user1) { create(:user) }
    let!(:user2) { create(:user) }
    let!(:trip1) { create(:trip, user: user1, status: 'active') }
    let!(:trip2) { create(:trip, user: user2, status: 'planning') }
    let!(:trip3) { create(:trip, user: user1, status: 'active') }

    it 'returns platform statistics' do
      stats = helper.platform_stats
      
      expect(stats[:total_trips]).to eq(3)
      expect(stats[:active_trips]).to eq(2)
      expect(stats[:total_users]).to eq(2)
      expect(stats[:this_month_trips]).to eq(3)
    end

    it 'includes recent trips in monthly count' do
      old_trip = create(:trip, user: user1, created_at: 2.months.ago)
      stats = helper.platform_stats
      
      expect(stats[:this_month_trips]).to eq(3) # Only recent trips
    end
  end

  describe '#recent_public_trips' do
    let!(:user) { create(:user) }
    
    before do
      # Clean up any existing trips from previous tests
      Trip.destroy_all
    end

    it 'returns only public trips' do
      public_trip1 = create(:trip, user: user, is_public: true)
      public_trip2 = create(:trip, user: user, is_public: true)
      private_trip = create(:trip, user: user, is_public: false)
      
      trips = helper.recent_public_trips
      expect(trips.count).to eq(2)
      expect(trips).to include(public_trip1, public_trip2)
      expect(trips).not_to include(private_trip)
    end

    it 'respects the limit parameter' do
      create(:trip, user: user, is_public: true)
      create(:trip, user: user, is_public: true)
      create(:trip, user: user, is_public: true)
      create(:trip, user: user, is_public: true)
      
      trips = helper.recent_public_trips(1)
      expect(trips.count).to eq(1)
    end

    it 'orders by recent first' do
      # Create trips with explicitly different timestamps
      older_trip = create(:trip, user: user, is_public: true)
      older_trip.update_column(:created_at, 1.day.ago)
      
      newer_trip = create(:trip, user: user, is_public: true)
      newer_trip.update_column(:created_at, 1.hour.ago)
      
      trips = helper.recent_public_trips
      expect(trips.first).to eq(newer_trip)
    end
  end
end
