# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutoRouteCalculationService do
  let(:trip) { create(:trip) }
  let(:chat_session) { create(:chat_session, trip: trip) }
  let(:service) { described_class.new(chat_session) }

  describe '#should_auto_calculate?' do
    it 'returns true for route request without tool call' do
      user_message = 'Plan a route from New York to Boston'
      ai_response = { tool_calls: [] }

      expect(service.should_auto_calculate?(user_message, ai_response)).to be true
    end

    it 'returns false for route request with tool call' do
      user_message = 'Plan a route from New York to Boston'
      ai_response = {
        tool_calls: [{ name: 'optimize_route' }]
      }

      expect(service.should_auto_calculate?(user_message, ai_response)).to be false
    end

    it 'returns false for non-route request' do
      user_message = 'What is the weather like?'
      ai_response = { tool_calls: [] }

      expect(service.should_auto_calculate?(user_message, ai_response)).to be false
    end
  end

  describe '#auto_calculate_route' do
    it 'calculates route when segments can be extracted' do
      user_message = 'Plan a route from New York to Boston'

      # Mock the route optimization service
      mock_route = {
        segments: [{
          origin: 'New York, NY, USA',
          destination: 'Boston, MA, USA',
          distance_km: 350.0,
          duration_hours: 3.5,
          distance_text: '350 km',
          duration_text: '3 hours 30 mins'
        }],
        summary: {
          total_segments: 1,
          total_distance_km: 350.0,
          total_duration_hours: 3.5
        }
      }

      allow_any_instance_of(RouteOptimizationService).to receive(:calculate_optimized_route).and_return(mock_route)

      result = service.auto_calculate_route(user_message)

      expect(result[:success]).to be true
      expect(result[:message]).to include('Route Calculated Successfully')
      expect(result[:route]).to eq(mock_route)
    end

    it 'returns error when segments cannot be extracted' do
      user_message = 'Plan a route' # No specific destinations

      result = service.auto_calculate_route(user_message)

      expect(result[:success]).to be false
      expect(result[:error]).to include('Could not determine route segments')
    end

    it 'handles calculation errors gracefully' do
      user_message = 'Plan a route from New York to Boston'

      allow_any_instance_of(RouteOptimizationService).to receive(:calculate_optimized_route).and_raise('API Error')

      result = service.auto_calculate_route(user_message)

      expect(result[:success]).to be false
      expect(result[:error]).to include('Failed to calculate route')
    end
  end
end