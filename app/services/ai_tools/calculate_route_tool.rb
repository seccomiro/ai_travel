# frozen_string_literal: true

module AITools
  class CalculateRouteTool < BaseTool
    def definition
      {
        type: 'function',
        function: {
          name: 'calculate_route',
          description: 'Calculate accurate driving routes using Google Directions API. Validates routes against user preferences and suggests splits for long segments.',
          parameters: {
            type: 'object',
            properties: {
              segments: {
                type: 'array',
                description: 'Array of route segments to calculate',
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
                description: 'User driving preferences for validation',
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

      Rails.logger.info "Calculating routes for #{segments.length} segments"

      # Initialize Google Directions service
      directions_service = GoogleDirectionsService.new

      # Calculate all route segments
      route_results = directions_service.calculate_trip_segments(segments, user_preferences)

      # Validate each segment against user preferences
      validated_results = route_results.map do |result|
        if result[:error]
          result
        else
          validation = directions_service.validate_segment(result[:route], user_preferences)
          result.merge(validation: validation)
        end
      end

      # Format the response
      {
        success: true,
        segments: validated_results.map { |result| format_segment_result(result) },
        summary: generate_summary(validated_results),
        recommendations: generate_recommendations(validated_results, user_preferences)
      }
    rescue => e
      Rails.logger.error "Route calculation error: #{e.message}"
      {
        success: false,
        error: "Failed to calculate routes: #{e.message}"
      }
    end

    private

    def format_segment_result(result)
      if result[:error]
        {
          origin: result[:segment][:origin],
          destination: result[:segment][:destination],
          error: result[:error]
        }
      else
        route = result[:route]
        validation = result[:validation]

        {
          origin: route[:legs].first[:origin],
          destination: route[:legs].first[:destination],
          distance_km: route[:legs].first[:distance_km],
          duration_hours: route[:legs].first[:duration_hours],
          distance_text: route[:legs].first[:distance_text],
          duration_text: route[:legs].first[:duration_text],
          valid: validation[:valid],
          issues: validation[:issues] || [],
          suggested_splits: validation[:suggested_splits] || [],
          route_id: route[:route_id]
        }
      end
    end

    def generate_summary(results)
      successful_results = results.reject { |r| r[:error] }

      return { total_segments: 0, total_distance: 0, total_duration: 0 } if successful_results.empty?

      total_distance = successful_results.sum { |r| r[:route][:total_distance_km] }
      total_duration = successful_results.sum { |r| r[:route][:total_duration_hours] }
      invalid_segments = successful_results.count { |r| !r[:validation][:valid] }

      {
        total_segments: successful_results.length,
        total_distance_km: total_distance.round(1),
        total_duration_hours: total_duration.round(1),
        invalid_segments: invalid_segments,
        average_distance_per_segment: (total_distance / successful_results.length).round(1),
        average_duration_per_segment: (total_duration / successful_results.length).round(1)
      }
    end

    def generate_recommendations(results, user_preferences)
      recommendations = []

      # Check for segments that exceed user preferences
      results.each do |result|
        next if result[:error]

        validation = result[:validation]
        next if validation[:valid]

        segment = result[:segment]
        route = result[:route]

        recommendations << {
          type: 'segment_too_long',
          segment: "#{segment[:origin]} to #{segment[:destination]}",
          issues: validation[:issues],
          suggested_splits: validation[:suggested_splits],
          current_distance: route[:legs].first[:distance_km],
          current_duration: route[:legs].first[:duration_hours]
        }
      end

      # Check for overall trip recommendations
      summary = generate_summary(results)
      if summary[:total_duration_hours] > (user_preferences[:max_daily_drive_h] || 8) * 7 # Weekly limit
        recommendations << {
          type: 'trip_too_intensive',
          message: "Total trip duration (#{summary[:total_duration_hours].round(1)}h) may be too intensive for a single trip",
          suggestion: "Consider extending the trip duration or reducing the number of destinations"
        }
      end

      recommendations
    end
  end
end