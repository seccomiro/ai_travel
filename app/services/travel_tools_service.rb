# frozen_string_literal: true

module TravelToolsService
  def self.call_tool(tool_call, trip)
    tool_name = tool_call['function']['name']
    args = JSON.parse(tool_call['function']['arguments'])

    case tool_name
    when 'get_weather'
      get_weather(args)
    when 'search_accommodation'
      search_accommodation(args)
    when 'plan_route'
      plan_route(args)
    when 'modify_route'
      modify_route(args, trip)
    else
      { error: "Unknown tool: #{tool_name}" }
    end
  rescue JSON::ParserError
    { error: 'Invalid arguments for tool call' }
  end

  def self.get_weather(args)
    # Mock weather data
    {
      location: args['location'],
      temperature: "#{rand(15..30)}°C",
      condition: %w[Sunny Cloudy Rainy Windy].sample,
      note: 'This is mock weather data.',
    }
  end

  def self.search_accommodation(args)
    # Mock accommodation data
    {
      location: args['location'],
      options: [
        { name: 'Hotel Sunshine', price: '$150/night', rating: '4.5 stars' },
        { name: 'Cozy Inn', price: '$100/night', rating: '4.0 stars' },
      ],
      note: 'This is mock accommodation data.',
    }
  end

  def self.plan_route(args)
    {
      destinations: args['destinations'],
      transport_mode: args['transport_mode'] || 'driving',
    }
  end

  def self.modify_route(args, trip)
    current_destinations = trip.trip_data.dig('current_route', 'destinations') || []

    # Remove destinations
    if args['remove_destinations'].present?
      current_destinations.reject! { |dest| args['remove_destinations'].include?(dest) }
    end

    # Add destinations
    if args['add_destinations'].present?
      if args['add_before'].present?
        index = current_destinations.index(args['add_before']) || 0
        current_destinations.insert(index, *args['add_destinations'])
      elsif args['add_after'].present?
        index = current_destinations.index(args['add_after']) || current_destinations.length - 1
        current_destinations.insert(index + 1, *args['add_destinations'])
      else
        current_destinations.concat(args['add_destinations'])
      end
    end

    # Return the same structure as plan_route
    {
      destinations: current_destinations.uniq,
      transport_mode: trip.trip_data.dig('current_route', 'mode') || 'driving',
    }
  end
end
