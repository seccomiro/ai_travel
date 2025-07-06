class TravelToolsService
  def self.call_tool(tool_name, arguments)
    case tool_name
    when 'get_weather'
      get_weather(arguments['location'])
    when 'search_accommodation'
      search_accommodation(arguments)
    when 'plan_route'
      plan_route(arguments)
    else
      { error: "Unknown tool: #{tool_name}" }
    end
  end

  private

  def self.get_weather(location)
    # TODO: Integrate with real weather API (OpenWeatherMap, etc.)
    # For now, return mock data
    {
      location: location,
      temperature: rand(15..30),
      condition: ['Sunny', 'Cloudy', 'Rainy', 'Partly Cloudy'].sample,
      humidity: rand(40..80),
      wind_speed: rand(5..25),
      note: 'This is mock weather data. Integrate with a real weather API for production.'
    }
  end

  def self.search_accommodation(args)
    location = args['location']
    check_in = args['check_in']
    check_out = args['check_out']
    guests = args['guests'] || 2

    # TODO: Integrate with real accommodation APIs (Booking.com, Airbnb, etc.)
    # For now, return mock data
    {
      location: location,
      check_in: check_in,
      check_out: check_out,
      guests: guests,
      options: [
        {
          name: "Grand Hotel #{location.split(',').first}",
          type: 'Hotel',
          price_per_night: rand(100..300),
          rating: rand(3.5..5.0).round(1),
          amenities: ['WiFi', 'Pool', 'Restaurant', 'Spa']
        },
        {
          name: "Cozy #{location.split(',').first} Inn",
          type: 'Hotel',
          price_per_night: rand(80..150),
          rating: rand(3.0..4.5).round(1),
          amenities: ['WiFi', 'Breakfast', 'Parking']
        },
        {
          name: "#{location.split(',').first} Central Apartment",
          type: 'Apartment',
          price_per_night: rand(120..250),
          rating: rand(4.0..5.0).round(1),
          amenities: ['WiFi', 'Kitchen', 'Washing Machine', 'Balcony']
        }
      ],
      note: 'This is mock accommodation data. Integrate with real booking APIs for production.'
    }
  end

  def self.plan_route(args)
    destinations = args['destinations']
    transport_mode = args['transport_mode'] || 'car'

    # TODO: Integrate with real routing APIs (Google Maps, etc.)
    # For now, return mock data
    {
      destinations: destinations,
      transport_mode: transport_mode,
      route: destinations.each_cons(2).map.with_index do |(from, to), index|
        {
          segment: index + 1,
          from: from,
          to: to,
          distance: rand(50..500),
          duration: rand(1..8),
          transport: transport_mode,
          estimated_cost: case transport_mode
                          when 'car'
                           rand(20..100)
                          when 'train'
                           rand(30..150)
                          when 'plane'
                           rand(100..500)
                          when 'bus'
                           rand(15..80)
                          end
        }
      end,
      total_distance: rand(200..2000),
      total_duration: rand(5..24),
      total_cost: rand(100..800),
      note: 'This is mock routing data. Integrate with Google Maps or similar for production.'
    }
  end
end
