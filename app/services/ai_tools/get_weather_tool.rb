module AITools
  class GetWeatherTool < BaseTool
    def self.definition
      {
        type: 'function',
        function: {
          name: 'get_weather',
          description: 'Get current weather information for a specific location',
          parameters: {
            type: 'object',
            properties: {
              location: {
                type: 'string',
                description: "The city and country name (e.g., 'Paris, France')"
              }
            },
            required: ['location']
          }
        }
      }
    end
  end
end 