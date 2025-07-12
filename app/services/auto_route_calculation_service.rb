# frozen_string_literal: true

class AutoRouteCalculationService
  def initialize(chat_session)
    @chat_session = chat_session
    @trip = chat_session.trip
    @detector = RouteRequestDetectorService.new(@trip)
  end

  # Main method to check if we need to auto-calculate a route
  def should_auto_calculate?(user_message, ai_response)
    return false unless @detector.route_request?(user_message)

    # Check if the AI already called a route tool
    tool_called = ai_response[:tool_calls]&.any? do |tool_call|
      tool_call[:name] == 'optimize_route' || tool_call[:name] == 'calculate_route'
    end

    !tool_called
  end

  # Auto-calculate route and return the result
  def auto_calculate_route(user_message)
    Rails.logger.info "Auto-calculating route for user message: #{user_message[0..100]}..."

    # Try to extract segments from the user message
    segments = @detector.extract_segments_from_message(user_message)

    # If we can't extract from message, try to build from trip data
    if segments.blank?
      segments = @detector.build_segments_from_trip
    end

    # If still no segments, we can't auto-calculate
    if segments.blank?
      Rails.logger.warn "Could not extract route segments from message or trip data"
      return {
        success: false,
        error: "Could not determine route segments. Please specify your destinations clearly."
      }
    end

    # Get user preferences
    preferences = @detector.extract_preferences_from_trip

    # Calculate the route
    begin
      optimization_service = RouteOptimizationService.new(@trip)
      optimized_route = optimization_service.calculate_optimized_route(segments, preferences)

      Rails.logger.info "Auto-calculated route with #{optimized_route[:segments].length} segments"

      {
        success: true,
        route: optimized_route,
        message: format_route_message(optimized_route)
      }
    rescue => e
      Rails.logger.error "Auto route calculation failed: #{e.message}"
      {
        success: false,
        error: "Failed to calculate route: #{e.message}"
      }
    end
  end

  private

  def format_route_message(optimized_route)
    segments = optimized_route[:segments]
    summary = optimized_route[:summary]

    return "Route calculation failed." if segments.blank?

    message = "🚗 **Route Calculated Successfully!**\n\n"

    # Add route overview
    if segments.length == 1
      segment = segments.first
      message += "**Route:** #{segment[:origin]} → #{segment[:destination]}\n"
      message += "**Distance:** #{segment[:distance_text]}\n"
      message += "**Duration:** #{segment[:duration_text]}\n"
    else
      message += "**Multi-segment Route:**\n"
      segments.each_with_index do |segment, index|
        message += "#{index + 1}. #{segment[:origin]} → #{segment[:destination]} (#{segment[:distance_text]}, #{segment[:duration_text]})\n"
      end
      message += "\n**Total:** #{summary[:total_distance_km].round}km, #{summary[:total_duration_hours].round}h\n"
    end

    # Add warnings if any
    if optimized_route[:warnings]&.any?
      message += "\n⚠️ **Warnings:**\n"
      optimized_route[:warnings].each do |warning|
        message += "• #{warning}\n"
      end
    end

    # Add recommendations
    if optimized_route[:recommendations]&.any?
      message += "\n💡 **Recommendations:**\n"
      optimized_route[:recommendations].each do |rec|
        message += "• #{rec[:message]}\n"
      end
    end

    message
  end
end