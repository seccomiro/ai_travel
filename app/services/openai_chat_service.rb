require 'openai'
require_dependency 'ai_tools_registry'

class OpenaiChatService
  DEFAULT_MODEL = 'gpt-4o' # Using a more reliable model for function calling
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
    if tools
      params[:tools] = AIToolsRegistry.new(trip).definitions
      params[:tool_choice] = 'required'
      Rails.logger.info "Providing #{params[:tools].length} tools to AI with required tool choice"
    end

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
