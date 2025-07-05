require 'rails_helper'

# Specs in this file have access to a helper object that includes
# the TripsHelper. For example:
#
# describe TripsHelper do
#   describe "string concat" do
#     it "concats two strings with spaces" do
#       expect(helper.concat_strings("this","that")).to eq("this that")
#     end
#   end
# end

RSpec.describe TripsHelper, type: :helper do
  describe '#trip_status_badge_class' do
    it 'returns success for active status' do
      expect(helper.trip_status_badge_class('active')).to eq('success')
    end

    it 'returns primary for planning status' do
      expect(helper.trip_status_badge_class('planning')).to eq('primary')
    end

    it 'returns secondary for completed status' do
      expect(helper.trip_status_badge_class('completed')).to eq('secondary')
    end

    it 'returns secondary for unknown status' do
      expect(helper.trip_status_badge_class('unknown')).to eq('secondary')
    end

    it 'handles symbol input' do
      expect(helper.trip_status_badge_class(:active)).to eq('success')
    end
  end

  describe '#trip_visibility_badge_class' do
    it 'returns info for public trips' do
      expect(helper.trip_visibility_badge_class(true)).to eq('info')
    end

    it 'returns secondary for private trips' do
      expect(helper.trip_visibility_badge_class(false)).to eq('secondary')
    end
  end

  describe '#trip_duration_in_days' do
    let(:start_date) { Date.new(2024, 1, 1) }
    let(:end_date) { Date.new(2024, 1, 5) }

    it 'calculates duration correctly' do
      expect(helper.trip_duration_in_days(start_date, end_date)).to eq(5)
    end

    it 'returns 1 for same day trips' do
      expect(helper.trip_duration_in_days(start_date, start_date)).to eq(1)
    end

    it 'returns dash when start date is nil' do
      expect(helper.trip_duration_in_days(nil, end_date)).to eq('-')
    end

    it 'returns dash when end date is nil' do
      expect(helper.trip_duration_in_days(start_date, nil)).to eq('-')
    end

    it 'returns dash when both dates are nil' do
      expect(helper.trip_duration_in_days(nil, nil)).to eq('-')
    end
  end

  describe '#trip_date_range' do
    let(:start_date) { Date.new(2024, 1, 1) }
    let(:end_date) { Date.new(2024, 1, 5) }

    before do
      # Mock the I18n methods
      allow(helper).to receive(:t).with('trips.dates_not_set').and_return('Dates not set')
      allow(helper).to receive(:t).with('trips.from').and_return('From')
      allow(helper).to receive(:t).with('trips.until').and_return('Until')
      allow(helper).to receive(:l).with(start_date, format: :long).and_return('January 1, 2024')
      allow(helper).to receive(:l).with(start_date, format: :short).and_return('Jan 1')
      allow(helper).to receive(:l).with(end_date, format: :short).and_return('Jan 5')
    end

    it 'returns full date range for both dates' do
      expect(helper.trip_date_range(start_date, end_date)).to eq('Jan 1 - Jan 5')
    end

    it 'returns single date for same day' do
      expect(helper.trip_date_range(start_date, start_date)).to eq('January 1, 2024')
    end

    it 'returns from date when only start date is present' do
      expect(helper.trip_date_range(start_date, nil)).to eq('From Jan 1')
    end

    it 'returns until date when only end date is present' do
      expect(helper.trip_date_range(nil, end_date)).to eq('Until Jan 5')
    end

    it 'returns dates not set when both are nil' do
      expect(helper.trip_date_range(nil, nil)).to eq('Dates not set')
    end
  end

  describe '#trip_description_summary' do
    before do
      allow(helper).to receive(:t).with('trips.no_description').and_return('No description')
    end

    it 'returns no description for blank description' do
      expect(helper.trip_description_summary('')).to eq('No description')
      expect(helper.trip_description_summary(nil)).to eq('No description')
    end

    it 'returns full description when shorter than limit' do
      short_desc = 'Short description'
      expect(helper.trip_description_summary(short_desc)).to eq(short_desc)
    end

    it 'truncates long descriptions' do
      long_desc = 'a' * 150
      allow(helper).to receive(:truncate).with(long_desc, length: 100).and_return('a' * 97 + '...')
      expect(helper.trip_description_summary(long_desc)).to eq('a' * 97 + '...')
    end

    it 'accepts custom length parameter' do
      desc = 'This is a test description'
      allow(helper).to receive(:truncate).with(desc, length: 10).and_return('This is...')
      expect(helper.trip_description_summary(desc, length: 10)).to eq('This is...')
    end
  end

  describe '#trip_status_with_icon' do
    before do
      allow(helper).to receive(:t).with('trips.status.active').and_return('Active')
      allow(helper).to receive(:t).with('trips.status.planning').and_return('Planning')
      allow(helper).to receive(:t).with('trips.status.completed').and_return('Completed')
      allow(helper).to receive(:t).with('trips.status.unknown').and_return('Unknown')
    end

    it 'returns correct icon and text for active status' do
      result = helper.trip_status_with_icon('active')
      expect(result).to include('bi-play-circle')
      expect(result).to include('Active')
    end

    it 'returns correct icon and text for planning status' do
      result = helper.trip_status_with_icon('planning')
      expect(result).to include('bi-pencil-square')
      expect(result).to include('Planning')
    end

    it 'returns correct icon and text for completed status' do
      result = helper.trip_status_with_icon('completed')
      expect(result).to include('bi-check-circle')
      expect(result).to include('Completed')
    end

    it 'returns default icon for unknown status' do
      result = helper.trip_status_with_icon('unknown')
      expect(result).to include('bi-circle')
      expect(result).to include('Unknown')
    end

    it 'handles symbol input' do
      result = helper.trip_status_with_icon(:active)
      expect(result).to include('bi-play-circle')
      expect(result).to include('Active')
    end
  end
end
