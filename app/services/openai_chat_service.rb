require 'openai'

class OpenaiChatService
  DEFAULT_MODEL = 'gpt-4o' # or "gpt-4-turbo-preview" if preferred
  DEFAULT_TEMPERATURE = 0.7

  def initialize(api_key: Rails.application.credentials.open_ai_api_key, client: nil)
    @client = client || OpenAI::Client.new(access_token: api_key)
  end

  # messages: [{role: 'user'|'assistant'|'system', content: '...'}]
  def chat(messages, model: DEFAULT_MODEL, temperature: DEFAULT_TEMPERATURE, tools: nil)
    params = {
      model: model,
      messages: messages,
      temperature: temperature,
    }
    params[:tools] = tools || default_tools if tools != false
    response = @client.chat(parameters: params)
    if response.dig('choices', 0, 'message', 'content')
      {
        content: response['choices'][0]['message']['content'],
        usage: response['usage'],
        tool_calls: response['choices'][0]['message']['tool_calls'],
      }
    else
      raise "OpenAI API error: #{response['error'] || response}"
    end
  end

  private

  def default_tools
    [
      {
        type: 'function',
        function: {
          name: 'get_weather',
          description: 'Get current weather information for a specific location',
          parameters: {
            type: 'object',
            properties: {
              location: {
                type: 'string',
                description: "The city and country name (e.g., 'Paris, France')",
              },
            },
            required: ['location'],
          },
        },
      },
      {
        type: 'function',
        function: {
          name: 'search_accommodation',
          description: 'Search for accommodation options in a specific location',
          parameters: {
            type: 'object',
            properties: {
              location: {
                type: 'string',
                description: "The city and country name (e.g., 'Paris, France')",
              },
              check_in: {
                type: 'string',
                description: 'Check-in date in YYYY-MM-DD format',
              },
              check_out: {
                type: 'string',
                description: 'Check-out date in YYYY-MM-DD format',
              },
              guests: {
                type: 'integer',
                description: 'Number of guests',
              },
            },
            required: ['location'],
          },
        },
      },
      {
        type: 'function',
        function: {
          name: 'plan_route',
          description: 'Plan a route between two or more destinations',
          parameters: {
            type: 'object',
            properties: {
              destinations: {
                type: 'array',
                items: {
                  type: 'string',
                },
                description: "Array of destination names (e.g., ['Paris', 'London', 'Rome'])",
              },
              transport_mode: {
                type: 'string',
                enum: ['car', 'train', 'plane', 'bus'],
                description: 'Preferred mode of transportation',
              },
            },
            required: ['destinations'],
          },
        },
      },
    ]
  end
end
