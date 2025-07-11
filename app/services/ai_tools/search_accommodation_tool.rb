module AITools
  class SearchAccommodationTool < BaseTool
    def definition
      {
        type: 'function',
        function: {
          name: 'search_accommodation',
          description: 'Search for accommodation options in a specific location',
          parameters: {
            type: 'object',
            properties: {
              location: {
                type: 'string',
                description: "The city and country name (e.g., 'Paris, France')",
              },
              check_in: {
                type: 'string',
                description: 'Check-in date in YYYY-MM-DD format',
              },
              check_out: {
                type: 'string',
                description: 'Check-out date in YYYY-MM-DD format',
              },
              guests: {
                type: 'integer',
                description: 'Number of guests',
              },
            },
            required: ['location'],
          },
        },
      }
    end
  end
end
