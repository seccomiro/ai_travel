require 'openai'
require_dependency 'ai_tools_registry'

class OpenaiChatService
  DEFAULT_MODEL = 'gpt-4o' # or "gpt-4-turbo-preview" if preferred
  DEFAULT_TEMPERATURE = 0.7

  def initialize(api_key: Rails.application.credentials.open_ai_api_key, client: nil)
    @client = client || OpenAI::Client.new(access_token: api_key)
  end

  # messages: [{role: 'user'|'assistant'|'system', content: '...'}]
  def chat(trip, messages, model: DEFAULT_MODEL, temperature: DEFAULT_TEMPERATURE, tools: true)
    params = {
      model: model,
      messages: messages,
      temperature: temperature,
    }
    params[:tools] = AIToolsRegistry.new(trip).definitions if tools
    params[:tool_choice] = 'auto' if tools

    response = @client.chat(parameters: params)
    if response.dig('choices', 0, 'message', 'content') || response.dig('choices', 0, 'message', 'tool_calls')
      {
        content: response.dig('choices', 0, 'message', 'content'),
        usage: response['usage'],
        tool_calls: response.dig('choices', 0, 'message', 'tool_calls'),
      }
    else
      raise "OpenAI API error: #{response['error'] || response}"
    end
  end
end
