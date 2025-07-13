require 'rails_helper'

RSpec.describe OpenaiChatService, type: :service do
  let(:api_key) { 'test-api-key' }
  let(:mock_client) { instance_double('OpenAI::Client') }
  let(:service) { described_class.new(api_key: api_key, client: mock_client) }
  let(:trip) { create(:trip) } # Create a trip for the tests
  let(:messages) { [{ role: 'user', content: 'Hello' }] }
  let(:mock_response) do
    {
      'choices' => [
        {
          'message' => {
            'content' => 'Hello! How can I help you?',
            'role' => 'assistant'
          }
        }
      ],
      'usage' => {
        'prompt_tokens' => 10,
        'completion_tokens' => 20,
        'total_tokens' => 30
      }
    }
  end
  let(:mock_tool_definitions) do
    [
      { type: 'function', function: { name: 'get_weather', description: 'Get weather' } },
      { type: 'function', function: { name: 'search_accommodation', description: 'Search accommodation' } }
    ]
  end
  let(:mock_ai_tools_registry) { instance_double(AIToolsRegistry) }

  describe '#initialize' do
    it 'initializes with OpenAI client' do
      expect(service.instance_variable_get(:@client)).to eq(mock_client)
    end
  end

  describe '#chat' do
    before do
      allow(AIToolsRegistry).to receive(:new).with(trip).and_return(mock_ai_tools_registry)
      allow(mock_ai_tools_registry).to receive(:definitions).and_return(mock_tool_definitions)
      allow(mock_client).to receive(:chat).and_return(mock_response)
    end

    it 'calls OpenAI API with correct parameters' do
      expect(mock_client).to receive(:chat).with(
        parameters: {
          model: 'gpt-4o',
          messages: messages,
          temperature: 0.7,
          tools: mock_tool_definitions,
          tool_choice: 'auto'
        }
      ).and_return(mock_response)

      service.chat(trip, messages)
    end

    it 'returns the response from OpenAI' do
      result = service.chat(trip, messages)

      expect(result).to eq({
        content: 'Hello! How can I help you?',
        usage: {
          'prompt_tokens' => 10,
          'completion_tokens' => 20,
          'total_tokens' => 30
        },
        tool_calls: nil
      })
    end

    it 'handles functions when provided' do
      # This test is somewhat redundant now as tools are handled by default,
      # but we can adjust it to test the `tools: false` path.
      expect(mock_client).to receive(:chat).with(
        parameters: {
          model: 'gpt-4o',
          messages: messages,
          temperature: 0.7
          # No :tools or :tool_choice
        }
      ).and_return(mock_response)

      service.chat(trip, messages, tools: false)
    end

    it 'handles function calling when response includes function call' do
      response_with_function = Marshal.load(Marshal.dump(mock_response))
      response_with_function['choices'][0]['message']['tool_calls'] = [
        {
          'id' => 'call_123',
          'type' => 'function',
          'function' => {
            'name' => 'get_weather',
            'arguments' => '{"location": "Paris"}',
          },
        },
      ]

      allow(mock_client).to receive(:chat).and_return(response_with_function)

      result = service.chat(trip, messages)

      expect(result[:tool_calls]).to eq([
        {
          'id' => 'call_123',
          'type' => 'function',
          'function' => {
            'name' => 'get_weather',
            'arguments' => '{"location": "Paris"}',
          },
        },
      ])
    end
  end

  describe '#chat error handling' do
    let(:service_without_key) { described_class.new(api_key: nil, client: mock_client) }

    before do
      # No need to mock AIToolsRegistry here as the client call will fail first
    end

    context 'when API call fails' do
      it 'raises the error' do
        allow(mock_client).to receive(:chat).and_raise(StandardError.new('API error'))
        expect { service.chat(trip, messages) }.to raise_error(StandardError, 'API error')
      end
    end

    context 'when network error occurs' do
      it 'raises the network error' do
        allow(mock_client).to receive(:chat).and_raise(Net::OpenTimeout.new('Connection timeout'))
        expect { service.chat(trip, messages) }.to raise_error(Net::OpenTimeout)
      end
    end

    context 'when OpenAI returns an error message' do
      it 'raises a custom error' do
        error_response = { 'error' => { 'message' => 'Invalid API key' } }
        allow(mock_client).to receive(:chat).and_return(error_response)
        expect { service.chat(trip, messages) }.to raise_error(/OpenAI API error/)
      end
    end
  end
end
