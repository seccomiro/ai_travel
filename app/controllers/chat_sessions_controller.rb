class ChatSessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_trip
  before_action :set_chat_session, only: [:show, :create_message]
  before_action :ensure_trip_owner, only: [:show, :create_message]

  def show
    # Show the chat interface for the trip
  end

  def create
    @chat_session = @trip.chat_sessions.create!
    redirect_to trip_chat_session_path(@trip, @chat_session)
  rescue => e
    Rails.logger.error("Failed to create chat session: #{e.message}")
    redirect_to @trip, alert: t('chat_sessions.create_error')
  end

  def create_message
    @message = @chat_session.chat_messages.build(
      role: 'user',
      content: params[:content]
    )

    if @message.save
      # Process with AI and create assistant response
      process_ai_response(@message)

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            # Remove the typing indicator
            turbo_stream.update('ai-typing', ''),
            # Add the AI response
            turbo_stream.append('chat-messages', partial: 'chat_messages/message', locals: { message: @chat_session.chat_messages.where(role: 'assistant').last }),
            # Reset the form
            turbo_stream.update('message-form', partial: 'chat_sessions/message_form', locals: { chat_session: @chat_session }),
            # Update trip sidebar
            turbo_stream.update('trip-sidebar', partial: 'trips/sidebar_content', locals: { trip: @trip }),
          ]
        end
        format.html { redirect_to trip_chat_session_path(@trip, @chat_session) }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            # Remove typing indicator
            turbo_stream.update('ai-typing', ''),
            # Show error in form
            turbo_stream.update('message-form',
              partial: 'chat_sessions/message_form',
              locals: { chat_session: @chat_session, error: @message.errors.full_messages.join(', ') }),
          ]
        end
        format.html { redirect_to trip_chat_session_path(@trip, @chat_session), alert: @message.errors.full_messages.join(', ') }
      end
    end
  end

  private

  def set_trip
    @trip = Trip.find(params[:trip_id])
  end

  def set_chat_session
    @chat_session = @trip.chat_sessions.find(params[:id])
  end

  def ensure_trip_owner
    unless @trip.user == current_user
      redirect_to trips_path, alert: t('trips.access_denied')
    end
  end

  def process_ai_response(user_message)
    service = OpenaiChatService.new
    messages = @chat_session.conversation_for_ai
    ai_result = service.chat(messages)

    if ai_result && ai_result[:content].present?
      # Check if AI made tool calls
      if ai_result[:tool_calls].present?
        # Execute tool calls and get results
        tool_results = []
        ai_result[:tool_calls].each do |tool_call|
          tool_name = tool_call['function']['name']
          arguments = JSON.parse(tool_call['function']['arguments'])
          result = TravelToolsService.call_tool(tool_name, arguments)

          tool_results << {
            tool_call_id: tool_call['id'],
            role: 'tool',
            name: tool_name,
            content: result.to_json,
          }
        end

        # Add tool results to messages and get final AI response
        messages_with_tools = messages + tool_results
        final_result = service.chat(messages_with_tools, tools: false)

        if final_result && final_result[:content].present?
          @chat_session.chat_messages.create!(
            role: 'assistant',
            content: final_result[:content],
            metadata: {
              usage: final_result[:usage],
              tool_calls: ai_result[:tool_calls],
              tool_results: tool_results,
              model: OpenaiChatService::DEFAULT_MODEL,
            }
          )
        else
          create_fallback_message
        end
      else
        # No tool calls, just save the response
        @chat_session.chat_messages.create!(
          role: 'assistant',
          content: ai_result[:content],
          metadata: {
            usage: ai_result[:usage],
            model: OpenaiChatService::DEFAULT_MODEL,
          }
        )
      end
    else
      create_fallback_message
    end

    update_trip_from_conversation(user_message, @chat_session.last_message)
  end

  def create_fallback_message
    @chat_session.chat_messages.create!(
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
