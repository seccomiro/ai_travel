# frozen_string_literal: true

class GoogleDirectionsService
  include HTTParty

  def initialize
    @api_key = Rails.application.credentials.google_maps_api_key
    @base_url = 'https://maps.googleapis.com/maps/api/directions/json'
  end

  # Calculate route between two points
  def calculate_route(origin, destination, options = {})
    params = {
      origin: origin,
      destination: destination,
      key: @api_key,
      mode: 'driving',
      units: 'metric',
      avoid: options[:avoid] || [],
      waypoints: options[:waypoints] || [],
      optimize: options[:optimize] || false,
      alternatives: options[:alternatives] || false
    }

    response = HTTParty.get(@base_url, query: params)

    if response.success?
      parse_directions_response(response.parsed_response)
    else
      Rails.logger.error "Google Directions API error: #{response.code} - #{response.body}"
      { error: "Failed to calculate route: #{response.code}" }
    end
  rescue => e
    Rails.logger.error "Google Directions API exception: #{e.message}"
    { error: "Route calculation failed: #{e.message}" }
  end

  # Calculate multiple route segments for a trip
  def calculate_trip_segments(segments, options = {})
    results = []

    segments.each_with_index do |segment, index|
      Rails.logger.info "Calculating route #{index + 1}/#{segments.length}: #{segment[:origin]} to #{segment[:destination]}"

      result = calculate_route(
        segment[:origin],
        segment[:destination],
        options.merge(waypoints: segment[:waypoints])
      )

      if result[:error]
        results << { segment: segment, error: result[:error] }
      else
        results << { segment: segment, route: result }
      end

      # Rate limiting - Google allows 10 requests per second
      sleep(0.1) if index < segments.length - 1
    end

    results
  end

  # Validate if a route segment is realistic based on user preferences
  def validate_segment(route_data, user_preferences = {})
    max_daily_drive_h = user_preferences[:max_daily_drive_h] || 8
    max_daily_distance_km = user_preferences[:max_daily_distance_km] || 800

    return { valid: true } unless route_data[:legs]&.any?

    leg = route_data[:legs].first
    drive_hours = leg[:duration_hours]
    distance_km = leg[:distance_km]

    issues = []

    if drive_hours > max_daily_drive_h
      issues << "Drive time (#{drive_hours}h) exceeds maximum daily drive time (#{max_daily_drive_h}h)"
    end

    if distance_km > max_daily_distance_km
      issues << "Distance (#{distance_km}km) exceeds maximum daily distance (#{max_daily_distance_km}km)"
    end

    if issues.any?
      { valid: false, issues: issues, suggested_splits: suggest_route_splits(route_data, user_preferences) }
    else
      { valid: true }
    end
  end

  # Suggest how to split a long route into multiple days
  def suggest_route_splits(route_data, user_preferences = {})
    max_daily_drive_h = user_preferences[:max_daily_drive_h] || 8
    max_daily_distance_km = user_preferences[:max_daily_distance_km] || 800

    return [] unless route_data[:legs]&.any?

    leg = route_data[:legs].first
    total_hours = leg[:duration_hours]
    total_distance = leg[:distance_km]

    # Calculate how many days needed
    days_needed = [total_hours / max_daily_drive_h, total_distance / max_daily_distance_km].max.ceil

    if days_needed <= 1
      return []
    end

    # Find intermediate points along the route
    waypoints = find_intermediate_stops(route_data, days_needed)

    waypoints.map.with_index do |waypoint, index|
      {
        day: index + 1,
        stop_location: waypoint[:location],
        distance_from_origin: waypoint[:distance_from_origin],
        hours_from_origin: waypoint[:hours_from_origin]
      }
    end
  end

  private

  def parse_directions_response(response)
    return { error: 'No routes found' } if response['routes'].blank?

    route = response['routes'].first
    legs = route['legs']

    {
      status: response['status'],
      route_id: SecureRandom.uuid,
      legs: legs.map { |leg| parse_leg(leg) },
      total_distance_km: legs.sum { |leg| leg['distance']['value'] } / 1000.0,
      total_duration_hours: legs.sum { |leg| leg['duration']['value'] } / 3600.0,
      polyline: route['overview_polyline']['points'],
      bounds: route['bounds'],
      warnings: response['geocoded_waypoints']&.select { |wp| wp['geocoder_status'] != 'OK' }&.map { |wp| wp['geocoder_status'] } || []
    }
  end

  def parse_leg(leg)
    {
      origin: leg['start_address'],
      destination: leg['end_address'],
      distance_km: leg['distance']['value'] / 1000.0,
      distance_text: leg['distance']['text'],
      duration_hours: leg['duration']['value'] / 3600.0,
      duration_text: leg['duration']['text'],
      steps: leg['steps']&.map { |step| parse_step(step) } || []
    }
  end

  def parse_step(step)
    {
      instruction: step['html_instructions'],
      distance_km: step['distance']['value'] / 1000.0,
      duration_hours: step['duration']['value'] / 3600.0,
      travel_mode: step['travel_mode'],
      polyline: step['polyline']['points']
    }
  end

  def find_intermediate_stops(route_data, days_needed)
    return [] unless route_data[:legs]&.any?

    leg = route_data[:legs].first
    total_distance = leg[:distance_km]
    total_hours = leg[:duration_hours]

    # Find major cities/towns along the route
    # This is a simplified approach - in practice, you'd want to use a geocoding service
    # to find actual towns along the route
    waypoints = []

    (1...days_needed).each do |day|
      progress_ratio = day.to_f / days_needed
      estimated_distance = total_distance * progress_ratio
      estimated_hours = total_hours * progress_ratio

      # Find a reasonable stopping point (this would need geocoding integration)
      waypoints << {
        location: "Intermediate stop #{day}",
        distance_from_origin: estimated_distance,
        hours_from_origin: estimated_hours
      }
    end

    waypoints
  end
end