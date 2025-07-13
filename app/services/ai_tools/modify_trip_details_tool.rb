# frozen_string_literal: true

module AITools
  class ModifyTripDetailsTool < BaseTool
    def definition
      {
        type: 'function',
        function: {
          name: 'modify_trip_details',
          description: 'Modify trip details such as title, description, start date, end date, and other trip metadata',
          parameters: {
            type: 'object',
            properties: {
              title: {
                type: 'string',
                description: 'The title of the trip'
              },
              description: {
                type: 'string',
                description: 'A detailed description of the trip'
              },
              start_date: {
                type: 'string',
                format: 'date',
                description: 'The start date of the trip (YYYY-MM-DD)'
              },
              end_date: {
                type: 'string',
                format: 'date',
                description: 'The end date of the trip (YYYY-MM-DD)'
              },
              is_public: {
                type: 'boolean',
                description: 'Whether the trip should be public or private'
              },
              trip_data: {
                type: 'object',
                description: 'Additional trip metadata to store'
              }
            }
          }
        }
      }
    end

    def call(args)
      Rails.logger.info "Modifying trip details: #{args.inspect}"

      # Validate and clean the arguments
      cleaned_args = clean_arguments(args)

      # Update the trip with the new details
      if @trip.update(cleaned_args)
        {
          success: true,
          message: 'Trip details updated successfully',
          updated_fields: cleaned_args.keys,
          trip_id: @trip.id
        }
      else
        {
          success: false,
          error: 'Failed to update trip details',
          validation_errors: @trip.errors.full_messages
        }
      end
    rescue => e
      Rails.logger.error "Error modifying trip details: #{e.message}"
      {
        success: false,
        error: "Failed to modify trip details: #{e.message}"
      }
    end

    private

    def clean_arguments(args)
      cleaned = {}

      # Handle native trip attributes
      if args['title'].present?
        cleaned[:title] = args['title'].strip
      end

      if args['description'].present?
        cleaned[:description] = args['description'].strip
      end

      if args['start_date'].present?
        begin
          cleaned[:start_date] = Date.parse(args['start_date'])
        rescue Date::Error
          Rails.logger.warn "Invalid start_date format: #{args['start_date']}"
        end
      end

      if args['end_date'].present?
        begin
          cleaned[:end_date] = Date.parse(args['end_date'])
        rescue Date::Error
          Rails.logger.warn "Invalid end_date format: #{args['end_date']}"
        end
      end

      if args.key?('is_public')
        cleaned[:public_trip] = args['is_public']
      end

      # Handle trip_data (additional metadata)
      if args['trip_data'].present?
        current_trip_data = @trip.trip_data || {}
        updated_trip_data = current_trip_data.merge(args['trip_data'])
        cleaned[:trip_data] = updated_trip_data
      end

      cleaned
    end
  end
end