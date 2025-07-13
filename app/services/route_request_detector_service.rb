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

    # If explicit patterns found valid segments, use them
    if explicit_segments.any? && explicit_segments.all? { |seg| seg[:origin].present? && seg[:destination].present? }
      segments = explicit_segments
    else
      # Otherwise, try to extract destinations and build segments
      segments = extract_destinations_and_build_segments(message)
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

    # Pattern for "from X to Y, with a stop in Z" (more comprehensive)
    from_to_with_stop_patterns = [
      /from\s+([\w\sÀ-ÿ]+?)\s+to\s+([\w\sÀ-ÿ]+?),\s+with\s+a\s+stop\s+in\s+([\w\sÀ-ÿ]+?)(?:\.|,|\.|\s+I\s+|\s*$)/i,
      /from\s+([\w\sÀ-ÿ]+?)\s+to\s+([\w\sÀ-ÿ]+?),\s+stopping\s+in\s+([\w\sÀ-ÿ]+?)(?:\.|,|\.|\s+I\s+|\s*$)/i,
      /from\s+([\w\sÀ-ÿ]+?)\s+to\s+([\w\sÀ-ÿ]+?),\s+via\s+([\w\sÀ-ÿ]+?)(?:\.|,|\.|\s+I\s+|\s*$)/i,
    ]

    from_to_with_stop_patterns.each do |pattern|
      if match = message.match(pattern)
        origin = clean_location(match[1].strip)
        destination = clean_location(match[2].strip)
        stop = clean_location(match[3].strip)

        if origin.present? && destination.present? && stop.present?
          # Create two segments: origin -> stop, stop -> destination
          segments << {
            origin: origin,
            destination: stop,
            waypoints: [],
          }
          segments << {
            origin: stop,
            destination: destination,
            waypoints: [],
          }
          return segments # Return early if we found this pattern
        end
      end
    end

    # Pattern for "from X to Y" (both origin and destination)
    from_to_patterns = [
      /from\s+([^,\s]+(?:\s+[^,\s]+)*)\s+to\s+([^,\s]+(?:\s+[^,\s]+)*)/i,
      /driving\s+from\s+([^,\s]+(?:\s+[^,\s]+)*)\s+to\s+([^,\s]+(?:\s+[^,\s]+)*)/i,
      /route\s+from\s+([^,\s]+(?:\s+[^,\s]+)*)\s+to\s+([^,\s]+(?:\s+[^,\s]+)*)/i,
      /how\s+to\s+get\s+from\s+([^,\s]+(?:\s+[^,\s]+)*)\s+to\s+([^,\s]+(?:\s+[^,\s]+)*)/i,
    ]

    from_to_patterns.each do |pattern|
      match = message.match(pattern) # Use match instead of scan to avoid duplicates
      if match
        origin = clean_location(match[1])
        destination = clean_location(match[2])

        # Skip if either origin or destination contains date patterns
        next if origin&.match?(/\d+/) || destination&.match?(/\d+/)
        # Skip if either contains month names (likely dates)
        next if origin&.match?(/(?:January|February|March|April|May|June|July|August|September|October|November|December)/i) ||
                destination&.match?(/(?:January|February|March|April|May|June|July|August|September|October|November|December)/i)

        if origin.present? && destination.present?
          segments << {
            origin: origin,
            destination: destination,
            waypoints: [],
          }
          break # Exit after first match to avoid duplicates
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
          waypoints: [],
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
          waypoints: [],
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
          waypoints: [],
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
            waypoints: [],
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
    date_contexts = []

    # Look for date patterns with context
    # Pattern for dates with location context
    location_date_patterns = [
      # "reservation in [Location] from [Date] to [Date]" - dynamic location pattern
      /(reservation\s+in\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s+from\s+((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+(?:st|nd|rd|th)?)\s+to\s+((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+(?:st|nd|rd|th)?))/i,
      # "in Location from date to date" pattern
      /in\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\s+from\s+((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+(?:st|nd|rd|th)?)\s+to\s+((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+(?:st|nd|rd|th)?)\b/i,
    ]

    location_date_patterns.each do |pattern|
      matches = message.scan(pattern)
      matches.each do |match|
        location = match[1]
        start_date = match[2]
        end_date = match[3]

        date_contexts << {
          type: 'reservation',
          location: location,
          start_date: start_date,
          end_date: end_date,
          full_text: match[0],
        }

        dates << "#{start_date} to #{end_date}"
      end
    end

    # General date patterns
    general_date_patterns = [
      # "December 26th, 2025" pattern with optional year
      /\b((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+(?:st|nd|rd|th)?(?:,?\s+\d{4})?)\b/i,
      # "January 18th to February 15th" pattern
      /\b((?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+(?:st|nd|rd|th)?\s+to\s+(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+(?:st|nd|rd|th)?)\b/i,
      # "from January 18th to February 15th" pattern
      /(from\s+(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+(?:st|nd|rd|th)?\s+to\s+(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d+(?:st|nd|rd|th)?)\b/i,
    ]

    general_date_patterns.each do |pattern|
      matches = message.scan(pattern)
      matches.each do |match|
        date_str = match.is_a?(Array) ? match[0] : match
        dates << date_str.strip
      end
    end

    # Store contexts in instance variable for later use
    @date_contexts = date_contexts

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
      /want to visit\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)/i,
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

    # First, look for locations in "want to visit X, Y, Z" patterns
    visit_pattern = /want\s+to\s+visit\s+([^.]+?)(?:\.|(?:\s*We|\s*we)\s+|$)/i
    if match = message.match(visit_pattern)
      destinations_text = match[1]
      # Split by commas and 'and' - be more careful about splitting
      destination_parts = destinations_text.split(/,\s*(?:and\s+)?|\s+and\s+/)
      destination_parts.each do |part|
        cleaned = clean_location(part.strip)
        if cleaned.present? && !cleaned.match?(/^(a|an|the|my|our|some|few|at|on|in|during|only)$/i)
          locations << cleaned
        end
      end
    end

    # Look for capitalized location patterns (dynamic - no hardcoded cities)
    city_patterns = [
      /\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*(?:\s+(?:City|Town|Village|Park|National\s+Park))?)\b/,
    ]

    city_patterns.each do |pattern|
      matches = message.scan(pattern)
      matches.each do |match|
        location = match.is_a?(Array) ? match[0] : match
        cleaned_location = clean_location(location)
        locations << cleaned_location if cleaned_location.present?
      end
    end

    # Look for geographic features (dynamic patterns)
    geographic_patterns = [
      /\b(Mount\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\b/i,
      /\b(Monte\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\b/i,
      /\b(Lake\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\b/i,
      /\b(Parque\s+Nacional\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\b/i,
      /\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\s+(?:National\s+Park|Park|del\s+[A-Z][a-z]+))\b/i,
    ]

    geographic_patterns.each do |pattern|
      matches = message.scan(pattern)
      matches.each do |match|
        location = match.is_a?(Array) ? match[0] : match
        cleaned_location = clean_location(location)
        locations << cleaned_location if cleaned_location.present?
      end
    end

    # Remove duplicates and filter out common words and irrelevant phrases
    common_words = %w[the and or but in on at to from with by for of a an we want visit plan trip my wife I]
    irrelevant_phrases = [
      'trip for me', 'departing from', 'my wife and',
      'want to visit', 'we are going to drive', 'only during daytime',
      'do not plan segments', 'stops counting',
      'week', 'days', 'reservation', 'national parks', 'some days'
    ]
    
    # Filter out dates and time references (dynamic month detection)
    date_words = %w[january february march april may june july august september october november december]
    date_patterns = /\d+(?:st|nd|rd|th)?|\d{4}/

    locations = locations.reject do |loc|
      normalized = loc.downcase.strip
      common_words.include?(normalized) ||
      date_words.include?(normalized) ||
      irrelevant_phrases.any? { |phrase| normalized == phrase.downcase } ||
      loc.match?(date_patterns) || # Reject dates and years dynamically
      loc.length < 3 # Reject very short strings
    end

    # Deduplicate while preserving order
    seen = Set.new
    unique_locations = []

    locations.each do |loc|
      normalized = loc.downcase.strip
      unless seen.include?(normalized)
        seen.add(normalized)
        unique_locations << loc
      end
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

    # Extract driving time preferences - handle various patterns
    time_patterns = [
      /no\s+more\s+than\s+(\d+)\s*h(?:ours?)?/i,
      /(?:not|don't|do not).*(?:more than|exceed|over|greater than).*?(\d+)\s*h(?:ours?)?/i,
      /(?:max|maximum|up to|less than|under).*?(\d+)\s*h(?:ours?)?/i,
      /(\d+)\s*h(?:ours?)?.*?(?:max|maximum|limit)/i,
      /segments.*(?:last|take|be).*(?:more than|over).*?(\d+)\s*h(?:ours?)?/i,
    ]

    time_patterns.each do |pattern|
      if match = message.match(pattern)
        preferences[:max_daily_drive_h] = match[1].to_i
        break
      end
    end

    # Extract distance preferences - handle various patterns
    distance_patterns = [
      /(?:not|don't|do not).*(?:more than|exceed|over|greater than).*?(\d+)\s*km/i,
      /(?:max|maximum|up to|less than|under).*?(\d+)\s*km/i,
      /(\d+)\s*km.*?(?:max|maximum|limit)/i,
      /segments.*(?:last|be|cover).*(?:more than|over).*?(\d+)\s*km/i,
    ]

    distance_patterns.each do |pattern|
      if match = message.match(pattern)
        preferences[:max_daily_distance_km] = match[1].to_i
        break
      end
    end

    # Extract driving preferences
    if message.match?(/(?:only\s+)?(?:during\s+)?daytime/i) || message.match?(/daytime\s+only/i)
      preferences[:daytime_only] = true
    end

    # Extract avoid preferences
    avoid_items = []
    if message.match?(/avoid.*tolls/i) || message.match?(/no.*tolls/i)
      avoid_items << 'tolls'
    end
    if message.match?(/avoid.*highways/i) || message.match?(/no.*highways/i)
      avoid_items << 'highways'
    end
    if message.match?(/avoid.*ferries/i) || message.match?(/no.*ferries/i)
      avoid_items << 'ferries'
    end
    if message.match?(/avoid.*dirt\s*roads/i) || message.match?(/no.*dirt\s*roads/i)
      avoid_items << 'unpaved'
    end

    preferences[:avoid] = avoid_items if avoid_items.any?

    Rails.logger.info "Extracted preferences: #{preferences}"
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
          waypoints: segment['waypoints'] || [],
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
          waypoints: [],
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
      avoid: trip_data.dig('route_preferences', 'avoid') || [],
    }
  end

  private

  def clean_location(location)
    return nil if location.blank?

    # Basic cleaning - remove extra whitespace
    cleaned = location.strip

    # Return cleaned and titleized version - let Google Maps handle the geocoding
    cleaned.titleize
  end
end
