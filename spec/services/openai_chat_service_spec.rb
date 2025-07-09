require 'rails_helper'

RSpec.describe OpenaiChatService, type: :service do
  let(:api_key) { 'test-api-key' }
  let(:mock_client) { double('OpenAI::Client') }
  let(:service) { described_class.new(api_key: api_key, client: mock_client) }
  let(:messages) { [{ role: 'user', content: 'Hello' }] }
  let(:mock_response) do
    {
      'choices' => [
        {
          'message' => {
            'content' => 'Hello! How can I help you?',
            'role' => 'assistant',
          },
        },
      ],
      'usage' => {
        'prompt_tokens' => 10,
        'completion_tokens' => 20,
        'total_tokens' => 30,
      },
    }
  end

  describe '#initialize' do
    it 'initializes with OpenAI client' do
      expect(service.instance_variable_get(:@client)).to eq(mock_client)
    end
  end

  describe '#chat' do
    before do
      allow(mock_client).to receive(:chat).and_return(mock_response)
    end

    it 'calls OpenAI API with correct parameters' do
      expect(mock_client).to receive(:chat).with(
        parameters: {
          model: 'gpt-4o',
          messages: messages,
          temperature: 0.7,
          tools: kind_of(Array),
        }
      ).and_return(mock_response)

      service.chat(messages)
    end

    it 'returns the response from OpenAI' do
      result = service.chat(messages)

      expect(result).to eq({
        content: 'Hello! How can I help you?',
        usage: {
          'prompt_tokens' => 10,
          'completion_tokens' => 20,
          'total_tokens' => 30,
        },
        tool_calls: nil,
      })
    end

    it 'handles functions when provided' do
      tools = [{ type: 'function', function: { name: 'test_tool' } }]

      expect(mock_client).to receive(:chat).with(
        parameters: hash_including(tools: tools)
      ).and_return(mock_response)

      service.chat(messages, tools: tools)
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

      result = service.chat(messages)

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
    context 'when API key is missing' do
      it 'raises an error' do
        service_without_key = described_class.new(api_key: nil, client: mock_client)
        allow(mock_client).to receive(:chat).and_raise(StandardError.new('API key required'))
        expect { service_without_key.chat(messages) }.to raise_error(StandardError, 'API key required')
      end
    end

    context 'when API call fails' do
      it 'raises the error' do
        allow(mock_client).to receive(:chat).and_raise(StandardError.new('API error'))
        expect { service.chat(messages) }.to raise_error(StandardError, 'API error')
      end
    end

    context 'when network error occurs' do
      it 'raises the network error' do
        allow(mock_client).to receive(:chat).and_raise(Net::OpenTimeout.new('Connection timeout'))
        expect { service.chat(messages) }.to raise_error(Net::OpenTimeout)
      end
    end
  end
end
