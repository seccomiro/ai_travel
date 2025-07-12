# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RouteOptimizationService do
  let(:trip) { create(:trip) }
  let(:service) { described_class.new(trip) }

  describe '#calculate_optimized_route' do
    let(:segments) do
      [
        { origin: 'New York, NY', destination: 'Boston, MA' },
        { origin: 'Boston, MA', destination: 'Portland, ME' }
      ]
    end

    it 'calculates and optimizes a complete route' do
      # Mock the Google Directions service responses
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
        route_id: 'test-route-123',
        polyline: 'mock_polyline',
        bounds: { 'northeast' => {}, 'southwest' => {} }
      }

      allow_any_instance_of(GoogleDirectionsService).to receive(:calculate_trip_segments).and_return([
        { segment: segments[0], route: mock_route_result, error: nil },
        { segment: segments[1], route: mock_route_result, error: nil }
      ])

      allow_any_instance_of(GoogleDirectionsService).to receive(:validate_segment).and_return({ valid: true })

      result = service.calculate_optimized_route(segments)

      expect(result[:segments]).to be_present
      expect(result[:summary]).to be_present
      expect(result[:segments].length).to eq(2)
      expect(result[:summary][:total_segments]).to eq(2)
    end

        it 'splits long segments that exceed user preferences' do
      # Mock a long route that exceeds preferences
      long_route_result = {
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
        route_id: 'test-route-long',
        polyline: 'mock_polyline',
        bounds: { 'northeast' => {}, 'southwest' => {} }
      }

      # Mock validation that says the segment is too long
      allow_any_instance_of(GoogleDirectionsService).to receive(:validate_segment).and_return({
        valid: false,
        issues: ['Drive time (40h) exceeds maximum daily drive time (8h)'],
        suggested_splits: [
          { stop_location: 'Chicago, IL', distance_from_origin: 1200, hours_from_origin: 12 },
          { stop_location: 'Denver, CO', distance_from_origin: 2400, hours_from_origin: 24 }
        ]
      })

      # Mock the split segments
      split_route_result = {
        legs: [{
          origin: 'New York, NY, USA',
          destination: 'Chicago, IL, USA',
          distance_km: 1200,
          duration_hours: 12,
          distance_text: '1,200 km',
          duration_text: '12 hours'
        }],
        total_distance_km: 1200,
        total_duration_hours: 12,
        route_id: 'test-route-split',
        polyline: 'mock_polyline',
        bounds: { 'northeast' => {}, 'southwest' => {} }
      }

      # Mock the initial calculation
      allow_any_instance_of(GoogleDirectionsService).to receive(:calculate_trip_segments).and_return([
        { segment: { origin: 'New York, NY', destination: 'Los Angeles, CA' }, route: long_route_result, error: nil }
      ])

      # Mock the recalculated split segments - this will be called for the split segments
      allow_any_instance_of(GoogleDirectionsService).to receive(:calculate_trip_segments).with(
        array_including(
          { origin: 'New York, NY', destination: 'Chicago, IL', waypoints: [] }
        ),
        anything
      ).and_return([
        { segment: { origin: 'New York, NY', destination: 'Chicago, IL' }, route: split_route_result, error: nil },
        { segment: { origin: 'Chicago, IL', destination: 'Denver, CO' }, route: split_route_result, error: nil },
        { segment: { origin: 'Denver, CO', destination: 'Los Angeles, CA' }, route: split_route_result, error: nil }
      ])

      # Mock validation for the split segments to be valid
      allow_any_instance_of(GoogleDirectionsService).to receive(:validate_segment).with(split_route_result, anything).and_return({ valid: true })

      result = service.calculate_optimized_route([{ origin: 'New York, NY', destination: 'Los Angeles, CA' }])

      expect(result[:segments].length).to be > 1
      expect(result[:segments].all? { |seg| seg[:valid] }).to be true
    end

    it 'handles API errors gracefully' do
      allow_any_instance_of(GoogleDirectionsService).to receive(:calculate_trip_segments).and_return([
        { segment: segments[0], error: 'Location not found' }
      ])

      result = service.calculate_optimized_route(segments)

      expect(result[:warnings]).to include('Location not found')
      expect(result[:segments]).to be_empty
    end
  end

  describe '#extract_user_preferences' do
    it 'uses trip data preferences when available' do
      trip.trip_data = {
        'route_preferences' => {
          'max_daily_drive_h' => 6,
          'avoid' => ['tolls']
        }
      }

      preferences = service.send(:extract_user_preferences, {})

      expect(preferences[:max_daily_drive_h]).to eq(6)
      expect(preferences[:avoid]).to include('tolls')
    end

    it 'uses provided preferences over trip data' do
      trip.trip_data = {
        'route_preferences' => {
          'max_daily_drive_h' => 6
        }
      }

      preferences = service.send(:extract_user_preferences, { max_daily_drive_h: 8 })

      expect(preferences[:max_daily_drive_h]).to eq(8)
    end
  end
end