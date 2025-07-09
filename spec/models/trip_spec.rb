require 'rails_helper'

RSpec.describe Trip, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      trip = build(:trip)
      expect(trip).to be_valid
    end

    it 'is invalid without name' do
      trip = build(:trip, name: nil)
      expect(trip).to_not be_valid
    end

    it 'is invalid without user' do
      trip = build(:trip, user: nil)
      expect(trip).to_not be_valid
    end

    it 'is invalid with name too long' do
      trip = build(:trip, name: 'a' * 256)
      expect(trip).to_not be_valid
    end

    it 'is invalid with invalid status' do
      trip = build(:trip)
      expect { trip.status = 'invalid_status' }.not_to raise_error
      expect(trip).to_not be_valid
    end

    it 'validates end_date is after start_date' do
      trip = build(:trip, start_date: Date.current, end_date: Date.current - 1.day)
      expect(trip).to_not be_valid
      expect(trip.errors[:end_date]).to include('must be after start date')
    end

    it 'is valid when end_date is same as start_date' do
      trip = build(:trip, start_date: Date.current, end_date: Date.current)
      expect(trip).to be_valid
    end

    it 'is valid when dates are nil' do
      trip = build(:trip, start_date: nil, end_date: nil)
      expect(trip).to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to user' do
      association = described_class.reflect_on_association(:user)
      expect(association.macro).to eq :belongs_to
    end
  end

  describe 'scopes' do
    let!(:user) { create(:user) }
    let!(:planning_trip) { create(:trip, user: user, status: 'planning') }
    let!(:active_trip) { create(:trip, user: user, status: 'active') }
    let!(:completed_trip) { create(:trip, user: user, status: 'completed') }
    let!(:public_trip) { create(:trip, user: user, status: 'active', public_trip: true) }
    let!(:private_trip) { create(:trip, user: user, status: 'completed', public_trip: false) }

    describe '.planning' do
      it 'returns only planning trips' do
        expect(Trip.planning).to contain_exactly(planning_trip)
      end
    end

    describe '.active' do
      it 'returns only active trips' do
        expect(Trip.active).to contain_exactly(active_trip, public_trip)
      end
    end

    describe '.completed' do
      it 'returns only completed trips' do
        expect(Trip.completed).to contain_exactly(completed_trip, private_trip)
      end
    end

    describe '.public_trips' do
      it 'returns only public trips' do
        expect(Trip.public_trips).to contain_exactly(public_trip)
      end
    end

    describe '.by_user' do
      it 'returns trips for specified user' do
        user2 = create(:user)
        other_trip = create(:trip, user: user2)

        expect(Trip.by_user(user)).to match_array([planning_trip, active_trip, completed_trip, public_trip, private_trip])
        expect(Trip.by_user(user2)).to eq([other_trip])
      end
    end

    describe '.recent' do
      it 'returns trips ordered by created_at desc' do
        old_trip = create(:trip, user: user)
        sleep(0.01) # Ensure different timestamps
        new_trip = create(:trip, user: user)

        expect(Trip.recent.first).to eq(new_trip)
      end
    end
  end

  describe 'instance methods' do
    let(:user) { create(:user) }
    let(:trip) { create(:trip, user: user, name: 'Test Trip', description: 'A test trip') }

    describe '#duration_in_days' do
      it 'returns correct duration when both dates are present' do
        trip.start_date = Date.current
        trip.end_date = Date.current + 5.days
        expect(trip.duration_in_days).to eq(6)
      end

      it 'returns nil when dates are not set' do
        trip.start_date = nil
        trip.end_date = nil
        expect(trip.duration_in_days).to be_nil
      end

      it 'returns nil when only start date is set' do
        trip.start_date = Date.current
        trip.end_date = nil
        expect(trip.duration_in_days).to be_nil
      end
    end

    describe '#can_be_edited_by?' do
      it 'returns true for the trip owner' do
        expect(trip.can_be_edited_by?(user)).to be true
      end

      it 'returns false for other users' do
        other_user = create(:user)
        expect(trip.can_be_edited_by?(other_user)).to be false
      end

      it 'returns false for nil user' do
        expect(trip.can_be_edited_by?(nil)).to be false
      end
    end

    describe '#status_badge_class' do
      it 'returns correct CSS class for each status' do
        trip.status = 'planning'
        expect(trip.status_badge_class).to eq('bg-primary')

        trip.status = 'active'
        expect(trip.status_badge_class).to eq('bg-success')

        trip.status = 'completed'
        expect(trip.status_badge_class).to eq('bg-secondary')
      end
    end

    describe '#current?' do
      it 'returns true for active trips' do
        trip.status = 'active'
        expect(trip.current?).to be true
      end

      it 'returns false for non-active trips' do
        trip.status = 'planning'
        expect(trip.current?).to be false

        trip.status = 'completed'
        expect(trip.current?).to be false
      end
    end

    describe '#add_trip_data' do
      it 'merges new data with existing trip_data' do
        trip.trip_data = { 'existing' => 'value' }
        trip.add_trip_data('new_key', 'new_value')

        expect(trip.trip_data).to eq({
          'existing' => 'value',
          'new_key' => 'new_value'
        })
      end

      it 'initializes trip_data if nil' do
        trip.trip_data = nil
        trip.add_trip_data('key', 'value')

        expect(trip.trip_data).to eq({ 'key' => 'value' })
      end

      it 'overwrites existing keys' do
        trip.trip_data = { 'key' => 'old_value' }
        trip.add_trip_data('key', 'new_value')

        expect(trip.trip_data['key']).to eq('new_value')
      end
    end

    describe '#active_chat_session' do
      it 'returns the first active chat session' do
        active_session = create(:chat_session, trip: trip, status: 'active')
        create(:chat_session, trip: trip, status: 'completed')
        
        expect(trip.active_chat_session).to eq(active_session)
      end

      it 'returns nil when no active chat sessions' do
        create(:chat_session, trip: trip, status: 'completed')
        
        expect(trip.active_chat_session).to be_nil
      end
    end

    describe '#has_active_chat_session?' do
      it 'returns true when trip has active chat session' do
        create(:chat_session, trip: trip, status: 'active')
        
        expect(trip.has_active_chat_session?).to be true
      end

      it 'returns false when trip has no active chat session' do
        create(:chat_session, trip: trip, status: 'completed')
        
        expect(trip.has_active_chat_session?).to be false
      end
    end
  end

  describe 'default values' do
    it 'sets default status to planning' do
      user = create(:user)
      trip = Trip.new(user: user, title: 'Test Trip')
      trip.save
      expect(trip.status).to eq('planning')
    end

    it 'sets default public_trip? to false' do
      user = create(:user)
      trip = Trip.new(user: user, title: 'Test Trip')
      trip.save
      expect(trip.public_trip?).to be false
    end

    it 'initializes empty trip_data hash' do
      trip = create(:trip)
      expect(trip.trip_data).to eq({})
    end

    it 'initializes empty sharing_settings hash' do
      trip = create(:trip)
      expect(trip.sharing_settings).to eq({})
    end
  end
end
