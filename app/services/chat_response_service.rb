class ChatResponseService
  def initialize(chat_session)
    @chat_session = chat_session
    @trip = @chat_session.trip
  end

  def call(user_message)
    service = OpenaiChatService.new
    messages = @chat_session.conversation_for_ai
    ai_result = service.chat(messages)

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
    tool_results = execute_tool_calls(ai_result[:tool_calls])

    messages_with_tools = messages + tool_results
    final_result = OpenaiChatService.new.chat(messages_with_tools, tools: false)

    if final_result && final_result[:content].present?
      create_assistant_message(final_result[:content], {
        usage: final_result[:usage],
        tool_calls: ai_result[:tool_calls],
        tool_results: tool_results,
        model: OpenaiChatService::DEFAULT_MODEL,
      })
    else
      create_fallback_message
    end
  end

  def execute_tool_calls(tool_calls)
    tool_calls.map do |tool_call|
      tool_name = tool_call['function']['name']
      arguments = JSON.parse(tool_call['function']['arguments'])
      result = TravelToolsService.call_tool(tool_name, arguments)

      {
        tool_call_id: tool_call['id'],
        role: 'tool',
        name: tool_name,
        content: result.to_json,
      }
    end
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

  def update_trip_from_conversation(user_message, ai_response)
    # Extract trip data from the conversation
    trip_data = @trip.trip_data || {}

    # Update last chat timestamp
    trip_data['last_chat_update'] = Time.current.iso8601

    # Extract destinations mentioned in the conversation
    if user_message.content.present?
      # Simple destination extraction (can be enhanced with NLP)
      destinations = extract_destinations(user_message.content)
      if destinations.any?
        trip_data['destinations'] ||= []
        trip_data['destinations'] = (trip_data['destinations'] + destinations).uniq
      end

      # Extract dates mentioned
      dates = extract_dates(user_message.content)
      if dates.any?
        trip_data['mentioned_dates'] ||= []
        trip_data['mentioned_dates'] = (trip_data['mentioned_dates'] + dates).uniq
      end

      # Extract preferences
      preferences = extract_preferences(user_message.content)
      if preferences.any?
        trip_data['preferences'] ||= {}
        trip_data['preferences'].merge!(preferences)
      end
    end

    # Update trip with extracted data
    @trip.update(trip_data: trip_data)
  end

  def extract_destinations(text)
    # Simple regex-based extraction (can be enhanced with NLP)
    # Look for common city/country patterns
    destinations = []

    # Common city patterns
    city_patterns = [
      /\b(?:visit|going to|travel to|planning to go to)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)/i,
      /\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s+(?:in|to|for)\s+(?:my\s+)?trip/i,
    ]

    city_patterns.each do |pattern|
      matches = text.scan(pattern)
      destinations.concat(matches.flatten)
    end

    destinations.uniq
  end

  def extract_dates(text)
    # Simple date extraction
    dates = []

    # Common date patterns
    date_patterns = [
      /\b(?:in|on|from|to)\s+(\w+\s+\d{1,2},?\s+\d{4})/i,
      /\b(\d{1,2}\/\d{1,2}\/\d{4})/,
      /\b(\d{4}-\d{2}-\d{2})/,
    ]

    date_patterns.each do |pattern|
      matches = text.scan(pattern)
      dates.concat(matches.flatten)
    end

    dates.uniq
  end

  def extract_preferences(text)
    preferences = {}

    # Extract budget preferences
    if text.match?(/\b(?:budget|cheap|expensive|luxury|affordable)\b/i)
      if text.match?(/\b(?:budget|cheap|affordable)\b/i)
        preferences['budget_level'] = 'budget'
      elsif text.match?(/\b(?:luxury|expensive)\b/i)
        preferences['budget_level'] = 'luxury'
      end
    end

    # Extract accommodation preferences
    if text.match?(/\b(?:hotel|hostel|apartment|airbnb|resort)\b/i)
      preferences['accommodation_type'] = text.match(/\b(hotel|hostel|apartment|airbnb|resort)\b/i)[1].downcase
    end

    # Extract transportation preferences
    if text.match?(/\b(?:car|train|plane|bus|walking)\b/i)
      preferences['transportation'] = text.match(/\b(car|train|plane|bus|walking)\b/i)[1].downcase
    end

    preferences
  end
end
