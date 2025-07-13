# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GoogleDirectionsService do
  let(:service) { described_class.new }

  describe '#calculate_route' do
    it 'calculates a route between two points' do
      # Mock successful Google Directions API response
      mock_response = double(
        success?: true,
        parsed_response: {
          'status' => 'OK',
          'routes' => [{
            'legs' => [{
              'start_address' => 'New York, NY, USA',
              'end_address' => 'Boston, MA, USA',
              'distance' => { 'value' => 350000, 'text' => '350 km' },
              'duration' => { 'value' => 12600, 'text' => '3 hours 30 mins' },
              'steps' => []
            }],
            'overview_polyline' => { 'points' => 'mock_polyline' },
            'bounds' => { 'northeast' => {}, 'southwest' => {} }
          }],
          'geocoded_waypoints' => []
        }
      )

      allow(HTTParty).to receive(:get).and_return(mock_response)

      result = service.calculate_route('New York, NY', 'Boston, MA')

      expect(result[:error]).to be_nil
      expect(result[:legs]).to be_present
      expect(result[:total_distance_km]).to be > 0
      expect(result[:total_duration_hours]).to be > 0
    end

    it 'handles API errors gracefully' do
      # Mock a failed API response
      allow(HTTParty).to receive(:get).and_return(
        double(success?: false, code: 400, body: 'Bad Request')
      )

      result = service.calculate_route('Invalid', 'Location')

      expect(result[:error]).to be_present
    end
  end

  describe '#validate_segment' do
    let(:route_data) do
      {
        legs: [{
          distance_km: 1000,
          duration_hours: 12
        }]
      }
    end

    it 'validates segments against user preferences' do
      user_preferences = { max_daily_drive_h: 8, max_daily_distance_km: 800 }

      result = service.validate_segment(route_data, user_preferences)

      expect(result[:valid]).to be false
      expect(result[:issues]).to include(/Drive time.*exceeds maximum/)
      expect(result[:issues]).to include(/Distance.*exceeds maximum/)
    end

    it 'returns valid for reasonable segments' do
      route_data[:legs].first[:distance_km] = 400
      route_data[:legs].first[:duration_hours] = 6

      user_preferences = { max_daily_drive_h: 8, max_daily_distance_km: 800 }

      result = service.validate_segment(route_data, user_preferences)

      expect(result[:valid]).to be true
    end
  end

  describe '#calculate_trip_segments' do
    let(:segments) do
      [
        { origin: 'New York, NY', destination: 'Boston, MA' },
        { origin: 'Boston, MA', destination: 'Portland, ME' }
      ]
    end

    it 'calculates multiple route segments' do
      # Mock successful responses for both segments
      mock_response = double(
        success?: true,
        parsed_response: {
          'status' => 'OK',
          'routes' => [{
            'legs' => [{
              'start_address' => 'New York, NY, USA',
              'end_address' => 'Boston, MA, USA',
              'distance' => { 'value' => 350000, 'text' => '350 km' },
              'duration' => { 'value' => 12600, 'text' => '3 hours 30 mins' },
              'steps' => []
            }],
            'overview_polyline' => { 'points' => 'mock_polyline' },
            'bounds' => { 'northeast' => {}, 'southwest' => {} }
          }],
          'geocoded_waypoints' => []
        }
      )

      allow(HTTParty).to receive(:get).and_return(mock_response)

      results = service.calculate_trip_segments(segments)

      expect(results.length).to eq(2)
      expect(results.first[:segment]).to eq(segments.first)
      expect(results.first[:route]).to be_present
    end
  end
end