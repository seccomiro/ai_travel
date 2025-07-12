# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AITools::CalculateRouteTool do
  let(:trip) { create(:trip) }
  let(:tool) { described_class.new(trip) }

  describe '#execute' do
    let(:args) do
      {
        'segments' => [
          {
            'origin' => 'New York, NY',
            'destination' => 'Boston, MA'
          }
        ],
        'user_preferences' => {
          'max_daily_drive_h' => 8,
          'max_daily_distance_km' => 800
        }
      }
    end

    it 'calculates routes and validates them' do
      # Mock the Google Directions service
      mock_route_result = {
        legs: [{
          origin: 'New York, NY, USA',
          destination: 'Boston, MA, USA',
          distance_km: 350.0,
          duration_hours: 3.5,
          distance_text: '350 km',
          duration_text: '3 hours 30 mins'
        }],
        total_distance_km: 350.0,
        total_duration_hours: 3.5,
        route_id: 'test-route-123'
      }

      allow_any_instance_of(GoogleDirectionsService).to receive(:calculate_route).and_return(mock_route_result)
      allow_any_instance_of(GoogleDirectionsService).to receive(:validate_segment).and_return({ valid: true })

      result = tool.execute(args)

      expect(result[:success]).to be true
      expect(result[:segments]).to be_present
      expect(result[:summary]).to be_present
      expect(result[:recommendations]).to be_present
    end

    it 'handles invalid segments gracefully' do
      args['segments'] = [
        {
          'origin' => 'Invalid Location',
          'destination' => 'Another Invalid'
        }
      ]

      allow_any_instance_of(GoogleDirectionsService).to receive(:calculate_route).and_return({ error: 'Location not found' })

      result = tool.execute(args)

      expect(result[:success]).to be true
      expect(result[:segments].first[:error]).to be_present
    end

    it 'validates segments against user preferences' do
      # Mock a long route that exceeds preferences
      mock_route_result = {
        legs: [{
          origin: 'New York, NY, USA',
          destination: 'Los Angeles, CA, USA',
          distance_km: 4000,
          duration_hours: 40,
          distance_text: '4,000 km',
          duration_text: '40 hours'
        }],
        total_distance_km: 4000,
        total_duration_hours: 40,
        route_id: 'test-route'
      }

      allow_any_instance_of(GoogleDirectionsService).to receive(:calculate_route).and_return(mock_route_result)
      allow_any_instance_of(GoogleDirectionsService).to receive(:validate_segment).and_return({
        valid: false,
        issues: ['Drive time (40h) exceeds maximum daily drive time (8h)', 'Distance (4000km) exceeds maximum daily distance (800km)']
      })

      result = tool.execute(args)

      expect(result[:success]).to be true
      expect(result[:segments].first[:valid]).to be false
      expect(result[:segments].first[:issues]).to be_present
    end
  end

    describe '#definition' do
    it 'returns the correct tool definition' do
      definition = tool.definition

      expect(definition[:function][:name]).to eq('calculate_route')
      expect(definition[:function][:description]).to include('Google Directions API')
      expect(definition[:function][:parameters][:properties]).to include('segments')
      expect(definition[:function][:parameters][:properties]).to include('user_preferences')
    end
  end
end