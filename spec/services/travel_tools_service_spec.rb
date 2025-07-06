require 'rails_helper'

RSpec.describe TravelToolsService do
  let(:service) { described_class.new }

  describe '#get_weather' do
    let(:args) { { 'location' => 'Paris' } }

    it 'returns weather information for the location' do
      result = service.get_weather(args)
      
      expect(result).to be_a(Hash)
      expect(result[:location]).to eq('Paris')
      expect(result[:temperature]).to be_a(Integer)
      expect(result[:condition]).to be_a(String)
      expect(result[:note]).to include('mock weather data')
    end

    it 'handles different locations' do
      result = service.get_weather({ 'location' => 'Tokyo' })
      expect(result[:location]).to eq('Tokyo')
    end

    it 'returns temperature in reasonable range' do
      result = service.get_weather(args)
      expect(result[:temperature]).to be_between(-50, 50)
    end

    it 'returns valid weather conditions' do
      valid_conditions = ['Sunny', 'Cloudy', 'Rainy', 'Partly Cloudy']
      result = service.get_weather(args)
      expect(valid_conditions).to include(result[:condition])
    end
  end

  describe '#get_accommodation' do
    let(:args) do
      {
        'location' => 'Paris',
        'check_in' => '2025-07-15',
        'check_out' => '2025-07-20',
        'guests' => 2
      }
    end

    it 'returns accommodation options for the location' do
      result = service.get_accommodation(args)
      
      expect(result).to be_a(Hash)
      expect(result[:location]).to eq('Paris')
      expect(result[:check_in]).to eq('2025-07-15')
      expect(result[:check_out]).to eq('2025-07-20')
      expect(result[:guests]).to eq(2)
      expect(result[:options]).to be_an(Array)
      expect(result[:note]).to include('mock accommodation data')
    end

    it 'returns multiple accommodation options' do
      result = service.get_accommodation(args)
      expect(result[:options].length).to be >= 3
    end

    it 'includes different types of accommodation' do
      result = service.get_accommodation(args)
      types = result[:options].map { |option| option[:type] }
      
      expect(types).to include('Hotel')
      expect(types).to include('Apartment')
    end

    it 'includes amenities in accommodation options' do
      result = service.get_accommodation(args)
      first_option = result[:options].first
      
      expect(first_option[:amenities]).to be_an(Array)
      expect(first_option[:amenities]).to_not be_empty
    end

    it 'handles missing guests parameter' do
      args_without_guests = args.except('guests')
      result = service.get_accommodation(args_without_guests)
      
      expect(result[:guests]).to eq(2) # Default value
    end

    it 'handles different locations' do
      result = service.get_accommodation({ 'location' => 'Tokyo', 'check_in' => '2025-08-01', 'check_out' => '2025-08-05' })
      expect(result[:location]).to eq('Tokyo')
    end
  end

  describe '#plan_route' do
    let(:args) do
      {
        'destinations' => ['Paris', 'London', 'Rome'],
        'transport_mode' => 'car'
      }
    end

    it 'returns route planning information' do
      result = service.plan_route(args)
      
      expect(result).to be_a(Hash)
      expect(result[:destinations]).to eq(['Paris', 'London', 'Rome'])
      expect(result[:transport_mode]).to eq('car')
      expect(result[:segments]).to be_an(Array)
      expect(result[:note]).to include('mock routing data')
    end

    it 'returns route segments for multiple destinations' do
      result = service.plan_route(args)
      expect(result[:segments].length).to eq(2) # Paris->London, London->Rome
    end

    it 'includes segment details' do
      result = service.plan_route(args)
      first_segment = result[:segments].first
      
      expect(first_segment[:from]).to eq('Paris')
      expect(first_segment[:to]).to eq('London')
      expect(first_segment[:duration]).to be_a(String)
      expect(first_segment[:distance]).to be_a(String)
    end

    it 'handles different transport modes' do
      transport_modes = ['car', 'train', 'plane', 'bus']
      
      transport_modes.each do |mode|
        result = service.plan_route({ 'destinations' => ['Paris', 'London'], 'transport_mode' => mode })
        expect(result[:transport_mode]).to eq(mode)
      end
    end

    it 'uses default transport mode when not specified' do
      result = service.plan_route({ 'destinations' => ['Paris', 'London'] })
      expect(result[:transport_mode]).to eq('car')
    end

    it 'handles single destination' do
      result = service.plan_route({ 'destinations' => ['Paris'] })
      expect(result[:segments]).to be_empty
    end

    it 'handles empty destinations' do
      result = service.plan_route({ 'destinations' => [] })
      expect(result[:segments]).to be_empty
    end

    it 'handles different destination combinations' do
      result = service.plan_route({ 'destinations' => ['Tokyo', 'Kyoto', 'Osaka'], 'transport_mode' => 'train' })
      expect(result[:destinations]).to eq(['Tokyo', 'Kyoto', 'Osaka'])
      expect(result[:transport_mode]).to eq('train')
    end
  end

  describe '#available_tools' do
    it 'returns all available travel tools' do
      tools = service.available_tools
      
      expect(tools).to be_an(Array)
      expect(tools.length).to eq(3)
      
      tool_names = tools.map { |tool| tool[:name] }
      expect(tool_names).to include('get_weather')
      expect(tool_names).to include('get_accommodation')
      expect(tool_names).to include('plan_route')
    end

    it 'includes tool descriptions' do
      tools = service.available_tools
      
      tools.each do |tool|
        expect(tool[:description]).to be_a(String)
        expect(tool[:description]).to_not be_empty
      end
    end

    it 'includes tool parameters' do
      tools = service.available_tools
      
      tools.each do |tool|
        expect(tool[:parameters]).to be_a(Hash)
        expect(tool[:parameters][:type]).to eq('object')
        expect(tool[:parameters][:properties]).to be_a(Hash)
      end
    end

    it 'has correct weather tool structure' do
      weather_tool = service.available_tools.find { |tool| tool[:name] == 'get_weather' }
      
      expect(weather_tool[:description]).to include('weather information')
      expect(weather_tool[:parameters][:properties]).to have_key('location')
      expect(weather_tool[:parameters][:required]).to include('location')
    end

    it 'has correct accommodation tool structure' do
      accommodation_tool = service.available_tools.find { |tool| tool[:name] == 'get_accommodation' }
      
      expect(accommodation_tool[:description]).to include('accommodation options')
      expect(accommodation_tool[:parameters][:properties]).to have_key('location')
      expect(accommodation_tool[:parameters][:properties]).to have_key('check_in')
      expect(accommodation_tool[:parameters][:properties]).to have_key('check_out')
      expect(accommodation_tool[:parameters][:required]).to include('location')
    end

    it 'has correct route planning tool structure' do
      route_tool = service.available_tools.find { |tool| tool[:name] == 'plan_route' }
      
      expect(route_tool[:description]).to include('route planning')
      expect(route_tool[:parameters][:properties]).to have_key('destinations')
      expect(route_tool[:parameters][:properties]).to have_key('transport_mode')
      expect(route_tool[:parameters][:required]).to include('destinations')
    end
  end

  describe 'error handling' do
    it 'handles missing required parameters gracefully' do
      expect { service.get_weather({}) }.to_not raise_error
      expect { service.get_accommodation({}) }.to_not raise_error
      expect { service.plan_route({}) }.to_not raise_error
    end

    it 'handles nil parameters gracefully' do
      expect { service.get_weather(nil) }.to_not raise_error
      expect { service.get_accommodation(nil) }.to_not raise_error
      expect { service.plan_route(nil) }.to_not raise_error
    end

    it 'handles invalid transport modes' do
      result = service.plan_route({ 'destinations' => ['Paris', 'London'], 'transport_mode' => 'invalid_mode' })
      expect(result[:transport_mode]).to eq('invalid_mode')
      expect(result[:segments]).to be_an(Array)
    end
  end

  describe 'data consistency' do
    it 'returns consistent data structures' do
      weather_result = service.get_weather({ 'location' => 'Paris' })
      accommodation_result = service.get_accommodation({ 'location' => 'Paris', 'check_in' => '2025-07-15', 'check_out' => '2025-07-20' })
      route_result = service.plan_route({ 'destinations' => ['Paris', 'London'] })

      # All results should be hashes
      expect(weather_result).to be_a(Hash)
      expect(accommodation_result).to be_a(Hash)
      expect(route_result).to be_a(Hash)

      # All results should have a note field
      expect(weather_result).to have_key(:note)
      expect(accommodation_result).to have_key(:note)
      expect(route_result).to have_key(:note)
    end
  end
end 