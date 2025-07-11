module AITools
  class PlanRouteTool < BaseTool
    def definition
      {
        type: 'function',
        function: {
          name: 'plan_route',
          description: 'Plan a new route from scratch, overwriting any existing route. Supports driving, walking, bicycling, and transit. Does not support flights.',
          parameters: {
            type: 'object',
            properties: {
              destinations: {
                type: 'array',
                items: {
                  type: 'string',
                },
                description: "Array of destination names in order. E.g., ['Paris, France', 'London, UK'].",
              },
              transport_mode: {
                type: 'string',
                enum: ['driving', 'walking', 'bicycling', 'transit'],
                description: "Preferred mode of transportation. Defaults to 'driving'.",
              },
            },
            required: ['destinations'],
          },
        },
      }
    end
  end
end
