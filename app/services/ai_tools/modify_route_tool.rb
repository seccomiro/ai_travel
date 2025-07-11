module AITools
  class ModifyRouteTool < BaseTool
    def definition
      current_destinations = @trip.trip_data.dig('current_route', 'destinations')
      return nil unless current_destinations.present? # This tool is only available if a route exists.

      {
        type: 'function',
        function: {
          name: 'modify_route',
          description: "Modify the existing route. The current route is: #{current_destinations.join(' -> ')}. Use this tool to add or remove destinations.",
          parameters: {
            type: 'object',
            properties: {
              add_destinations: {
                type: 'array',
                items: { type: 'string' },
                description: 'An array of destination names to add to the route.',
              },
              add_before: {
                type: 'string',
                description: 'The existing destination before which the new destination(s) should be added.',
              },
              add_after: {
                type: 'string',
                description: 'The existing destination after which the new destination(s) should be added. Defaults to the end.',
              },
              remove_destinations: {
                type: 'array',
                items: { type: 'string' },
                description: 'An array of destination names to remove from the route.',
              },
            },
          },
        },
      }
    end
  end
end
