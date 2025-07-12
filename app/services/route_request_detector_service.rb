# frozen_string_literal: true

class RouteRequestDetectorService
  def initialize(trip)
    @trip = trip
  end

  # Main method to detect if a message is a route request
  def route_request?(message)
    return false if message.blank?

    message = message.downcase

    # Keywords that indicate a route request
    route_keywords = [
      'plan.*route', 'calculate.*route', 'driving.*route', 'road.*trip',
      'itinerary', 'route.*planning', 'driving.*from', 'drive.*to',
      'road.*trip', 'car.*trip', 'driving.*trip', 'route.*calculation',
      'visit', 'travel.*to', 'go.*to', 'trip.*to'
    ]

    route_keywords.any? { |keyword| message.match?(/#{keyword}/i) }
  end

  # Extract route segments from user message
  def extract_segments_from_message(message)
    return nil unless route_request?(message)

    # Common patterns for route extraction
    patterns = [
      # "from X to Y" pattern
      /from\s+([^,\s]+(?:\s+[^,\s]+)*)\s+to\s+([^,\s]+(?:\s+[^,\s]+)*)/i,
      # "driving from X to Y" pattern
      /driving\s+from\s+([^,\s]+(?:\s+[^,\s]+)*)\s+to\s+([^,\s]+(?:\s+[^,\s]+)*)/i,
      # "route from X to Y" pattern
      /route\s+from\s+([^,\s]+(?:\s+[^,\s]+)*)\s+to\s+([^,\s]+(?:\s+[^,\s]+)*)/i
    ]

    segments = []

    patterns.each do |pattern|
      matches = message.scan(pattern)
      matches.each do |match|
        origin = clean_location(match[0])
        destination = clean_location(match[1])

        segments << {
          origin: origin,
          destination: destination,
          waypoints: []
        }
      end
    end

    # If no direct "from X to Y" pattern, try to extract destinations from the message
    if segments.empty?
      segments = extract_destinations_from_text(message)
    end

    segments.any? ? segments : nil
  end

    # Extract destinations mentioned in the text and create segments
  def extract_destinations_from_text(message)
    # Common destination patterns
    segments = []

    # Look for city/country names (this is a simplified approach)
    # In a real implementation, you might use a geocoding service or NLP
    common_destinations = [
      'curitiba', 'porto alegre', 'uruguaiana', 'puerto madryn', 'ushuaia',
      'torres del paine', 'mount fitz roy', 'bariloche', 'mendoza',
      'buenos aires', 'santiago', 'montevideo', 'asuncion'
    ]

    message_lower = message.downcase
    found_destinations = common_destinations.select { |dest| message_lower.include?(dest) }

    # If we have multiple destinations, create segments
    if found_destinations.length >= 2
      (0...found_destinations.length - 1).each do |i|
        segments << {
          origin: found_destinations[i].titleize,
          destination: found_destinations[i + 1].titleize,
          waypoints: []
        }
      end
    end

    segments
  end

  # Build segments from trip data if available
  def build_segments_from_trip
    trip_data = @trip.trip_data || {}

    # Check if we have a current route
    if trip_data['current_route']&.dig('segments')&.any?
      return trip_data['current_route']['segments'].map do |segment|
        {
          origin: segment['origin'],
          destination: segment['destination'],
          waypoints: segment['waypoints'] || []
        }
      end
    end

    # If no current route, try to build from destinations mentioned in trip data
    destinations = extract_destinations_from_trip_data(trip_data)

    if destinations.length >= 2
      segments = []
      (0...destinations.length - 1).each do |i|
        segments << {
          origin: destinations[i],
          destination: destinations[i + 1],
          waypoints: []
        }
      end
      return segments
    end

    nil
  end

  # Extract destinations from trip data
  def extract_destinations_from_trip_data(trip_data)
    destinations = []

    # Check various fields where destinations might be mentioned
    if trip_data['must_do']&.any?
      destinations.concat(trip_data['must_do'])
    end

    if trip_data['destinations']&.any?
      destinations.concat(trip_data['destinations'])
    end

    # Remove duplicates and clean
    destinations.uniq.map { |dest| clean_location(dest) }
  end

  # Extract user preferences from trip data
  def extract_preferences_from_trip
    trip_data = @trip.trip_data || {}

    {
      max_daily_drive_h: trip_data.dig('route_preferences', 'max_daily_drive_h') || 8,
      max_daily_distance_km: trip_data.dig('route_preferences', 'max_daily_distance_km') || 800,
      avoid: trip_data.dig('route_preferences', 'avoid') || []
    }
  end

  private

  def clean_location(location)
    return nil if location.blank?

    # Basic cleaning - remove extra whitespace and capitalize
    location.strip.titleize
  end
end