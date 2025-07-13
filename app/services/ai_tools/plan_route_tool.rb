# frozen_string_literal: true

module AITools
  class PlanRouteTool < BaseTool
    def definition
      {
        type: 'function',
        function: {
          name: 'plan_route',
          description: 'Plan a complete route from an origin to multiple destinations. This tool handles the initial route planning and automatically optimizes segments based on user constraints.',
          parameters: {
            type: 'object',
            properties: {
              origin: {
                type: 'string',
                description: 'Starting location (city, address, or coordinates)'
              },
              destinations: {
                type: 'array',
                items: {
                  type: 'string',
                },
                description: "Array of destination names in order as provided by user.",
              },
              transport_mode: {
                type: 'string',
                enum: ['driving', 'walking', 'bicycling', 'transit'],
                description: "Preferred mode of transportation. Defaults to 'driving'.",
              },
              constraints: {
                type: 'object',
                description: 'Travel constraints and preferences',
                properties: {
                  max_daily_drive_hours: {
                    type: 'number',
                    description: 'Maximum hours to drive in a single day'
                  },
                  max_daily_distance_km: {
                    type: 'number',
                    description: 'Maximum distance to drive in a single day (km)'
                  },
                  daytime_only: {
                    type: 'boolean',
                    description: 'Whether to drive only during daytime'
                  },
                  avoid: {
                    type: 'array',
                    description: 'Things to avoid (tolls, highways, ferries)',
                    items: { type: 'string' }
                  }
                }
              },
              date_constraints: {
                type: 'array',
                description: 'Fixed dates or reservations that must be respected',
                items: {
                  type: 'object',
                  properties: {
                    location: {
                      type: 'string',
                      description: 'Location for the constraint'
                    },
                    start_date: {
                      type: 'string',
                      description: 'Start date (ISO format)'
                    },
                    end_date: {
                      type: 'string',
                      description: 'End date (ISO format)'
                    },
                    description: {
                      type: 'string',
                      description: 'Description of the constraint'
                    }
                  }
                }
              }
            },
            required: ['origin', 'destinations'],
          },
        },
      }
    end

    def execute(args)
      origin = args['origin']
      destinations = args['destinations']
      constraints = args['constraints'] || {}
      date_constraints = args['date_constraints'] || []

      # Validate inputs
      return { success: false, error: 'Origin is required' } if origin.blank?
      return { success: false, error: 'At least one destination is required' } if destinations.blank?

      Rails.logger.info "Planning route from #{origin} to #{destinations.join(' -> ')}"

      # Build segments from origin to destinations
      segments = build_route_segments(origin, destinations)

      # Extract user preferences
      user_preferences = {
        max_daily_drive_h: constraints['max_daily_drive_hours'],
        max_daily_distance_km: constraints['max_daily_distance_km'],
        avoid: constraints['avoid'] || [],
        daytime_only: constraints['daytime_only']
      }

      # Update trip data with constraints and destinations
      update_trip_data(origin, destinations, user_preferences, date_constraints)

      # Use the optimize route tool to calculate the actual route
      optimize_tool = OptimizeRouteTool.new(@trip)
      result = optimize_tool.execute({
        'segments' => segments,
        'user_preferences' => user_preferences
      })

      # Add date constraints to the result
      if result[:success] && date_constraints.any?
        result[:date_constraints] = date_constraints
        result[:notes] = generate_date_constraint_notes(date_constraints)
      end

      result
    rescue => e
      Rails.logger.error "Route planning error: #{e.message}"
      {
        success: false,
        error: "Failed to plan route: #{e.message}"
      }
    end

    private

    def build_route_segments(origin, destinations)
      segments = []
      current_origin = origin

      destinations.each do |destination|
        segments << {
          'origin' => current_origin,
          'destination' => destination,
          'waypoints' => []
        }
        current_origin = destination
      end

      segments
    end

    def update_trip_data(origin, destinations, preferences, date_constraints)
      trip_data = @trip.trip_data || {}

      # Update trip origin and destination
      @trip.origin = origin if @trip.origin.blank?
      @trip.destination = destinations.last if @trip.destination.blank?

      # Update route preferences
      trip_data['route_preferences'] = preferences.compact

      # Update destinations list
      all_destinations = [origin] + destinations
      trip_data['destinations'] = all_destinations

      # Update date constraints
      if date_constraints.any?
        trip_data['timing_constraints'] = date_constraints
      end

      # Save updates
      @trip.update(trip_data: trip_data)
      @trip.save if @trip.changed?
    end

    def generate_date_constraint_notes(date_constraints)
      notes = []

      date_constraints.each do |constraint|
        if constraint['start_date'] && constraint['end_date']
          notes << "Must be in #{constraint['location']} from #{constraint['start_date']} to #{constraint['end_date']}"
        elsif constraint['start_date']
          notes << "Must be in #{constraint['location']} on #{constraint['start_date']}"
        end
      end

      notes
    end
  end
end
