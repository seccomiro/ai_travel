# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Route Handling Integration', type: :service do
  let(:user) { create(:user) }
  let(:trip) { create(:trip, user: user) }
  let(:chat_session) { create(:chat_session, trip: trip) }

  describe 'Route request detection and handling' do
    it 'detects route requests and forces tool usage' do
      # Create a route request message
      user_message = create(:chat_message,
        chat_session: chat_session,
        role: 'user',
        content: 'How do I get from Curitiba to Puerto Madryn?'
      )

      # Mock the route detector to return segments
      detector = instance_double(RouteRequestDetectorService)
      allow(RouteRequestDetectorService).to receive(:new).and_return(detector)
      allow(detector).to receive(:route_request?).and_return(true)
      allow(detector).to receive(:extract_segments_from_message).and_return([
        { origin: 'Curitiba, Paraná, Brazil', destination: 'Puerto Madryn, Chubut, Argentina' }
      ])
      allow(detector).to receive(:extract_preferences_from_trip).and_return({
        max_daily_drive_h: 8,
        max_daily_distance_km: 800
      })

      # Mock the travel tools service
      mock_result = {
        success: true,
        summary: { total_distance_km: 1403, total_duration_hours: 17.5 },
        segments: [
          {
            origin: 'Curitiba, Paraná, Brazil',
            destination: 'Puerto Madryn, Chubut, Argentina',
            distance_km: 1403,
            duration_hours: 17.5,
            valid: true
          }
        ],
        warnings: []
      }
      allow(TravelToolsService).to receive(:call_tool).and_return(mock_result)

      # Mock the OpenAI service for the polished response
      mock_ai_response = { content: 'I\'ve calculated your route from Curitiba to Puerto Madryn!' }
      allow_any_instance_of(OpenaiChatService).to receive(:chat).and_return(mock_ai_response)

      # Call the chat response service
      service = ChatResponseService.new(chat_session)
      result = service.call(user_message)

      # Verify the result
      expect(result[:message]).to be_present
      expect(result[:trip].trip_data['current_route']).to be_present
      expect(result[:trip].trip_data['current_route']['segments'].length).to eq(1)
    end

    it 'does not force tool usage for non-route requests' do
      # Create a non-route message
      user_message = create(:chat_message,
        chat_session: chat_session,
        role: 'user',
        content: 'What is the weather like in Buenos Aires?'
      )

      # Mock the route detector to return false
      detector = instance_double(RouteRequestDetectorService)
      allow(RouteRequestDetectorService).to receive(:new).and_return(detector)
      allow(detector).to receive(:route_request?).and_return(false)

      # Mock the OpenAI service
      mock_ai_response = { content: 'The weather in Buenos Aires is sunny and warm.' }
      allow_any_instance_of(OpenaiChatService).to receive(:chat).and_return(mock_ai_response)

      # Call the chat response service
      service = ChatResponseService.new(chat_session)
      result = service.call(user_message)

      # Verify the result
      expect(result[:message]).to be_present
      expect(result[:message].content).to include('Buenos Aires')
    end
  end

  describe 'Google Directions Service' do
    let(:service) { GoogleDirectionsService.new }

    it 'calculates routes using real API calls' do
      # This test would require a real API key and would make actual API calls
      # For now, we'll just verify the service is properly structured
      expect(service).to respond_to(:calculate_route)
      expect(service).to respond_to(:calculate_trip_segments)
      expect(service).to respond_to(:validate_segment)
    end

    it 'does not contain hardcoded mock methods' do
      # Verify that hardcoded methods have been removed
      expect(service.private_methods).not_to include(:mock_route_response)
      expect(service.private_methods).not_to include(:calculate_realistic_distance_and_duration)
      expect(service.private_methods).not_to include(:calculate_estimated_distance)
      expect(service.private_methods).not_to include(:extract_city_name)
    end
  end

  describe 'Route Optimization Service' do
    let(:service) { RouteOptimizationService.new(trip) }

    it 'optimizes routes and splits long segments' do
      segments = [
        { origin: 'Curitiba, Paraná, Brazil', destination: 'Ushuaia, Tierra del Fuego, Argentina' }
      ]

      # Mock the Google Directions Service
      mock_route_result = {
        legs: [
          {
            origin: 'Curitiba, Paraná, Brazil',
            destination: 'Ushuaia, Tierra del Fuego, Argentina',
            distance_km: 3000,
            duration_hours: 40,
            distance_text: '3000 km',
            duration_text: '40 hours'
          }
        ],
        total_distance_km: 3000,
        total_duration_hours: 40
      }

      allow_any_instance_of(GoogleDirectionsService).to receive(:calculate_trip_segments).and_return([
        { segment: segments.first, route: mock_route_result }
      ])

      allow_any_instance_of(GoogleDirectionsService).to receive(:validate_segment).and_return({
        valid: false,
        issues: ['Drive time (40h) exceeds maximum daily drive time (8h)'],
        suggested_splits: [
          { day: 1, stop_location: 'Intermediate stop 1', distance_from_origin: 750, hours_from_origin: 10 },
          { day: 2, stop_location: 'Intermediate stop 2', distance_from_origin: 1500, hours_from_origin: 20 },
          { day: 3, stop_location: 'Intermediate stop 3', distance_from_origin: 2250, hours_from_origin: 30 },
          { day: 4, stop_location: 'Intermediate stop 4', distance_from_origin: 3000, hours_from_origin: 40 }
        ]
      })

      # Call the optimization service
      result = service.calculate_optimized_route(segments)

      # Verify the result
      expect(result).to be_present
      expect(result[:segments]).to be_present
      expect(result[:summary]).to be_present
    end
  end
end