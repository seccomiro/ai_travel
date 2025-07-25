# frozen_string_literal: true

class ChatResponseService
  def initialize(chat_session)
    @chat_session = chat_session
    @trip = @chat_session.trip
  end

  def call(user_message)
    service = OpenaiChatService.new
    messages = @chat_session.conversation_for_ai
    ai_result = service.chat(@trip, messages)

    assistant_message = if ai_result && (ai_result[:content].present? || ai_result[:tool_calls].present?)
      if ai_result[:tool_calls].present?
        handle_tool_calls(ai_result, messages)
      else
        create_assistant_message(ai_result[:content], {
                                   usage: ai_result[:usage],
                                   model: OpenaiChatService::DEFAULT_MODEL,
                                 })
      end
    else
      create_fallback_message
    end

    update_trip_from_conversation(user_message, assistant_message) if assistant_message.persisted?

    assistant_message
  end

  private

  def handle_tool_calls(ai_result, messages)
    tool_results, route_object = execute_tool_calls(ai_result[:tool_calls])

    # If a route was planned or modified, store the details for the frontend to use.
    if route_object
      @trip.update(trip_data: @trip.trip_data.merge('current_route' => route_object))
    end

    # Add the assistant message with tool calls to the history
    assistant_message_with_tools = {
      role: 'assistant',
      content: nil,
      tool_calls: ai_result[:tool_calls],
    }

    messages_with_tools = messages + [assistant_message_with_tools] + tool_results
    final_result = OpenaiChatService.new.chat(@trip, messages_with_tools, tools: false)

    if final_result && final_result[:content].present?
      metadata = {
        usage: final_result[:usage],
        tool_calls: ai_result[:tool_calls],
        tool_results: tool_results,
        model: OpenaiChatService::DEFAULT_MODEL,
      }
      # Add the final route object to the message metadata for historical record.
      metadata[:route] = route_object if route_object
      create_assistant_message(final_result[:content], metadata)
    else
      create_fallback_message
    end
  end

  def execute_tool_calls(tool_calls)
    route_object = nil
    results = tool_calls.map do |tool_call|
      result = TravelToolsService.call_tool(tool_call, @trip)

      # If a route tool was called, capture the resulting route object.
      tool_name = tool_call.dig('function', 'name')
      if ['plan_route', 'modify_route'].include?(tool_name)
        route_object = {
          'id' => Time.current.to_i,
          'destinations' => result[:destinations],
          'mode' => result[:transport_mode],
        }
      end

      {
        tool_call_id: tool_call['id'],
        role: 'tool',
        name: tool_name,
        content: result.to_json,
      }
    end
    [results, route_object]
  end

  def create_assistant_message(content, metadata)
    @chat_session.chat_messages.create(
      role: 'assistant',
      content: content,
      metadata: metadata
    )
  end

  def create_fallback_message
    @chat_session.chat_messages.create(
      role: 'assistant',
      content: "Sorry, I'm having trouble connecting to the AI right now. Please try again later.",
      metadata: { error: true }
    )
  end

  def update_trip_from_conversation(_user_message, _ai_response)
    # This is a placeholder for future logic to extract trip details
    # from the conversation and update the trip model.
    # For now, it just updates the timestamp.
    trip_data = @trip.trip_data || {}
    trip_data['last_chat_update'] = Time.current.iso8601
    @trip.update(trip_data: trip_data)
  end
end
