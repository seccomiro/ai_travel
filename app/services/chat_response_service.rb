# frozen_string_literal: true

class ChatResponseService
  def initialize(chat_session)
    @chat_session = chat_session
    @trip = @chat_session.trip
  end

  def call(user_message)
    # Check if this is a route request before calling AI
    if is_route_request?(user_message)
      return handle_route_request(user_message)
    end

    # For non-route requests, proceed with normal AI chat
    service = OpenaiChatService.new
    messages = build_messages_with_system_prompt
    ai_result = service.chat(@trip, messages, tools: false)  # No tools for non-route requests

    if ai_result && ai_result[:content].present?
      assistant_message = create_assistant_message(ai_result[:content], {
        usage: ai_result[:usage],
        model: OpenaiChatService::DEFAULT_MODEL,
      })
      update_trip_from_conversation(user_message, assistant_message) if assistant_message.persisted?
      return { message: assistant_message, trip: @trip }
    else
      assistant_message = create_fallback_message
      update_trip_from_conversation(user_message, assistant_message) if assistant_message.persisted?
      return { message: assistant_message, trip: @trip }
    end
  end

  private

  def handle_route_request(user_message)
    Rails.logger.info "Handling route request for trip #{@trip.id}"

    # Force route calculation without AI promises
    route_result = force_route_tool_usage(user_message)

    if route_result && route_result[:success]
      # Update trip with the route result
      trip_data = @trip.trip_data || {}
      trip_data['current_route'] = route_result[:route]
      trip_data['last_chat_update'] = Time.current.iso8601
      @trip.update(trip_data: trip_data)

      # Generate response based on actual results
      response_content = generate_route_response(route_result, user_message)

      assistant_message = create_assistant_message(response_content, {
        usage: { total_tokens: 0 },
        model: OpenaiChatService::DEFAULT_MODEL,
        auto_calculated_route: true,
        route_id: route_result[:route]['id']
      })

      update_trip_from_conversation(user_message, assistant_message) if assistant_message.persisted?
      return { message: assistant_message, trip: @trip }
    else
      error_message = "I apologize, but I encountered an issue calculating your route. Please try again or provide more specific location details."
      assistant_message = create_assistant_message(error_message, {
        usage: { total_tokens: 0 },
        model: OpenaiChatService::DEFAULT_MODEL,
        route_calculation_error: true
      })

      return { message: assistant_message, trip: @trip }
    end
  end

  def old_call_method(user_message)
    service = OpenaiChatService.new
    messages = build_messages_with_system_prompt
    ai_result = service.chat(@trip, messages)
    tool_call_made = false

    loop do
      if ai_result && (ai_result[:content].present? || ai_result[:tool_calls].present?)
        if ai_result[:tool_calls].present?
          tool_call_made = true
          tool_results, route_object, details_object = execute_tool_calls(ai_result[:tool_calls])

          # If a route was planned or modified, store the details for the frontend to use.
          if route_object
            # The OptimizeRouteTool already handles breakdown automatically
            # No need to call handle_route_breakdown again

            # Replace the current route instead of merging to avoid accumulating invalid segments
            trip_data = @trip.trip_data || {}
            trip_data['current_route'] = route_object
            trip_data['last_chat_update'] = Time.current.iso8601
            @trip.update(trip_data: trip_data)
          end

          # If trip details were modified, update the trip record.
          if details_object.present?
            details_params = details_object.deep_symbolize_keys
            native_attributes = %i[title description start_date end_date]
            native_params = details_params.slice(*native_attributes)
            trip_data_params = details_params.except(*native_attributes)
            @trip.assign_attributes(native_params) if native_params.any?
            if trip_data_params.any?
              @trip.trip_data = (@trip.trip_data || {}).merge(trip_data_params)
            end
            @trip.save if @trip.changed?
          end

          # Add the assistant message with tool calls to the history
          assistant_message_with_tools = {
            role: 'assistant',
            content: nil,
            tool_calls: ai_result[:tool_calls],
          }
          messages = messages + [assistant_message_with_tools] + tool_results
          ai_result = service.chat(@trip, messages, tools: false)
          next
        else
          # No more tool calls, check if this is a route request that needs tool usage
          if !tool_call_made && is_route_request?(user_message)
            # Force the AI to use route tools instead of trying to resolve routes itself
            forced_tool_result = force_route_tool_usage(user_message)
            if forced_tool_result
              # The OptimizeRouteTool already handles breakdown automatically
              # No need to call handle_route_breakdown again

              # Update trip with the route result
              trip_data = @trip.trip_data || {}
              trip_data['current_route'] = forced_tool_result[:route]
              trip_data['last_chat_update'] = Time.current.iso8601
              @trip.update(trip_data: trip_data)

              # Generate a polished response using a separate LLM call
              polished_response = generate_polished_route_response(forced_tool_result, user_message)

              assistant_message = create_assistant_message(polished_response, {
                usage: ai_result[:usage],
                model: OpenaiChatService::DEFAULT_MODEL,
                auto_calculated_route: true,
                route: forced_tool_result[:route]
              })
            else
              assistant_message = create_assistant_message(ai_result[:content], {
                usage: ai_result[:usage],
                model: OpenaiChatService::DEFAULT_MODEL,
              })
            end
          else
            assistant_message = create_assistant_message(ai_result[:content], {
              usage: ai_result[:usage],
              model: OpenaiChatService::DEFAULT_MODEL,
            })
          end
          update_trip_from_conversation(user_message, assistant_message) if assistant_message.persisted?

          # Check if automatic breakdown is needed after any route calculation
          if trip_data = @trip.trip_data&.dig('current_route')
            automatic_breakdown_result = perform_automatic_breakdown(trip_data)
            if automatic_breakdown_result != trip_data
              # Update trip with the automatically broken down route
              trip_data = @trip.trip_data || {}
              trip_data['current_route'] = automatic_breakdown_result
              trip_data['last_chat_update'] = Time.current.iso8601
              @trip.update(trip_data: trip_data)

              # Update the assistant message to reflect the automatic breakdown
              if assistant_message.persisted?
                assistant_message.update(content: assistant_message.content + "\n\nI've automatically broken down the long segments into smaller, more manageable parts that fit within your driving preferences.")
              end
            end
          end

          return { message: assistant_message, trip: @trip }
        end
      else
        assistant_message = create_fallback_message
        update_trip_from_conversation(user_message, assistant_message) if assistant_message.persisted?
        return { message: assistant_message, trip: @trip }
      end
    end
  end

  private

  def build_messages_with_system_prompt
    # Start with the system prompt
    system_prompt = AIPrompts::TripPlanningSystemPrompt.generate(@trip.user)
    messages = [{
      role: 'system',
      content: system_prompt
    }]

    # Add the conversation history
    messages + @chat_session.conversation_for_ai
  end

  def generate_route_response(route_result, user_message)
    route = route_result[:route]
    summary = route_result[:summary] || route['summary']
    segments = route_result[:segments] || route['segments']

    # Handle both symbol and string keys in summary
    total_distance = summary[:total_distance_km] || summary['total_distance_km'] || 0
    total_duration = summary[:total_duration_hours] || summary['total_duration_hours'] || 0
    avg_distance = summary[:average_distance_per_segment] || summary['average_distance_per_segment'] || 0
    avg_duration = summary[:average_duration_per_segment] || summary['average_duration_per_segment'] || 0
    invalid_segments = summary[:invalid_segments] || summary['invalid_segments'] || 0

    response = []
    response << "I've calculated your complete road trip itinerary with #{segments.length} segments."
    response << ""
    response << "**Route Summary:**"
    response << "• Total distance: #{total_distance} km"
    response << "• Total driving time: #{total_duration.round(1)} hours"
    response << "• Average per segment: #{avg_distance} km, #{avg_duration.round(1)} hours"

    if invalid_segments > 0
      response << ""
      response << "⚠️ **Note:** #{invalid_segments} segments exceed your 10h/800km constraints and have been automatically broken down into smaller parts."
    end

    response << ""
    response << "**Detailed Route:**"

    segments.each_with_index do |segment, index|
      # Handle both symbol and string keys
      is_valid = segment[:valid] || segment['valid']
      origin = segment[:origin] || segment['origin']
      destination = segment[:destination] || segment['destination']
      distance = segment[:distance_km] || segment['distance_km'] || 0
      duration = segment[:duration_hours] || segment['duration_hours'] || 0
      issues = segment[:issues] || segment['issues']

      status_icon = is_valid ? "✅" : "⚠️"
      response << "#{index + 1}. #{status_icon} **#{origin}** → **#{destination}**"
      response << "   Distance: #{distance} km | Duration: #{duration.round(1)} hours"

      if issues&.any?
        response << "   Issues: #{issues.join(', ')}"
      end
    end

    if route_result[:warnings]&.any?
      response << ""
      response << "**Warnings:**"
      route_result[:warnings].each { |warning| response << "• #{warning}" }
    end

    response << ""
    response << "Your route respects your constraints: daytime driving only, max 10 hours or 800km per segment."

    response.join("\n")
  end

  def is_route_request?(user_message)
    message_content = user_message.is_a?(ChatMessage) ? user_message.content : user_message.to_s
    detector = RouteRequestDetectorService.new(@trip)
    detector.route_request?(message_content)
  end

  def force_route_tool_usage(user_message)
    message_content = user_message.is_a?(ChatMessage) ? user_message.content : user_message.to_s
    detector = RouteRequestDetectorService.new(@trip)

    # Extract segments from the user message
    segments = detector.extract_segments_from_message(message_content)

    # If we can't extract from message, try to build from trip data
    if segments.blank?
      segments = detector.build_segments_from_trip
    end

    # If still no segments, we can't calculate a route
    if segments.blank?
      Rails.logger.warn "Could not extract route segments from message or trip data"
      return nil
    end

    # Convert segments to the format expected by the tool (string keys)
    formatted_segments = segments.map do |segment|
      {
        'origin' => segment[:origin],
        'destination' => segment[:destination],
        'waypoints' => segment[:waypoints] || []
      }
    end

    # Get user preferences
    preferences = detector.extract_preferences_from_trip

    # Use the optimize_route tool to calculate the route
    tool_call = {
      'function' => {
        'name' => 'optimize_route',
        'arguments' => {
          segments: formatted_segments,
          user_preferences: preferences
        }.to_json
      }
    }

    result = TravelToolsService.call_tool(tool_call, @trip)

    if result[:success]
      route_object = {
        'id' => SecureRandom.uuid,
        'summary' => result[:summary],
        'segments' => result[:segments].map { |seg| seg.deep_stringify_keys },
        'warnings' => result[:warnings] || [],
        'created_at' => Time.current.iso8601,
        'preferences' => result[:user_preferences] || {}
      }

      {
        success: true,
        route: route_object,
        segments: result[:segments],
        summary: result[:summary],
        warnings: result[:warnings] || []
      }
    else
      Rails.logger.error "Route calculation failed: #{result[:error]}"
      nil
    end
  end

  def generate_polished_route_response(route_result, user_message)
    # Use a separate LLM call to generate a polished response based on the route result
    service = OpenaiChatService.new

    # Create a context message for the LLM
    context_message = {
      role: 'system',
      content: "You are a helpful travel assistant. The user asked about a route, and we've calculated it using our tools. Generate a natural, helpful response that presents the route information in a user-friendly way. Include the key details like distances, durations, and any warnings or recommendations. Be conversational and helpful."
    }

    # Create a user message with the route data
    user_context = {
      role: 'user',
      content: "The user asked: '#{user_message.content}'. Here's the calculated route data: #{route_result.to_json}. Please provide a helpful response about this route."
    }

    # Get the polished response
    response = service.chat(@trip, [context_message, user_context], tools: false)

    response[:content] || "I've calculated the route for you! Here are the details..."
  end

  def handle_tool_calls(ai_result, messages)
    tool_results, route_object, details_object = execute_tool_calls(ai_result[:tool_calls])

    # If a route was planned or modified, store the details for the frontend to use.
    if route_object
      # Replace the current route instead of merging to avoid accumulating invalid segments
      trip_data = @trip.trip_data || {}
      trip_data['current_route'] = route_object
      trip_data['last_chat_update'] = Time.current.iso8601
      @trip.update(trip_data: trip_data)
    end

    # If trip details were modified, update the trip record.
    if details_object.present?
      details_params = details_object.deep_symbolize_keys
      native_attributes = %i[title description start_date end_date]
      native_params = details_params.slice(*native_attributes)
      trip_data_params = details_params.except(*native_attributes)
      @trip.assign_attributes(native_params) if native_params.any?
      if trip_data_params.any?
        @trip.trip_data = (@trip.trip_data || {}).merge(trip_data_params)
      end
      @trip.save if @trip.changed?
    end

    # Add the assistant message with tool calls to the history
    assistant_message_with_tools = {
      role: 'assistant',
      content: nil,
      tool_calls: ai_result[:tool_calls],
    }
    messages = messages + [assistant_message_with_tools] + tool_results

    { messages: messages, route_object: route_object, details_object: details_object }
  end

  def execute_tool_calls(tool_calls)
    route_object = nil
    details_object = nil
    tool_results = []

    tool_calls.each do |tool_call|
      result = TravelToolsService.call_tool(tool_call, @trip)

      if result[:success]
        # Check if this is a route tool
        tool_name = tool_call.dig('function', 'name') || tool_call[:name]
        if ['optimize_route', 'plan_route'].include?(tool_name)
          route_object = {
            'id' => SecureRandom.uuid,
            'summary' => result[:summary],
            'segments' => result[:segments].map { |seg| seg.deep_stringify_keys },
            'warnings' => result[:warnings] || [],
            'created_at' => Time.current.iso8601,
            'preferences' => result[:user_preferences] || {}
          }
        elsif tool_name == 'modify_trip_details'
          details_object = result[:trip_details]
        end
      end

      tool_results << {
        role: 'tool',
        tool_call_id: tool_call['id'],
        content: result.to_json
      }
    end

    [tool_results, route_object, details_object]
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
      content: "I'm sorry, I couldn't process your request. Please try again."
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

  def handle_route_breakdown(route_object, user_message)
    Rails.logger.info "handle_route_breakdown called with #{route_object['segments']&.length || 0} segments"
    return route_object unless route_object && route_object['segments']

    # Check if there are invalid segments that need breakdown
    invalid_segments = route_object['segments'].select { |seg| seg['valid'] == false }

    Rails.logger.info "Found #{invalid_segments.length} invalid segments"

    if invalid_segments.any?
      Rails.logger.info "Found #{invalid_segments.length} invalid segments that need breakdown"

      # Create a progress message to inform the user
      progress_message = create_assistant_message(
        "I've calculated your route and found #{invalid_segments.length} segments that exceed your driving preferences. I'm now breaking these down into smaller, more manageable segments. This may take a moment...",
        {
          usage: { total_tokens: 0 },
          model: OpenaiChatService::DEFAULT_MODEL,
          route_breakdown_in_progress: true
        }
      )

      # Update trip data to show breakdown is in progress
      trip_data = @trip.trip_data || {}
      trip_data['route_breakdown_in_progress'] = true
      trip_data['last_chat_update'] = Time.current.iso8601
      @trip.update(trip_data: trip_data)

      # Trigger the breakdown process
      Rails.logger.info "Triggering route breakdown..."
      broken_down_route = trigger_route_breakdown(route_object)
      Rails.logger.info "Route breakdown complete, new segments: #{broken_down_route['segments'].length}"

      # Update trip data to show breakdown is complete
      trip_data = @trip.trip_data || {}
      trip_data['route_breakdown_in_progress'] = false
      trip_data['last_chat_update'] = Time.current.iso8601
      @trip.update(trip_data: trip_data)

      # Update the progress message with completion
      progress_message.update(content: "Route breakdown complete! I've split the long segments into smaller, more manageable parts that fit within your driving preferences.")

      return broken_down_route
    end

    Rails.logger.info "No invalid segments found, returning original route"
    route_object
  end

  def trigger_route_breakdown(route_object)
    # Extract segments from the route object
    segments = route_object['segments'].map do |seg|
      {
        'origin' => seg['origin'],
        'destination' => seg['destination'],
        'waypoints' => seg['waypoints'] || []
      }
    end

    # Get user preferences
    preferences = extract_user_preferences_from_trip

    Rails.logger.info "Triggering route breakdown for #{segments.length} segments"

    # Use the route optimization service to break down segments
    optimization_service = RouteOptimizationService.new(@trip)
    broken_down_route = optimization_service.calculate_optimized_route(segments, preferences)

    Rails.logger.info "Route breakdown complete. New segments: #{broken_down_route[:segments].length}"

    # Format the broken down route to match the expected structure
    {
      'id' => SecureRandom.uuid,
      'summary' => broken_down_route[:summary],
      'segments' => broken_down_route[:segments].map { |seg| seg.deep_stringify_keys },
      'warnings' => broken_down_route[:warnings] || [],
      'created_at' => Time.current.iso8601,
      'preferences' => preferences,
      'breakdown_applied' => true
    }
  end

  def extract_user_preferences_from_trip
    trip_data = @trip.trip_data || {}

    {
      max_daily_drive_h: trip_data.dig('route_preferences', 'max_daily_drive_h'),
      max_daily_distance_km: trip_data.dig('route_preferences', 'max_daily_distance_km'),
      avoid: trip_data.dig('route_preferences', 'avoid') || []
    }
  end

  def perform_automatic_breakdown(route_object)
    return route_object unless route_object && route_object['segments']

    # Check if there are invalid segments that need breakdown
    invalid_segments = route_object['segments'].select { |seg| seg['valid'] == false }

    if invalid_segments.any?
      Rails.logger.info "Performing automatic breakdown for #{invalid_segments.length} invalid segments"

      # Create a progress message to inform the user
      progress_message = create_assistant_message(
        "I've detected #{invalid_segments.length} segments that exceed your driving preferences. I'm automatically breaking these down into smaller, more manageable segments...",
        {
          usage: { total_tokens: 0 },
          model: OpenaiChatService::DEFAULT_MODEL,
          route_breakdown_in_progress: true
        }
      )

      # Update trip data to show breakdown is in progress
      trip_data = @trip.trip_data || {}
      trip_data['route_breakdown_in_progress'] = true
      trip_data['last_chat_update'] = Time.current.iso8601
      @trip.update(trip_data: trip_data)

      # Replace rough segments with refined segments based on suggested_splits
      refined_segments = replace_rough_segments_with_refined_ones(route_object['segments'])

      # Update trip data to show breakdown is complete
      trip_data = @trip.trip_data || {}
      trip_data['route_breakdown_in_progress'] = false
      trip_data['last_chat_update'] = Time.current.iso8601
      @trip.update(trip_data: trip_data)

      # Update the progress message with completion
      progress_message.update(content: "Automatic breakdown complete! I've replaced the long segments with smaller, more manageable parts that fit within your driving preferences.")

      # Create new route object with refined segments
      {
        'id' => SecureRandom.uuid,
        'summary' => generate_summary_for_refined_segments(refined_segments),
        'segments' => refined_segments,
        'warnings' => route_object['warnings'] || [],
        'created_at' => Time.current.iso8601,
        'preferences' => route_object['preferences'] || {},
        'breakdown_applied' => true
      }
    else
      route_object
    end
  end

  def replace_rough_segments_with_refined_ones(segments)
    refined_segments = []

    segments.each do |segment|
      if segment['valid'] == false && segment['suggested_splits'].present?
        # Replace this rough segment with refined segments based on suggested_splits
        refined_segments.concat(create_refined_segments_from_splits(segment))
      else
        # Keep valid segments as-is
        refined_segments << segment
      end
    end

    refined_segments
  end

  def create_refined_segments_from_splits(rough_segment)
    refined_segments = []
    current_origin = rough_segment['origin']

    rough_segment['suggested_splits'].each_with_index do |split, index|
      # Create a refined segment with full object structure
      refined_segment = {
        'origin' => current_origin,
        'destination' => improve_location_name(split['stop_location']),
        'distance_km' => split['distance_from_origin'],
        'duration_hours' => split['hours_from_origin'],
        'distance_text' => "#{(split['distance_from_origin']).round} km",
        'duration_text' => format_duration(split['hours_from_origin']),
        'valid' => true, # These are now valid since they're based on suggested splits
        'issues' => [],
        'suggested_splits' => [],
        'waypoints' => []
      }

      refined_segments << refined_segment
      current_origin = improve_location_name(split['stop_location'])
    end

    # Add final segment to the original destination
    final_segment = {
      'origin' => current_origin,
      'destination' => rough_segment['destination'],
      'distance_km' => rough_segment['distance_km'] - rough_segment['suggested_splits'].last['distance_from_origin'],
      'duration_hours' => rough_segment['duration_hours'] - rough_segment['suggested_splits'].last['hours_from_origin'],
      'distance_text' => "#{(rough_segment['distance_km'] - rough_segment['suggested_splits'].last['distance_from_origin']).round} km",
      'duration_text' => format_duration(rough_segment['duration_hours'] - rough_segment['suggested_splits'].last['hours_from_origin']),
      'valid' => true,
      'issues' => [],
      'suggested_splits' => [],
      'waypoints' => []
    }

    refined_segments << final_segment
    refined_segments
  end

  def improve_location_name(location)
    return location if location.blank?

    # If it's already a proper location name, return it
    return location unless location.include?('Intermediate stop')

    # For now, return a more descriptive generic name
    # In a real implementation, this would use geocoding or a database of nearby cities
    case location.downcase
    when /intermediate stop (\d+)/
      stop_number = $1
      "Intermediate stop #{stop_number} (along route)"
    else
      location
    end
  end

  def format_duration(hours)
    if hours < 24
      "#{hours.round(1)} hours"
    else
      days = (hours / 24).floor
      remaining_hours = hours % 24
      if remaining_hours > 0
        "#{days} day#{days != 1 ? 's' : ''} #{remaining_hours.round(1)} hours"
      else
        "#{days} day#{days != 1 ? 's' : ''}"
      end
    end
  end

  def generate_summary_for_refined_segments(segments)
    total_distance = segments.sum { |seg| seg['distance_km'] }
    total_duration = segments.sum { |seg| seg['duration_hours'] }
    valid_segments = segments.count { |seg| seg['valid'] }
    invalid_segments = segments.count { |seg| seg['valid'] == false }

    {
      'total_segments' => segments.length,
      'total_distance_km' => total_distance.round(1),
      'total_duration_hours' => total_duration.round(1),
      'valid_segments' => valid_segments,
      'invalid_segments' => invalid_segments,
      'average_distance_per_segment' => (total_distance / segments.length).round(1),
      'average_duration_per_segment' => (total_duration / segments.length).round(1)
    }
  end
end
