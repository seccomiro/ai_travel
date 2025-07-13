# frozen_string_literal: true

class RouteOptimizationService
  def initialize(trip)
    @trip = trip
    @directions_service = GoogleDirectionsService.new
    @geocoding_service = GoogleGeocodingService.new
  end

  # Main method to calculate and optimize a complete route
  def calculate_optimized_route(segments, user_preferences = {})
    Rails.logger.info "Calculating optimized route for #{segments.length} segments"

    # Get user preferences from trip data or use defaults
    preferences = extract_user_preferences(user_preferences)

    # Calculate initial routes for all segments
    initial_results = calculate_all_segments(segments, preferences)

    # Check if we have API key issues
    api_key_errors = initial_results.select { |r| r[:error]&.include?('API key has restrictions') }
    if api_key_errors.any?
      Rails.logger.error "Google Maps API key restrictions detected"
      return {
        success: false,
        error: "Google Maps API key configuration issue",
        details: "The API key has domain restrictions that prevent server-side requests. Please configure the API key to allow server-side access.",
        segments: [],
        summary: { total_segments: 0, total_distance_km: 0, total_duration_hours: 0 },
        warnings: ["Google Maps API key needs to be configured for server-side requests"]
      }
    end

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
    
    # Handle both symbol and string keys
    prefs = user_preferences || {}
    
    {
      max_daily_drive_h: prefs[:max_daily_drive_h] || prefs['max_daily_drive_h'] || trip_data.dig('route_preferences', 'max_daily_drive_h'),
      max_daily_distance_km: prefs[:max_daily_distance_km] || prefs['max_daily_distance_km'] || trip_data.dig('route_preferences', 'max_daily_distance_km'),
      avoid: prefs[:avoid] || prefs['avoid'] || trip_data.dig('route_preferences', 'avoid') || []
    }
  end

  def calculate_all_segments(segments, preferences)
    Rails.logger.info "Calculating #{segments.length} route segments"

    # Convert segments to use symbol keys for GoogleDirectionsService
    symbol_segments = segments.map do |segment|
      {
        origin: segment['origin'] || segment[:origin],
        destination: segment['destination'] || segment[:destination],
        waypoints: segment['waypoints'] || segment[:waypoints] || []
      }
    end

    @directions_service.calculate_trip_segments(symbol_segments, preferences).map.with_index do |result, index|
      if result[:error]
        Rails.logger.error "Error calculating segment #{index + 1}: #{result[:error]}"

        # Try to resolve unrecognized locations by finding the nearest town
        resolved_result = try_resolve_unrecognized_location(result, index)
        if resolved_result
          resolved_result
        else
          result
        end
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
        # Create intermediate segment with proper location names
        new_segments << {
          origin: current_origin,
          destination: improve_location_name(split[:stop_location]),
          waypoints: []
        }
        current_origin = improve_location_name(split[:stop_location])
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
      # No specific splits suggested, try to find actual intermediate stops
      intermediate_stops = find_actual_intermediate_stops(segment[:origin], segment[:destination], preferences)

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
        # Fallback: try to find generic intermediate stops
        generic_stops = find_intermediate_stops(route, preferences)

        if generic_stops.any?
          new_segments = []
          current_origin = segment[:origin]

          generic_stops.each do |stop|
            new_segments << {
              origin: current_origin,
              destination: improve_location_name(stop),
              waypoints: []
            }
            current_origin = improve_location_name(stop)
          end

          new_segments << {
            origin: current_origin,
            destination: segment[:destination],
            waypoints: []
          }

          calculate_all_segments(new_segments, preferences)
        else
          # Final fallback: just return the original segment with a warning
          Rails.logger.warn "Could not find suitable intermediate stops for segment: #{segment[:origin]} to #{segment[:destination]}"
          [result]
        end
      end
    end
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
      stop_name = "Intermediate stop #{day}"

      stops << stop_name
    end

    stops
  end

  def find_actual_intermediate_stops(origin, destination, preferences)
    # This method would use Google Places API to find actual towns along the route
    # For now, we'll use a simplified approach with known major cities

    # Get coordinates for origin and destination
    origin_coords = get_coordinates(origin)
    destination_coords = get_coordinates(destination)

    return [] unless origin_coords && destination_coords

    # Find cities that are along the route
    potential_stops = find_cities_along_route(origin_coords, destination_coords)

    # Filter cities based on distance preferences
    filtered_stops = filter_cities_by_distance(potential_stops, origin_coords, destination_coords, preferences)

    # Sort by distance from origin
    filtered_stops.sort_by { |stop| calculate_distance(origin_coords, stop[:coordinates]) }
  end

  def get_coordinates(location)
    # Use the geocoding service to get coordinates for any location
    geocode_result = @geocoding_service.geocode_location(location)

    if geocode_result[:error]
      Rails.logger.warn "Could not geocode #{location}: #{geocode_result[:error]}"
      return nil
    end

    geocode_result[:coordinates]
  end

  def try_resolve_unrecognized_location(result, segment_index)
    segment = result[:segment]
    error = result[:error]

    # Check if this is a ZERO_RESULTS error (unrecognized location)
    return nil unless error&.include?('ZERO_RESULTS')

    Rails.logger.info "Attempting to resolve unrecognized location for segment #{segment_index + 1}"

    # Try to find the nearest town for both origin and destination
    origin_nearest_town = @geocoding_service.find_nearest_town(segment[:origin])
    destination_nearest_town = @geocoding_service.find_nearest_town(segment[:destination])

    if origin_nearest_town[:error] && destination_nearest_town[:error]
      Rails.logger.warn "Could not find nearest towns for segment #{segment_index + 1}: origin=#{origin_nearest_town[:error]}, destination=#{destination_nearest_town[:error]}"
      return nil
    end

    # Create new segment with resolved locations
    resolved_segment = {
      origin: origin_nearest_town[:nearest_town] || segment[:origin],
      destination: destination_nearest_town[:nearest_town] || segment[:destination],
      waypoints: segment[:waypoints] || []
    }

    Rails.logger.info "Resolved segment #{segment_index + 1}: #{segment[:origin]} → #{resolved_segment[:origin]}, #{segment[:destination]} → #{resolved_segment[:destination]}"

    # Recalculate the route with resolved locations
    new_result = @directions_service.calculate_route(
      resolved_segment[:origin],
      resolved_segment[:destination],
      { waypoints: resolved_segment[:waypoints] }
    )

    if new_result[:error]
      Rails.logger.warn "Still failed after resolving locations for segment #{segment_index + 1}: #{new_result[:error]}"
      return nil
    end

    # Return the successful result with resolved locations
    {
      segment: resolved_segment,
      route: new_result,
      segment_index: segment_index,
      resolved_from: {
        original_origin: segment[:origin],
        original_destination: segment[:destination],
        origin_nearest_town: origin_nearest_town,
        destination_nearest_town: destination_nearest_town
      }
    }
  end

  def find_cities_along_route(origin_coords, destination_coords)
    # This would use Google Places API to find cities along the route
    # For now, return an empty array to indicate that place search is needed
    Rails.logger.info "Place search needed for route from #{origin_coords} to #{destination_coords}"
    []
  end

  def is_point_between(point_a, point_b, point_c)
    # Simplified check if point_c is between point_a and point_b
    # In reality, you'd use more sophisticated geometric calculations

    # Calculate distances
    distance_ab = calculate_distance(point_a, point_b)
    distance_ac = calculate_distance(point_a, point_c)
    distance_bc = calculate_distance(point_b, point_c)

    # Check if point_c is roughly between a and b
    # Allow some tolerance for the triangle inequality
    tolerance = 0.1
    (distance_ac + distance_bc - distance_ab) / distance_ab < tolerance
  end

  def calculate_distance(point_a, point_b)
    # Haversine formula for calculating distance between two points
    lat1, lon1 = point_a
    lat2, lon2 = point_b

    # Convert to radians
    lat1_rad = lat1 * Math::PI / 180
    lat2_rad = lat2 * Math::PI / 180
    delta_lat = (lat2 - lat1) * Math::PI / 180
    delta_lon = (lon2 - lon1) * Math::PI / 180

    a = Math.sin(delta_lat / 2) * Math.sin(delta_lat / 2) +
        Math.cos(lat1_rad) * Math.cos(lat2_rad) *
        Math.sin(delta_lon / 2) * Math.sin(delta_lon / 2)

    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

    # Earth's radius in kilometers
    earth_radius = 6371

    earth_radius * c
  end

  def filter_cities_by_distance(cities, origin_coords, destination_coords, preferences)
    max_distance = preferences[:max_daily_distance_km] || 800

    cities.select do |city|
      distance_from_origin = calculate_distance(origin_coords, city[:coordinates])
      distance_to_destination = calculate_distance(city[:coordinates], destination_coords)

      # City should be reachable within daily driving limits
      distance_from_origin <= max_distance && distance_to_destination <= max_distance
    end
  end

  def build_final_route(results, preferences)
    successful_results = results.reject { |r| r[:error] }

    if successful_results.empty?
      return {
        success: false,
        error: "No routes could be calculated successfully",
        segments: [],
        summary: { total_segments: 0, total_distance_km: 0, total_duration_hours: 0 },
        warnings: results.map { |r| r[:error] }.compact
      }
    end

    formatted_segments = successful_results.map { |result| format_segment_for_route(result) }
    summary = generate_route_summary(successful_results)

    # Collect warnings including resolution information
    warnings = results.select { |r| r[:error] }.map { |r| r[:error] }

    # Add resolution notes for successfully resolved segments
    resolution_notes = successful_results.select { |r| r[:resolved_from] }.map do |result|
      result[:resolution_note]
    end.compact

    {
      success: true,
      segments: formatted_segments,
      summary: summary,
      warnings: warnings + resolution_notes
    }
  end

  def format_segment_for_route(result)
    route = result[:route]
    validation = result[:validation]

    segment_data = {
      origin: route[:legs].first[:origin],
      destination: route[:legs].first[:destination],
      distance_km: route[:legs].first[:distance_km],
      duration_hours: route[:legs].first[:duration_hours],
      distance_text: route[:legs].first[:distance_text],
      duration_text: route[:legs].first[:duration_text],
      valid: validation[:valid],
      issues: validation[:issues] || [],
      suggested_splits: validation[:suggested_splits] || []
    }

    # Add resolution information if this segment was resolved from unrecognized locations
    if result[:resolved_from]
      segment_data[:resolved_from] = result[:resolved_from]
      segment_data[:resolution_note] = generate_resolution_note(result[:resolved_from])
    end

    segment_data
  end

  def generate_resolution_note(resolved_from)
    notes = []

    if resolved_from[:origin_nearest_town] && !resolved_from[:origin_nearest_town][:error]
      origin_info = resolved_from[:origin_nearest_town]
      notes << "Origin '#{resolved_from[:original_origin]}' resolved to '#{origin_info[:nearest_town]}' (#{origin_info[:distance_km].round(1)} km away)"
    end

    if resolved_from[:destination_nearest_town] && !resolved_from[:destination_nearest_town][:error]
      dest_info = resolved_from[:destination_nearest_town]
      notes << "Destination '#{resolved_from[:original_destination]}' resolved to '#{dest_info[:nearest_town]}' (#{dest_info[:distance_km].round(1)} km away)"
    end

    notes.join("; ")
  end

  def generate_route_summary(results)
    return { total_segments: 0, total_distance_km: 0, total_duration_hours: 0, valid_segments: 0, invalid_segments: 0, average_distance_per_segment: 0, average_duration_per_segment: 0 } if results.empty?

    total_distance = results.sum { |r| r[:route][:total_distance_km] }
    total_duration = results.sum { |r| r[:route][:total_duration_hours] }
    valid_segments = results.count { |r| r[:validation] && r[:validation][:valid] }
    invalid_segments = results.count { |r| r[:validation] && !r[:validation][:valid] }
    resolved_segments = results.count { |r| r[:resolved_from] }

    {
      total_segments: results.length,
      total_distance_km: total_distance.round(1),
      total_duration_hours: total_duration.round(1),
      valid_segments: valid_segments,
      invalid_segments: invalid_segments,
      resolved_segments: resolved_segments,
      average_distance_per_segment: (total_distance / results.length).round(1),
      average_duration_per_segment: (total_duration / results.length).round(1)
    }
  end
end