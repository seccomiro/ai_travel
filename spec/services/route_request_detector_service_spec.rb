# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RouteRequestDetectorService do
  let(:trip) { create(:trip) }
  let(:service) { described_class.new(trip) }

  describe '#route_request?' do
    it 'detects route requests correctly' do
      route_requests = [
        'Plan a route from New York to Boston',
        'Calculate the driving route',
        'I want to plan a road trip',
        'Show me the itinerary',
        'What is the driving route?',
        'Plan my road trip itinerary'
      ]

      route_requests.each do |message|
        expect(service.route_request?(message)).to be true
      end
    end

    it 'does not detect non-route requests' do
      non_route_requests = [
        'What is the weather like?',
        'Find me a hotel',
        'What activities are available?',
        'Tell me about the destination'
      ]

      non_route_requests.each do |message|
        expect(service.route_request?(message)).to be false
      end
    end
  end

  describe '#extract_segments_from_message' do
    it 'extracts segments from "from X to Y" pattern' do
      message = 'Plan a route from Curitiba to Puerto Madryn'
      segments = service.extract_segments_from_message(message)

      expect(segments).to be_present
      expect(segments.first[:origin]).to eq('Curitiba')
      expect(segments.first[:destination]).to eq('Puerto Madryn')
    end

    it 'extracts segments from "driving from X to Y" pattern' do
      message = 'I want to drive from New York to Boston'
      segments = service.extract_segments_from_message(message)

      expect(segments).to be_present
      expect(segments.first[:origin]).to eq('New York')
      expect(segments.first[:destination]).to eq('Boston')
    end

    it 'extracts multiple destinations from text' do
      message = 'I want to visit Curitiba, Puerto Madryn, and Ushuaia'
      segments = service.extract_segments_from_message(message)

      expect(segments).to be_present
      expect(segments.length).to be >= 2
    end
  end

  describe '#build_segments_from_trip' do
    it 'builds segments from trip data with destinations' do
      trip.trip_data = {
        'must_do' => ['Curitiba', 'Puerto Madryn', 'Ushuaia']
      }

      segments = service.build_segments_from_trip

      expect(segments).to be_present
      expect(segments.length).to eq(2)
      expect(segments.first[:origin]).to eq('Curitiba')
      expect(segments.first[:destination]).to eq('Puerto Madryn')
    end

    it 'returns nil when no destinations in trip data' do
      trip.trip_data = {}

      segments = service.build_segments_from_trip

      expect(segments).to be_nil
    end
  end

  describe '#extract_preferences_from_trip' do
    it 'extracts preferences from trip data' do
      trip.trip_data = {
        'route_preferences' => {
          'max_daily_drive_h' => 6,
          'max_daily_distance_km' => 600,
          'avoid' => ['tolls']
        }
      }

      preferences = service.extract_preferences_from_trip

      expect(preferences[:max_daily_drive_h]).to eq(6)
      expect(preferences[:max_daily_distance_km]).to eq(600)
      expect(preferences[:avoid]).to include('tolls')
    end

    it 'uses defaults when preferences not set' do
      trip.trip_data = {}

      preferences = service.extract_preferences_from_trip

      expect(preferences[:max_daily_drive_h]).to eq(8)
      expect(preferences[:max_daily_distance_km]).to eq(800)
    end
  end
end