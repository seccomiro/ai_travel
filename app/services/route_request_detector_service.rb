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
      'visit', 'travel.*to', 'go.*to', 'trip.*to', 'how.*to.*get.*to',
      'route.*from', 'directions.*to', 'way.*to', 'path.*to', 'plan.*trip',
      # Breakdown and optimization keywords
      'break.*down.*segments', 'split.*route', 'break.*down.*route',
      'optimize.*route', 'improve.*route', 'fix.*route', 'adjust.*route',
      'break.*segments', 'split.*segments', 'divide.*route', 'segment.*route',
      'make.*route.*manageable', 'reduce.*segments', 'shorter.*segments',
      'daily.*driving', 'manageable.*segments', 'split.*long.*segments'
    ]

    route_keywords.any? { |keyword| message.match?(/#{keyword}/i) }
  end

  # Extract segments from message
  def extract_segments_from_message(message)
    return nil unless route_request?(message)

    # First, try to extract explicit "from X to Y" patterns
    explicit_segments = extract_explicit_route_patterns(message)

    # Try to extract destinations and build segments
    build_segments = extract_destinations_and_build_segments(message)

    # Choose the better result - prefer build_segments if it has more complete segments
    segments = if build_segments.length > explicit_segments.length
                 build_segments
               elsif explicit_segments.any? && explicit_segments.all? { |seg| seg[:origin].present? && seg[:destination].present? }
                 explicit_segments
               else
                 build_segments
               end

    # If we found segments, update the trip with the extracted information
    if segments.any?
      # Extract dates for additional context
      dates = extract_dates_from_message(message)
      locations = extract_all_locations(message)
      date_analysis = analyze_dates_for_route(dates, locations)

      update_trip_with_extracted_info(segments, message, date_analysis)
    end

    segments.any? ? segments : nil
  end

  # Extract explicit route patterns like "from X to Y"
  def extract_explicit_route_patterns(message)
    segments = []

    # Pattern for "from X to Y" (both origin and destination)
    from_to_patterns = [
      /from\s+([^,\s]+(?:\s+[^,\s]+)*)\s+to\s+([^,\s]+(?:\s+[^,\s]+)*)/i,
      /driving\s+from\s+([^,\s]+(?:\s+[^,\s]+)*)\s+to\s+([^,\s]+(?:\s+[^,\s]+)*)/i,
      /route\s+from\s+([^,\s]+(?:\s+[^,\s]+)*)\s+to\s+([^,\s]+(?:\s+[^,\s]+)*)/i,
      /how\s+to\s+get\s+from\s+([^,\s]+(?:\s+[^,\s]+)*)\s+to\s+([^,\s]+(?:\s+[^,\s]+)*)/i
    ]

    from_to_patterns.each do |pattern|
      matches = message.scan(pattern)
      matches.each do |match|
        origin = clean_location(match[0])
        destination = clean_location(match[1])

        # Skip if either origin or destination contains date patterns
        next if origin&.match?(/\d+/) || destination&.match?(/\d+/)
        # Skip if either contains month names (likely dates)
        next if origin&.match?(/(?:January|February|March|April|May|June|July|August|September|October|November|December)/i) ||
                destination&.match?(/(?:January|February|March|April|May|June|July|August|September|October|November|December)/i)

        if origin.present? && destination.present?
          segments << {
            origin: origin,
            destination: destination,
            waypoints: []
          }
        end
      end
    end

    # Pattern for "departing from X" (only origin)
    departing_pattern = /departing\s+from\s+([^,\s]+(?:\s+[^,\s]+)*)/i
    departing_matches = message.scan(departing_pattern)
    departing_matches.each do |match|
      origin = clean_location(match[0])
      # Skip if origin contains date patterns
      next if origin&.match?(/\d+/) || origin&.match?(/(?:January|February|March|April|May|June|July|August|September|October|November|December)/i)

      if origin.present?
        # For departing patterns, we'll let the destination extraction handle the rest
        segments << {
          origin: origin,
          destination: nil, # Will be filled by destination extraction
          waypoints: []
        }
      end
    end

    segments
  end

  # Extract destinations from text and build segments
  def extract_destinations_and_build_segments(message)
    # Extract all potential locations from the message
    locations = extract_all_locations(message)
    # Extract dates from the message
    dates = extract_dates_from_message(message)

    return [] if locations.empty?

    # Try to identify the origin from the message
    origin = extract_origin_from_message(message)

    # If we have an origin and multiple destinations, create a route
    if origin.present? && locations.length >= 1
      segments = []
      current_origin = origin

      locations.each do |destination|
        segments << {
          origin: current_origin,
          destination: destination,
          waypoints: []
        }
        current_origin = destination
      end

      return segments
    end

    # If we have multiple locations but no clear origin, create segments between them
    if locations.length >= 2
      segments = []
      (0...locations.length - 1).each do |i|
        segments << {
          origin: locations[i],
          destination: locations[i + 1],
          waypoints: []
        }
      end
      return segments
    end

    # If we only have one location, it might be the origin
    # We need to look for destinations in the message
    if locations.length == 1
      # Try to extract destinations from the message
      destinations = extract_destinations_from_message(message)
      if destinations.any?
        segments = []
        origin = locations.first
        destinations.each do |dest|
          segments << {
            origin: origin,
            destination: dest,
            waypoints: []
          }
        end
        return segments
      end
    end

    []
  end

  # Extract origin from message
  def extract_origin_from_message(message)
    # Look for "departing from X" pattern
    departing_pattern = /departing\s+from\s+([^,\s]+(?:\s+[^,\s]+)*)/i
    match = message.match(departing_pattern)
    if match
      origin = clean_location(match[1])
      return origin if origin.present?
    end

    # Look for "from X" pattern
    from_pattern = /from\s+([^,\s]+(?:\s+[A-Z][a-z]+)*)/i
    match = message.match(from_pattern)
    if match
      origin = clean_location(match[1])
      return origin if origin.present?
    end

    nil
  end

  # Extract dates from message text
  def extract_dates_from_message(message)
    dates = []

    # Look for date patterns
    date_patterns = [
      # "December 26th, 2025" pattern
      /\b(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+(?:st|nd|rd|th)?,?\s+\d{4}\b/i,
      # "January 18th to February 15th" pattern
      /\b(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+(?:st|nd|rd|th)?\s+to\s+(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+(?:st|nd|rd|th)?\b/i,
      # "from January 18th to February 15th" pattern
      /from\s+(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+(?:st|nd|rd|th)?\s+to\s+(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+(?:st|nd|rd|th)?\b/i
    ]

    date_patterns.each do |pattern|
      matches = message.scan(pattern)
      matches.each do |match|
        dates << match.strip
      end
    end

    dates.uniq
  end

  # Analyze dates and infer missing dates for route planning
  def analyze_dates_for_route(dates, locations)
    return {} if dates.empty?

    date_info = {}

    # Parse the dates
    parsed_dates = dates.map do |date_str|
      parse_date_range(date_str)
    end.compact

    # If we have multiple date ranges, try to associate them with locations
    if parsed_dates.length > 1 && locations.length > 1
      # Try to match dates with locations based on context
      parsed_dates.each_with_index do |date_range, index|
        if index < locations.length
          date_info[locations[index]] = date_range
        end
      end
    elsif parsed_dates.length == 1
      # Single date range - might be for the entire trip
      date_info[:trip_duration] = parsed_dates.first
    end

    date_info
  end

  # Parse a date range string
  def parse_date_range(date_str)
    # Handle "January 18th to February 15th" format
    if date_str.match?(/to/i)
      parts = date_str.split(/\s+to\s+/i)
      if parts.length == 2
        start_date = parse_single_date(parts[0])
        end_date = parse_single_date(parts[1])
        return { start: start_date, end: end_date } if start_date && end_date
      end
    else
      # Single date
      date = parse_single_date(date_str)
      return { start: date, end: date } if date
    end

    nil
  end

  # Parse a single date string
  def parse_single_date(date_str)
    # Remove ordinal suffixes and clean up
    cleaned = date_str.gsub(/(\d+)(st|nd|rd|th)/, '\1').strip

    # Try to parse with Date.parse
    begin
      Date.parse(cleaned)
    rescue ArgumentError
      nil
    end
  end

  # Extract destinations from message text
  def extract_destinations_from_message(message)
    destinations = []

    # Look for "visit", "go to", "travel to" patterns
    visit_patterns = [
      /(?:visit|go to|travel to|see)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)/i,
      /want to visit\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)/i
    ]

    visit_patterns.each do |pattern|
      matches = message.scan(pattern)
      matches.each do |match|
        destination = clean_location(match[0])
        destinations << destination if destination.present?
      end
    end

    # Also look for specific destination lists
    if message.match?(/visit\s+(.+?)(?:\.|,|and|or)/i)
      destination_text = message.match(/visit\s+(.+?)(?:\.|,|and|or)/i)[1]
      # Split by common separators and clean each destination
      destination_text.split(/[,and]/).each do |dest|
        cleaned = clean_location(dest.strip)
        destinations << cleaned if cleaned.present?
      end
    end

    destinations.uniq
  end

  # Extract all locations from text using improved patterns
  def extract_all_locations(message)
    locations = []

    # Look for city names with country suffixes
    city_country_pattern = /\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*),\s*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\b/i
    matches = message.scan(city_country_pattern)
    matches.each do |match|
      location = match.compact.join(', ')
      cleaned_location = clean_location(location)
      locations << cleaned_location if cleaned_location.present?
    end

    # Look for specific geographic features with proper cleaning
    geographic_patterns = [
      /\bTorres\s+del\s+Paine\b/i,
      /\bMount\s+Fitz\s+Roy\b/i,
      /\b(?:Mount|Monte)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\b/i
    ]

    geographic_patterns.each do |pattern|
      matches = message.scan(pattern)
      matches.each do |match|
        if match.is_a?(Array)
          location = match.compact.join(' ')
        else
          location = match
        end
        cleaned_location = clean_location(location)
        locations << cleaned_location if cleaned_location.present?
      end
    end

    # Remove duplicates and filter out common words and irrelevant phrases
    common_words = %w[the and or but in on at to from with by for of a an we want visit plan trip]
    irrelevant_phrases = [
      'trip for me', 'departing from', 'my wife and',
      'want to visit', 'we are going to drive', 'only during daytime',
      'do not plan segments that would last more than', 'stops counting',
      'week', 'days', 'reservation'
    ]

    locations = locations.reject do |loc|
      common_words.include?(loc.downcase) ||
      irrelevant_phrases.any? { |phrase| loc.downcase.include?(phrase.downcase) } ||
      # Reject compound phrases that contain multiple locations
      loc.include?(',') && loc.split(',').length > 2
    end

    # Remove duplicates and sort by appearance in text
    unique_locations = []
    locations.each do |loc|
      # Skip if this location is already included in another location
      next if unique_locations.any? { |existing| existing.downcase.include?(loc.downcase) || loc.downcase.include?(existing.downcase) }
      # Skip if this location is a subset of another location
      next if unique_locations.any? { |existing| existing.downcase != loc.downcase && (existing.downcase.include?(loc.downcase) || loc.downcase.include?(existing.downcase)) }
      unique_locations << loc
    end

    unique_locations
  end

  # Update trip with extracted information
  def update_trip_with_extracted_info(segments, message, date_analysis)
    return if segments.empty?

    # Extract origin and destination from first and last segments
    origin = segments.first[:origin]
    destination = segments.last[:destination]

    # Extract user preferences from the message
    preferences = extract_preferences_from_message(message)

    # Update trip fields
    updates = {}
    updates[:origin] = origin if origin.present? && @trip.origin.blank?
    updates[:destination] = destination if destination.present? && @trip.destination.blank?

    # Update trip data with preferences and destinations
    trip_data = @trip.trip_data || {}

    # Add destinations to trip data
    all_destinations = segments.map { |seg| [seg[:origin], seg[:destination]] }.flatten.uniq.compact
    trip_data['destinations'] = all_destinations if all_destinations.any?

    # Add route preferences
    if preferences.any?
      trip_data['route_preferences'] = preferences
    end

    # Add date analysis to trip data
    trip_data['date_analysis'] = date_analysis if date_analysis.any?

    # Save updates
    @trip.update(updates) if updates.any?
    @trip.update(trip_data: trip_data) if trip_data != @trip.trip_data
  end

  # Extract user preferences from message
  def extract_preferences_from_message(message)
    preferences = {}

    # Extract driving time preferences
    if message.match?(/max.*(\d+)\s*h/i)
      preferences[:max_daily_drive_h] = message.match(/max.*(\d+)\s*h/i)[1].to_i
    end

    # Extract distance preferences
    if message.match?(/max.*(\d+)\s*km/i)
      preferences[:max_daily_distance_km] = message.match(/max.*(\d+)\s*km/i)[1].to_i
    end

    # Extract driving preferences
    if message.match?(/daytime/i)
      preferences[:daytime_only] = true
    end

    preferences
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
      max_daily_drive_h: trip_data.dig('route_preferences', 'max_daily_drive_h'),
      max_daily_distance_km: trip_data.dig('route_preferences', 'max_daily_distance_km'),
      avoid: trip_data.dig('route_preferences', 'avoid') || []
    }
  end

  private

  def clean_location(location)
    return nil if location.blank?

    # Basic cleaning - remove extra whitespace and capitalize
    cleaned = location.strip.titleize

    # Return the cleaned location without hardcoded mappings
    # Let the user's original location names be used as-is
    cleaned
  end
end