require 'rails_helper'

RSpec.describe TravelToolsService, type: :service do
  let(:service) { described_class }

  describe '.call_tool' do
    it 'calls get_weather when tool name is get_weather' do
      args = { 'location' => 'Paris' }
      result = service.call_tool('get_weather', args)
      
      expect(result).to include(:location)
      expect(result[:location]).to eq('Paris')
      expect(result).to include(:temperature)
      expect(result).to include(:condition)
    end

    it 'calls search_accommodation when tool name is search_accommodation' do
      args = { 'location' => 'Paris', 'check_in' => '2025-08-01', 'check_out' => '2025-08-05' }
      result = service.call_tool('search_accommodation', args)
      
      expect(result).to include(:location)
      expect(result[:location]).to eq('Paris')
      expect(result).to include(:options)
      expect(result[:options]).to be_an(Array)
    end

    it 'calls plan_route when tool name is plan_route' do
      args = { 'destinations' => ['Paris', 'London'] }
      result = service.call_tool('plan_route', args)
      
      expect(result).to include(:destinations)
      expect(result[:destinations]).to eq(['Paris', 'London'])
      expect(result).to include(:route)
      expect(result[:route]).to be_an(Array)
    end

    it 'returns error for unknown tool' do
      result = service.call_tool('unknown_tool', {})
      expect(result).to eq({ error: 'Unknown tool: unknown_tool' })
    end
  end

  describe '.get_weather' do
    let(:args) { { 'location' => 'Paris' } }

    it 'returns weather information for the location' do
      result = service.send(:get_weather, 'Paris')
      
      expect(result).to include(:location)
      expect(result[:location]).to eq('Paris')
      expect(result).to include(:temperature)
      expect(result).to include(:condition)
      expect(result).to include(:humidity)
      expect(result).to include(:wind_speed)
    end

    it 'handles different locations' do
      result = service.send(:get_weather, 'Tokyo')
      expect(result[:location]).to eq('Tokyo')
    end

    it 'returns temperature in reasonable range' do
      result = service.send(:get_weather, 'Paris')
      expect(result[:temperature]).to be_between(15, 30)
    end

    it 'returns valid weather conditions' do
      result = service.send(:get_weather, 'Paris')
      valid_conditions = ['Sunny', 'Cloudy', 'Rainy', 'Partly Cloudy']
      expect(valid_conditions).to include(result[:condition])
    end
  end

  describe '.search_accommodation' do
    let(:args) do
      {
        'location' => 'Paris',
        'check_in' => '2025-08-01',
        'check_out' => '2025-08-05',
        'guests' => 2
      }
    end

    it 'returns accommodation options for the location' do
      result = service.send(:search_accommodation, args)
      
      expect(result).to include(:location)
      expect(result[:location]).to eq('Paris')
      expect(result).to include(:check_in)
      expect(result).to include(:check_out)
      expect(result).to include(:guests)
      expect(result).to include(:options)
    end

    it 'returns multiple accommodation options' do
      result = service.send(:search_accommodation, args)
      expect(result[:options]).to be_an(Array)
      expect(result[:options].length).to eq(3)
    end

    it 'includes different types of accommodation' do
      result = service.send(:search_accommodation, args)
      types = result[:options].map { |option| option[:type] }
      expect(types).to include('Hotel')
      expect(types).to include('Apartment')
    end

    it 'includes amenities in accommodation options' do
      result = service.send(:search_accommodation, args)
      first_option = result[:options].first
      expect(first_option).to include(:amenities)
      expect(first_option[:amenities]).to be_an(Array)
    end

    it 'handles missing guests parameter' do
      args_without_guests = args.except('guests')
      result = service.send(:search_accommodation, args_without_guests)
      expect(result[:guests]).to eq(2) # Default value
    end

    it 'handles different locations' do
      result = service.send(:search_accommodation, { 'location' => 'Tokyo', 'check_in' => '2025-08-01', 'check_out' => '2025-08-05' })
      expect(result[:location]).to eq('Tokyo')
    end
  end

  describe '.plan_route' do
    let(:args) do
      {
        'destinations' => ['Paris', 'London'],
        'transport_mode' => 'train'
      }
    end

    it 'returns route planning information' do
      result = service.send(:plan_route, args)
      
      expect(result).to include(:destinations)
      expect(result).to include(:transport_mode)
      expect(result).to include(:route)
      expect(result).to include(:total_distance)
      expect(result).to include(:total_duration)
      expect(result).to include(:total_cost)
    end

    it 'returns route segments for multiple destinations' do
      result = service.send(:plan_route, args)
      expect(result[:route]).to be_an(Array)
      expect(result[:route].length).to eq(1) # Paris to London = 1 segment
    end

    it 'includes segment details' do
      result = service.send(:plan_route, args)
      segment = result[:route].first
      
      expect(segment).to include(:segment)
      expect(segment).to include(:from)
      expect(segment).to include(:to)
      expect(segment).to include(:distance)
      expect(segment).to include(:duration)
      expect(segment).to include(:transport)
      expect(segment).to include(:estimated_cost)
    end

    it 'handles different transport modes' do
      ['car', 'train', 'plane', 'bus'].each do |mode|
        result = service.send(:plan_route, { 'destinations' => ['Paris', 'London'], 'transport_mode' => mode })
        expect(result[:transport_mode]).to eq(mode)
      end
    end

    it 'uses default transport mode when not specified' do
      result = service.send(:plan_route, { 'destinations' => ['Paris', 'London'] })
      expect(result[:transport_mode]).to eq('car')
    end

    it 'handles single destination' do
      result = service.send(:plan_route, { 'destinations' => ['Paris'] })
      expect(result[:route]).to be_empty
    end

    it 'handles empty destinations' do
      result = service.send(:plan_route, { 'destinations' => [] })
      expect(result[:route]).to be_empty
    end

    it 'handles different destination combinations' do
      result = service.send(:plan_route, { 'destinations' => ['Tokyo', 'Kyoto', 'Osaka'], 'transport_mode' => 'train' })
      expect(result[:route].length).to eq(2) # 3 destinations = 2 segments
    end
  end

  describe 'error handling' do
    it 'handles missing required parameters gracefully' do
      expect { service.send(:get_weather, nil) }.to_not raise_error
    end

    it 'handles nil parameters gracefully' do
      expect { service.send(:get_weather, nil) }.to_not raise_error
    end

    it 'handles invalid transport modes' do
      result = service.send(:plan_route, { 'destinations' => ['Paris', 'London'], 'transport_mode' => 'invalid_mode' })
      expect(result[:transport_mode]).to eq('invalid_mode')
      expect(result[:route]).to be_an(Array)
    end
  end

  describe 'data consistency' do
    it 'returns consistent data structures' do
      weather_result = service.send(:get_weather, 'Paris')
      accommodation_result = service.send(:search_accommodation, { 'location' => 'Paris', 'check_in' => '2025-08-01', 'check_out' => '2025-08-05' })
      route_result = service.send(:plan_route, { 'destinations' => ['Paris', 'London'] })

      expect(weather_result).to be_a(Hash)
      expect(accommodation_result).to be_a(Hash)
      expect(route_result).to be_a(Hash)
    end
  end
end 