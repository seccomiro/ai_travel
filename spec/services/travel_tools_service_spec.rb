require 'rails_helper'

RSpec.describe TravelToolsService, type: :service do
  let(:service) { described_class }
  let(:trip) { create(:trip) }

  describe '.call_tool' do
    it 'calls get_weather when tool name is get_weather' do
      tool_call = {
        'function' => {
          'name' => 'get_weather',
          'arguments' => '{"location": "Paris"}'
        }
      }
      result = service.call_tool(tool_call, trip)

      expect(result).to include(:location)
      expect(result[:location]).to eq('Paris')
      expect(result).to include(:temperature)
      expect(result).to include(:condition)
    end

    it 'calls search_accommodation when tool name is search_accommodation' do
      tool_call = {
        'function' => {
          'name' => 'search_accommodation',
          'arguments' => '{"location": "Paris"}'
        }
      }
      result = service.call_tool(tool_call, trip)

      expect(result).to include(:location)
      expect(result[:location]).to eq('Paris')
      expect(result).to include(:options)
      expect(result[:options]).to be_an(Array)
    end

    it 'calls plan_route when tool name is plan_route' do
      tool_call = {
        'function' => {
          'name' => 'plan_route',
          'arguments' => '{"destinations": ["Paris", "London"]}'
        }
      }
      result = service.call_tool(tool_call, trip)

      expect(result).to include(:destinations)
      expect(result[:destinations]).to eq(['Paris', 'London'])
    end

    it 'returns error for unknown tool' do
      tool_call = {
        'function' => {
          'name' => 'unknown_tool',
          'arguments' => '{}'
        }
      }
      result = service.call_tool(tool_call, trip)
      expect(result).to eq({ error: 'Unknown tool: unknown_tool' })
    end
  end

  describe '.get_weather' do
    it 'returns weather information for the location' do
      args = { 'location' => 'Paris' }
      result = service.send(:get_weather, args)

      expect(result).to include(:location, :temperature, :condition, :note)
      expect(result[:location]).to eq('Paris')
    end

    it 'returns temperature in reasonable range' do
      args = { 'location' => 'Paris' }
      result = service.send(:get_weather, args)
      temp_value = result[:temperature].to_i
      expect(temp_value).to be_between(15, 30)
    end

    it 'returns valid weather conditions' do
      args = { 'location' => 'Paris' }
      result = service.send(:get_weather, args)
      valid_conditions = ['Sunny', 'Cloudy', 'Rainy', 'Windy']
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

      expect(result).to include(:location, :options, :note)
      expect(result[:location]).to eq('Paris')
      expect(result[:options]).to be_an(Array)
    end

    it 'returns multiple accommodation options' do
      result = service.send(:search_accommodation, args)
      expect(result[:options].length).to eq(2)
    end
  end

  describe '.plan_route' do
    it 'returns route planning information' do
      args = { 'destinations' => ['Paris', 'London'], 'transport_mode' => 'train' }
      result = service.send(:plan_route, args)

      expect(result).to include(:destinations, :transport_mode)
      expect(result[:destinations]).to eq(['Paris', 'London'])
      expect(result[:transport_mode]).to eq('train')
    end

    it 'uses default transport mode when not specified' do
      args = { 'destinations' => ['Paris', 'London'] }
      result = service.send(:plan_route, args)
      expect(result[:transport_mode]).to eq('driving')
    end
  end

  describe 'error handling' do
    it 'handles invalid JSON gracefully' do
      tool_call = {
        'function' => {
          'name' => 'get_weather',
          'arguments' => '{"location": "Paris"' # Invalid JSON
        }
      }
      result = service.call_tool(tool_call, trip)
      expect(result).to eq({ error: 'Invalid arguments for tool call' })
    end
  end
end
