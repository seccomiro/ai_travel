# frozen_string_literal: true

class GoogleGeocodingService
  include HTTParty

  def initialize
    @api_key = Rails.application.credentials.google_maps_api_key
    @base_url = 'https://maps.googleapis.com/maps/api/geocode/json'
  end

  # Geocode a location to get coordinates
  def geocode_location(location)
    return nil if location.blank?

    Rails.logger.info "Geocoding location: #{location}"

    params = {
      address: location,
      key: @api_key
    }

    response = HTTParty.get(@base_url, query: params)

    if response.success?
      parsed_response = response.parsed_response

      # Check for API key restrictions
      if parsed_response['status'] == 'REQUEST_DENIED'
        error_message = parsed_response['error_message'] || 'API request denied'
        Rails.logger.error "Google Geocoding API key restriction: #{error_message}"
        return { error: "Google Maps API key has restrictions. Please configure the API key to allow server-side requests." }
      end

      # Check for other API errors
      if parsed_response['status'] != 'OK'
        error_message = parsed_response['error_message'] || "API returned status: #{parsed_response['status']}"
        Rails.logger.error "Google Geocoding API error: #{error_message}"
        return { error: "Google Maps API error: #{error_message}" }
      end

      parse_geocoding_response(parsed_response, location)
    else
      Rails.logger.error "Google Geocoding API HTTP error: #{response.code} - #{response.body}"
      { error: "Failed to geocode location: HTTP #{response.code}" }
    end
  rescue => e
    Rails.logger.error "Google Geocoding API exception: #{e.message}"
    { error: "Geocoding failed: #{e.message}" }
  end

  # Find the nearest town for a location that might be a geographic feature
  def find_nearest_town(location)
    return nil if location.blank?

    Rails.logger.info "Finding nearest town for: #{location}"

    # First, try to geocode the location directly
    geocode_result = geocode_location(location)

    if geocode_result[:error]
      Rails.logger.warn "Could not geocode #{location}: #{geocode_result[:error]}"
      return { error: geocode_result[:error] }
    end

    if geocode_result[:coordinates]
      # If we got coordinates, try to find the nearest town using reverse geocoding
      nearest_town = find_nearest_town_from_coordinates(geocode_result[:coordinates])

      if nearest_town[:error]
        return nearest_town
      end

      return {
        original_location: location,
        nearest_town: nearest_town[:town_name],
        coordinates: geocode_result[:coordinates],
        distance_km: nearest_town[:distance_km],
        confidence: nearest_town[:confidence]
      }
    end

    { error: "Could not find coordinates for location: #{location}" }
  end

  # Reverse geocode coordinates to find the nearest town
  def find_nearest_town_from_coordinates(coordinates)
    lat, lng = coordinates

    Rails.logger.info "Finding nearest town for coordinates: #{lat}, #{lng}"

    params = {
      latlng: "#{lat},#{lng}",
      key: @api_key,
      result_type: 'locality|administrative_area_level_1|administrative_area_level_2'
    }

    response = HTTParty.get(@base_url, query: params)

    if response.success?
      parsed_response = response.parsed_response

      if parsed_response['status'] == 'REQUEST_DENIED'
        error_message = parsed_response['error_message'] || 'API request denied'
        Rails.logger.error "Google Reverse Geocoding API key restriction: #{error_message}"
        return { error: "Google Maps API key has restrictions." }
      end

      if parsed_response['status'] != 'OK'
        error_message = parsed_response['error_message'] || "API returned status: #{parsed_response['status']}"
        Rails.logger.error "Google Reverse Geocoding API error: #{error_message}"
        return { error: "Google Maps API error: #{error_message}" }
      end

      parse_reverse_geocoding_response(parsed_response, coordinates)
    else
      Rails.logger.error "Google Reverse Geocoding API HTTP error: #{response.code} - #{response.body}"
      { error: "Failed to reverse geocode: HTTP #{response.code}" }
    end
  rescue => e
    Rails.logger.error "Google Reverse Geocoding API exception: #{e.message}"
    { error: "Reverse geocoding failed: #{e.message}" }
  end

  private

  def parse_geocoding_response(response, original_location)
    results = response['results'] || []

    if results.empty?
      Rails.logger.warn "No geocoding results found for: #{original_location}"
      return { error: "No results found for location: #{original_location}" }
    end

    # Get the first (most relevant) result
    result = results.first
    geometry = result['geometry'] || {}
    location = geometry['location'] || {}

    if location['lat'].blank? || location['lng'].blank?
      Rails.logger.warn "No coordinates found in geocoding result for: #{original_location}"
      return { error: "No coordinates found for location: #{original_location}" }
    end

    coordinates = [location['lat'].to_f, location['lng'].to_f]
    formatted_address = result['formatted_address']

    Rails.logger.info "Geocoded #{original_location} to #{formatted_address} at #{coordinates}"

    {
      coordinates: coordinates,
      formatted_address: formatted_address,
      location_types: result['types'] || [],
      place_id: result['place_id']
    }
  end

  def parse_reverse_geocoding_response(response, original_coordinates)
    results = response['results'] || []

    if results.empty?
      Rails.logger.warn "No reverse geocoding results found for coordinates: #{original_coordinates}"
      return { error: "No results found for coordinates: #{original_coordinates}" }
    end

    # Look for the most appropriate town name
    town_name = nil
    confidence = 'low'

    results.each do |result|
      types = result['types'] || []
      address_components = result['address_components'] || []

      # Prefer locality (city/town) over administrative areas
      if types.include?('locality')
        town_name = result['formatted_address']
        confidence = 'high'
        break
      elsif types.include?('administrative_area_level_1') && town_name.nil?
        # Use state/province as fallback
        town_name = result['formatted_address']
        confidence = 'medium'
      elsif types.include?('administrative_area_level_2') && town_name.nil?
        # Use county/district as fallback
        town_name = result['formatted_address']
        confidence = 'low'
      end
    end

    if town_name.nil?
      # Use the first result as fallback
      town_name = results.first['formatted_address']
      confidence = 'low'
    end

    # Calculate distance from original coordinates
    result_coordinates = [
      results.first['geometry']['location']['lat'].to_f,
      results.first['geometry']['location']['lng'].to_f
    ]
    distance_km = calculate_distance(original_coordinates, result_coordinates)

    Rails.logger.info "Found nearest town: #{town_name} (confidence: #{confidence}, distance: #{distance_km.round(1)} km)"

    {
      town_name: town_name,
      confidence: confidence,
      distance_km: distance_km,
      coordinates: result_coordinates
    }
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
end