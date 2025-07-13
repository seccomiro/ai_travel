# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GoogleGeocodingService do
  let(:service) { described_class.new }

  describe '#geocode_location' do
    it 'geocodes a valid location' do
      # Mock successful Google Geocoding API response
      mock_response = double(
        success?: true,
        parsed_response: {
          'status' => 'OK',
          'results' => [{
            'formatted_address' => 'El Chaltén, Santa Cruz Province, Argentina',
            'geometry' => {
              'location' => { 'lat' => -49.3299, 'lng' => -72.8861 }
            },
            'types' => ['locality', 'political'],
            'place_id' => 'mock_place_id'
          }]
        }
      )

      allow(HTTParty).to receive(:get).and_return(mock_response)

      result = service.geocode_location('Mount Fitz Roy')

      expect(result[:error]).to be_nil
      expect(result[:coordinates]).to eq([-49.3299, -72.8861])
      expect(result[:formatted_address]).to eq('El Chaltén, Santa Cruz Province, Argentina')
    end

    it 'handles API errors gracefully' do
      # Mock a failed API response
      allow(HTTParty).to receive(:get).and_return(
        double(success?: false, code: 400, body: 'Bad Request')
      )

      result = service.geocode_location('Invalid Location')

      expect(result[:error]).to be_present
    end

    it 'handles ZERO_RESULTS status' do
      # Mock ZERO_RESULTS response
      mock_response = double(
        success?: true,
        parsed_response: {
          'status' => 'ZERO_RESULTS',
          'results' => []
        }
      )

      allow(HTTParty).to receive(:get).and_return(mock_response)

      result = service.geocode_location('Mount Fitz Roy')

      expect(result[:error]).to include('No results found for location')
    end
  end

  describe '#find_nearest_town' do
    it 'finds the nearest town for a geographic feature' do
      # Mock geocoding response
      geocode_response = double(
        success?: true,
        parsed_response: {
          'status' => 'OK',
          'results' => [{
            'formatted_address' => 'Mount Fitz Roy, Santa Cruz Province, Argentina',
            'geometry' => {
              'location' => { 'lat' => -49.3299, 'lng' => -72.8861 }
            },
            'types' => ['natural_feature'],
            'place_id' => 'mock_place_id'
          }]
        }
      )

      # Mock reverse geocoding response
      reverse_geocode_response = double(
        success?: true,
        parsed_response: {
          'status' => 'OK',
          'results' => [{
            'formatted_address' => 'El Chaltén, Santa Cruz Province, Argentina',
            'geometry' => {
              'location' => { 'lat' => -49.3299, 'lng' => -72.8861 }
            },
            'types' => ['locality', 'political']
          }]
        }
      )

      allow(HTTParty).to receive(:get).and_return(geocode_response, reverse_geocode_response)

      result = service.find_nearest_town('Mount Fitz Roy')

      expect(result[:error]).to be_nil
      expect(result[:nearest_town]).to eq('El Chaltén, Santa Cruz Province, Argentina')
      expect(result[:original_location]).to eq('Mount Fitz Roy')
      expect(result[:coordinates]).to eq([-49.3299, -72.8861])
      expect(result[:distance_km]).to be > 0
      expect(result[:confidence]).to eq('high')
    end

    it 'handles geocoding failures' do
      # Mock failed geocoding response
      allow(HTTParty).to receive(:get).and_return(
        double(success?: false, code: 400, body: 'Bad Request')
      )

      result = service.find_nearest_town('Invalid Location')

      expect(result[:error]).to be_present
    end
  end

  describe '#find_nearest_town_from_coordinates' do
    it 'finds the nearest town from coordinates' do
      # Mock reverse geocoding response
      mock_response = double(
        success?: true,
        parsed_response: {
          'status' => 'OK',
          'results' => [{
            'formatted_address' => 'El Chaltén, Santa Cruz Province, Argentina',
            'geometry' => {
              'location' => { 'lat' => -49.3299, 'lng' => -72.8861 }
            },
            'types' => ['locality', 'political']
          }]
        }
      )

      allow(HTTParty).to receive(:get).and_return(mock_response)

      result = service.find_nearest_town_from_coordinates([-49.3299, -72.8861])

      expect(result[:error]).to be_nil
      expect(result[:town_name]).to eq('El Chaltén, Santa Cruz Province, Argentina')
      expect(result[:confidence]).to eq('high')
      expect(result[:distance_km]).to be >= 0
    end

    it 'prefers locality over administrative areas' do
      # Mock response with both locality and administrative areas
      mock_response = double(
        success?: true,
        parsed_response: {
          'status' => 'OK',
          'results' => [
            {
              'formatted_address' => 'El Chaltén, Santa Cruz Province, Argentina',
              'geometry' => {
                'location' => { 'lat' => -49.3299, 'lng' => -72.8861 }
              },
              'types' => ['locality', 'political']
            },
            {
              'formatted_address' => 'Santa Cruz Province, Argentina',
              'geometry' => {
                'location' => { 'lat' => -49.3299, 'lng' => -72.8861 }
              },
              'types' => ['administrative_area_level_1', 'political']
            }
          ]
        }
      )

      allow(HTTParty).to receive(:get).and_return(mock_response)

      result = service.find_nearest_town_from_coordinates([-49.3299, -72.8861])

      expect(result[:town_name]).to eq('El Chaltén, Santa Cruz Province, Argentina')
      expect(result[:confidence]).to eq('high')
    end
  end
end