require 'rails_helper'

RSpec.describe OpenaiChatService do
  let(:service) { described_class.new }
  let(:messages) { [{ role: 'user', content: 'Hello AI!' }] }
  let(:functions) { [] }

  before do
    # Mock Rails credentials
    allow(Rails.application.credentials).to receive(:openai_api_key).and_return('test-api-key')
  end

  describe '#initialize' do
    it 'initializes with OpenAI client' do
      expect(service.client).to be_a(OpenAI::Client)
    end

    it 'sets the API key from credentials' do
      expect(service.client.config.access_token).to eq('test-api-key')
    end
  end

  describe '#chat_completion' do
    let(:mock_response) do
      double(
        'response',
        choices: [
          double(
            'choice',
            message: double('message', content: 'Hello! How can I help you?', function_call: nil)
          )
        ]
      )
    end

    before do
      allow(service.client.chat).to receive(:completions).and_return(mock_response)
    end

    it 'calls OpenAI API with correct parameters' do
      expected_params = {
        parameters: {
          model: 'gpt-4',
          messages: messages,
          temperature: 0.7,
          max_tokens: 1000
        }
      }

      service.chat_completion(messages)
      expect(service.client.chat).to have_received(:completions).with(expected_params)
    end

    it 'returns the response from OpenAI' do
      result = service.chat_completion(messages)
      expect(result).to eq(mock_response)
    end

    it 'handles functions when provided' do
      functions = [
        {
          name: 'get_weather',
          description: 'Get weather information',
          parameters: {
            type: 'object',
            properties: {
              location: { type: 'string' }
            }
          }
        }
      ]

      expected_params = {
        parameters: {
          model: 'gpt-4',
          messages: messages,
          temperature: 0.7,
          max_tokens: 1000,
          functions: functions
        }
      }

      service.chat_completion(messages, functions: functions)
      expect(service.client.chat).to have_received(:completions).with(expected_params)
    end

    it 'handles function calling when response includes function call' do
      function_call = double('function_call', name: 'get_weather', arguments: '{"location":"Paris"}')
      function_message = double('message', content: nil, function_call: function_call)
      
      mock_response_with_function = double(
        'response',
        choices: [
          double('choice', message: function_message)
        ]
      )

      allow(service.client.chat).to receive(:completions).and_return(mock_response_with_function)

      result = service.chat_completion(messages, functions: functions)
      expect(result).to eq(mock_response_with_function)
    end

    context 'when API key is missing' do
      before do
        allow(Rails.application.credentials).to receive(:openai_api_key).and_return(nil)
      end

      it 'raises an error' do
        expect { described_class.new }.to raise_error(StandardError, 'OpenAI API key not found in credentials')
      end
    end

    context 'when API call fails' do
      before do
        allow(service.client.chat).to receive(:completions).and_raise(OpenAI::Error.new('API Error'))
      end

      it 'raises the error' do
        expect { service.chat_completion(messages) }.to raise_error(OpenAI::Error, 'API Error')
      end
    end

    context 'when network error occurs' do
      before do
        allow(service.client.chat).to receive(:completions).and_raise(Net::OpenTimeout.new('Connection timeout'))
      end

      it 'raises the network error' do
        expect { service.chat_completion(messages) }.to raise_error(Net::OpenTimeout, 'Connection timeout')
      end
    end
  end

  describe '#extract_function_call' do
    let(:function_call) do
      double('function_call', name: 'get_weather', arguments: '{"location":"Paris","unit":"celsius"}')
    end

    let(:message) do
      double('message', function_call: function_call)
    end

    let(:choice) do
      double('choice', message: message)
    end

    let(:response) do
      double('response', choices: [choice])
    end

    it 'extracts function call from response' do
      result = service.extract_function_call(response)
      
      expect(result).to eq({
        name: 'get_weather',
        arguments: { 'location' => 'Paris', 'unit' => 'celsius' }
      })
    end

    it 'returns nil when no function call' do
      message_without_function = double('message', function_call: nil)
      choice_without_function = double('choice', message: message_without_function)
      response_without_function = double('response', choices: [choice_without_function])

      result = service.extract_function_call(response_without_function)
      expect(result).to be_nil
    end

    it 'handles invalid JSON in arguments' do
      invalid_function_call = double('function_call', name: 'get_weather', arguments: 'invalid json')
      invalid_message = double('message', function_call: invalid_function_call)
      invalid_choice = double('choice', message: invalid_message)
      invalid_response = double('response', choices: [invalid_choice])

      expect { service.extract_function_call(invalid_response) }.to raise_error(JSON::ParserError)
    end
  end

  describe '#build_system_message' do
    let(:trip) { build(:trip, name: 'Paris Adventure', description: 'A trip to Paris') }

    it 'builds system message with trip context' do
      result = service.build_system_message(trip)
      
      expect(result).to include('You are Tripyo')
      expect(result).to include('Paris Adventure')
      expect(result).to include('A trip to Paris')
    end

    it 'handles trip without description' do
      trip.description = nil
      result = service.build_system_message(trip)
      
      expect(result).to include('Paris Adventure')
      expect(result).to_not include('Description:')
    end

    it 'includes travel tools information' do
      result = service.build_system_message(trip)
      
      expect(result).to include('weather information')
      expect(result).to include('accommodation options')
      expect(result).to include('route planning')
    end
  end

  describe '#extract_trip_data' do
    let(:user_message) { 'I want to go to Paris from July 15-20, 2025. I prefer hotels and want to visit the Eiffel Tower.' }

    it 'extracts destination from message' do
      result = service.extract_trip_data(user_message)
      expect(result[:destinations]).to include('Paris')
    end

    it 'extracts dates from message' do
      result = service.extract_trip_data(user_message)
      expect(result[:start_date]).to eq('2025-07-15')
      expect(result[:end_date]).to eq('2025-07-20')
    end

    it 'extracts preferences from message' do
      result = service.extract_trip_data(user_message)
      expect(result[:preferences]).to include('hotels')
      expect(result[:preferences]).to include('Eiffel Tower')
    end

    it 'handles message without dates' do
      message_without_dates = 'I want to go to Tokyo and stay in a hostel'
      result = service.extract_trip_data(message_without_dates)
      
      expect(result[:destinations]).to include('Tokyo')
      expect(result[:start_date]).to be_nil
      expect(result[:end_date]).to be_nil
    end

    it 'handles message without destinations' do
      message_without_destinations = 'I want to travel from July 1-5, 2025'
      result = service.extract_trip_data(message_without_destinations)
      
      expect(result[:destinations]).to be_empty
      expect(result[:start_date]).to eq('2025-07-01')
      expect(result[:end_date]).to eq('2025-07-05')
    end

    it 'handles empty message' do
      result = service.extract_trip_data('')
      expect(result).to eq({
        destinations: [],
        start_date: nil,
        end_date: nil,
        preferences: []
      })
    end
  end
end 