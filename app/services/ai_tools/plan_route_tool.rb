module AITools
  class PlanRouteTool < BaseTool
    def self.definition
      {
        type: 'function',
        function: {
          name: 'plan_route',
          description: 'Plan a route between two or more destinations',
          parameters: {
            type: 'object',
            properties: {
              destinations: {
                type: 'array',
                items: {
                  type: 'string',
                },
                description: "Array of destination names (e.g., ['Paris', 'London', 'Rome'])",
              },
              transport_mode: {
                type: 'string',
                enum: ['car', 'train', 'plane', 'bus'],
                description: 'Preferred mode of transportation',
              },
            },
            required: ['destinations'],
          },
        },
      }
    end
  end
end
