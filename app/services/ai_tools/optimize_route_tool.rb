# frozen_string_literal: true

module AITools
  class OptimizeRouteTool < BaseTool
    def definition
      {
        type: 'function',
        function: {
          name: 'optimize_route',
          description: 'Automatically calculate and optimize a complete route with real-world distances and times. Validates all segments against user preferences and splits long segments into manageable parts.',
          parameters: {
            type: 'object',
            properties: {
              segments: {
                type: 'array',
                description: 'Array of route segments to calculate and optimize',
                items: {
                  type: 'object',
                  properties: {
                    origin: {
                      type: 'string',
                      description: 'Starting location (city, address, or coordinates)'
                    },
                    destination: {
                      type: 'string',
                      description: 'Ending location (city, address, or coordinates)'
                    },
                    waypoints: {
                      type: 'array',
                      description: 'Optional intermediate stops',
                      items: { type: 'string' }
                    }
                  },
                  required: ['origin', 'destination']
                }
              },
              user_preferences: {
                type: 'object',
                description: 'User driving preferences for validation (optional - will use trip data if not provided)',
                properties: {
                  max_daily_drive_h: {
                    type: 'number',
                    description: 'Maximum hours to drive in a single day'
                  },
                  max_daily_distance_km: {
                    type: 'number',
                    description: 'Maximum distance to drive in a single day (km)'
                  },
                  avoid: {
                    type: 'array',
                    description: 'Things to avoid (tolls, highways, ferries)',
                    items: { type: 'string' }
                  }
                }
              }
            },
            required: ['segments']
          }
        }
      }
    end

    def execute(args)
      segments = args['segments']
      user_preferences = args['user_preferences'] || {}

      if segments.blank? || !segments.is_a?(Array) || segments.empty?
        Rails.logger.error "No route segments provided to OptimizeRouteTool"
        return {
          success: false,
          error: "Cannot calculate route: No route segments provided. Please specify at least one segment with origin and destination."
        }
      end

      Rails.logger.info "Optimizing route for #{segments.length} segments"

      # Validate segments before processing
      invalid_segments = segments.select do |seg|
        origin = seg['origin'] || seg[:origin]
        destination = seg['destination'] || seg[:destination]
        origin.blank? || destination.blank?
      end

      if invalid_segments.any?
        Rails.logger.error "Found segments with empty origin or destination: #{invalid_segments}"
        return {
          success: false,
          error: "Cannot calculate route: Some segments have missing origin or destination. Please provide complete location information for all route segments."
        }
      end

      # Initialize the route optimization service
      optimization_service = RouteOptimizationService.new(@trip)

      # Calculate and optimize the complete route
      optimized_route = optimization_service.calculate_optimized_route(segments, user_preferences)

      # Format the response for the AI
      {
        success: true,
        route: optimized_route,
        summary: optimized_route[:summary],
        segments: optimized_route[:segments],
        warnings: optimized_route[:warnings],
        recommendations: generate_recommendations(optimized_route)
      }
    rescue => e
      Rails.logger.error "Route optimization error: #{e.message}"
      {
        success: false,
        error: "Failed to optimize route: #{e.message}"
      }
    end

    private

    def generate_recommendations(optimized_route)
      recommendations = []

      # Check for segments with issues
      invalid_segments = optimized_route[:segments].select { |seg| !seg[:valid] }

      if invalid_segments.any?
        recommendations << {
          type: 'invalid_segments',
          message: "Some segments still exceed your driving preferences. Consider adjusting your route or extending your trip duration.",
          segments: invalid_segments.map { |seg| "#{seg[:origin]} to #{seg[:destination]}" }
        }
      end

      # Check for overall trip intensity
      summary = optimized_route[:summary]
      # Check if the trip is too long
      if summary[:total_duration_hours] && summary[:total_duration_hours] > 56 # More than 7 days of driving
        recommendations << {
          type: 'trip_too_intensive',
          message: "This trip involves #{summary[:total_duration_hours].round(1)} hours of driving. Consider extending your trip duration or reducing destinations.",
          suggestion: "Consider adding more rest days or reducing the number of destinations."
        }
      end

      # Check for long individual segments
      long_segments = optimized_route[:segments].select { |seg| seg[:duration_hours] > 6 }
      if long_segments.any?
        recommendations << {
          type: 'long_segments',
          message: "Some segments are quite long. Consider adding rest days between these segments.",
          segments: long_segments.map { |seg| "#{seg[:origin]} to #{seg[:destination]} (#{seg[:duration_text]})" }
        }
      end

      recommendations
    end
  end
end