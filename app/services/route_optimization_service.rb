# frozen_string_literal: true

class RouteOptimizationService
  def initialize(trip)
    @trip = trip
    @directions_service = GoogleDirectionsService.new
  end

  # Main method to calculate and optimize a complete route
  def calculate_optimized_route(segments, user_preferences = {})
    Rails.logger.info "Calculating optimized route for #{segments.length} segments"

    # Get user preferences from trip data or use defaults
    preferences = extract_user_preferences(user_preferences)

    # Calculate initial routes for all segments
    initial_results = calculate_all_segments(segments, preferences)

    # Validate and fix any problematic segments
    optimized_results = optimize_segments(initial_results, preferences)

    # Generate the final route summary
    final_route = build_final_route(optimized_results, preferences)

    Rails.logger.info "Route optimization complete. Final segments: #{final_route[:segments].length}"

    final_route
  end

  private

  def extract_user_preferences(user_preferences)
    trip_data = @trip.trip_data || {}

    {
      max_daily_drive_h: user_preferences[:max_daily_drive_h] || trip_data.dig('route_preferences', 'max_daily_drive_h') || 8,
      max_daily_distance_km: user_preferences[:max_daily_distance_km] || 800,
      avoid: user_preferences[:avoid] || trip_data.dig('route_preferences', 'avoid') || []
    }
  end

  def calculate_all_segments(segments, preferences)
    Rails.logger.info "Calculating #{segments.length} route segments"

    @directions_service.calculate_trip_segments(segments, preferences).map.with_index do |result, index|
      if result[:error]
        Rails.logger.error "Error calculating segment #{index + 1}: #{result[:error]}"
        result
      else
        validation = @directions_service.validate_segment(result[:route], preferences)
        result.merge(validation: validation, segment_index: index)
      end
    end
  end

  def optimize_segments(results, preferences)
    optimized_results = []

    results.each do |result|
      if result[:error]
        # Keep error results as-is
        optimized_results << result
      elsif result[:validation][:valid]
        # Valid segment, keep as-is
        optimized_results << result
      else
        # Invalid segment, need to split it
        Rails.logger.info "Splitting invalid segment: #{result[:segment][:origin]} to #{result[:segment][:destination]}"
        split_segments = split_long_segment(result, preferences)
        optimized_results.concat(split_segments)
      end
    end

    optimized_results
  end

  def split_long_segment(result, preferences)
    route = result[:route]
    segment = result[:segment]

    # Get suggested splits from the validation
    suggested_splits = result[:validation][:suggested_splits]

    if suggested_splits.any?
      # Use the suggested splits to create new segments
      new_segments = []
      current_origin = segment[:origin]

      suggested_splits.each do |split|
        # Create intermediate segment
        new_segments << {
          origin: current_origin,
          destination: split[:stop_location],
          waypoints: []
        }
        current_origin = split[:stop_location]
      end

      # Add final segment
      new_segments << {
        origin: current_origin,
        destination: segment[:destination],
        waypoints: []
      }

      # Recalculate all the new segments
      calculate_all_segments(new_segments, preferences)
    else
      # No specific splits suggested, try to find intermediate stops
      intermediate_stops = find_intermediate_stops(route, preferences)

      if intermediate_stops.any?
        new_segments = []
        current_origin = segment[:origin]

        intermediate_stops.each do |stop|
          new_segments << {
            origin: current_origin,
            destination: stop,
            waypoints: []
          }
          current_origin = stop
        end

        new_segments << {
          origin: current_origin,
          destination: segment[:destination],
          waypoints: []
        }

        calculate_all_segments(new_segments, preferences)
      else
        # Fallback: just return the original segment with a warning
        Rails.logger.warn "Could not find suitable intermediate stops for segment: #{segment[:origin]} to #{segment[:destination]}"
        [result]
      end
    end
  end

  def find_intermediate_stops(route, preferences)
    # This is a simplified approach - in a real implementation, you'd use
    # Google Places API to find actual towns along the route
    leg = route[:legs].first
    total_distance = leg[:distance_km]
    total_hours = leg[:duration_hours]

    # Calculate how many days needed
    days_needed = [total_hours / preferences[:max_daily_drive_h], total_distance / preferences[:max_daily_distance_km]].max.ceil

    return [] if days_needed <= 1

    # For now, we'll suggest generic intermediate stops
    # In a real implementation, you'd use geocoding to find actual towns
    stops = []

    (1...days_needed).each do |day|
      progress_ratio = day.to_f / days_needed
      estimated_distance = total_distance * progress_ratio

      # Try to find a reasonable stopping point
      # This would need Google Places API integration for real towns
      stop_name = "Intermediate Stop #{day}"

      stops << stop_name
    end

    stops
  end

  def build_final_route(results, preferences)
    successful_results = results.reject { |r| r[:error] }

    # Build the final route structure
    final_route = {
      id: SecureRandom.uuid,
      created_at: Time.current.iso8601,
      segments: successful_results.map { |result| format_segment_for_route(result) },
      summary: generate_route_summary(successful_results),
      preferences: preferences,
      warnings: results.select { |r| r[:error] }.map { |r| r[:error] }
    }

    # Store the optimized route in trip data
    @trip.trip_data = (@trip.trip_data || {}).merge('current_route' => final_route)
    @trip.save if @trip.changed?

    final_route
  end

  def format_segment_for_route(result)
    route = result[:route]
    leg = route[:legs].first

    {
      id: route[:route_id],
      origin: leg[:origin],
      destination: leg[:destination],
      distance_km: leg[:distance_km],
      duration_hours: leg[:duration_hours],
      distance_text: leg[:distance_text],
      duration_text: leg[:duration_text],
      polyline: route[:polyline],
      bounds: route[:bounds],
      valid: result[:validation][:valid],
      issues: result[:validation][:issues] || []
    }
  end

  def generate_route_summary(results)
    return { total_segments: 0, total_distance: 0, total_duration: 0 } if results.empty?

    total_distance = results.sum { |r| r[:route][:total_distance_km] }
    total_duration = results.sum { |r| r[:route][:total_duration_hours] }
    valid_segments = results.count { |r| r[:validation][:valid] }

    {
      total_segments: results.length,
      total_distance_km: total_distance.round(1),
      total_duration_hours: total_duration.round(1),
      valid_segments: valid_segments,
      invalid_segments: results.length - valid_segments,
      average_distance_per_segment: (total_distance / results.length).round(1),
      average_duration_per_segment: (total_duration / results.length).round(1)
    }
  end
end