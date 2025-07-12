module AITools
  class ModifyTripDetailsTool < BaseTool
    def definition
      {
        type: 'function',
        function: {
          name: 'modify_trip_details',
          description: 'Modify the details of the current trip plan. Use this to update trip attributes, preferences, and structured data based on user requests.',
          parameters: {
            type: 'object',
            properties: {
              # Native trip attributes
              title: {
                type: 'string',
                description: 'The new title for the trip.',
              },
              description: {
                type: 'string',
                description: 'A new description for the trip.',
              },
              start_date: {
                type: 'string',
                description: 'The new start date for the trip, in YYYY-MM-DD format.',
              },
              end_date: {
                type: 'string',
                description: 'The new end date for the trip, in YYYY-MM-DD format.',
              },

              # Trip metadata
              trip_type: {
                type: 'string',
                enum: ['one_way', 'round_trip', 'multi_city', 'road_trip'],
                description: 'The overall nature of the trip\'s geography.',
              },
              pace: {
                type: 'string',
                enum: ['relaxed', 'moderate', 'fast_paced', 'packed'],
                description: 'The desired intensity of the trip.',
              },

              # Participants
              group_composition: {
                type: 'object',
                description: 'Detailed breakdown of the travel party.',
                properties: {
                  adults: { type: 'integer', description: 'Number of adults (18+).' },
                  children: {
                    type: 'array',
                    items: { type: 'object', properties: { age: { type: 'integer' } } },
                    description: 'List of children by age.'
                  },
                  infants: { type: 'integer', description: 'Number of infants (< 2).' },
                  pets: {
                    type: 'array',
                    items: {
                      type: 'object',
                      properties: {
                        type: { type: 'string' },
                        size: { type: 'string' }
                      }
                    },
                    description: 'Details about any accompanying pets.'
                  }
                }
              },

              # Transportation
              primary_mode: {
                type: 'string',
                enum: ['car', 'rv', 'plane', 'train', 'bicycle', 'motorcycle'],
                description: 'The main method of transport.',
              },
              route_preferences: {
                type: 'object',
                description: 'Preferences for road travel.',
                properties: {
                  avoid: {
                    type: 'array',
                    items: { type: 'string' },
                    description: 'Things to avoid (e.g., "tolls", "dirt_roads").'
                  },
                  prefer: {
                    type: 'array',
                    items: { type: 'string' },
                    description: 'Things to prefer (e.g., "scenic_routes").'
                  },
                  max_daily_drive_h: {
                    type: 'integer',
                    description: 'Max hours to drive in a single day.'
                  }
                }
              },

              # Lodging
              preferred_types: {
                type: 'array',
                items: { type: 'string' },
                description: 'List of acceptable lodging types (e.g., "hotel", "vacation_rental", "camping").',
              },
              lodging_preferences: {
                type: 'object',
                description: 'Specific requirements for lodging.',
                properties: {
                  min_rating: { type: 'number', description: 'Minimum review score.' },
                  amenities: {
                    type: 'array',
                    items: { type: 'string' },
                    description: 'Must-have amenities (e.g., "wifi", "pool").'
                  },
                  proximity_to: {
                    type: 'array',
                    items: { type: 'string' },
                    description: 'Desired location characteristics (e.g., "city_center", "beach").'
                  }
                }
              },

              # Interests & Activities
              categories: {
                type: 'array',
                items: { type: 'string' },
                description: 'Broad areas of interest (e.g., "nature", "history", "gastronomy").',
              },
              specific_interests: {
                type: 'array',
                items: { type: 'string' },
                description: 'Granular hobbies or activities (e.g., "hiking", "wine_tasting", "museums").',
              },
              must_do: {
                type: 'array',
                items: { type: 'string' },
                description: 'Non-negotiable activities or sights.',
              },
              things_to_avoid: {
                type: 'array',
                items: { type: 'string' },
                description: 'Known dislikes or things to skip (e.g., "crowded_places", "tourist_traps").',
              },

              # Budget & Finance
              budget_profile: {
                type: 'string',
                enum: ['budget', 'mid-range', 'luxury'],
                description: 'General spending level for the trip.',
              },
              total_budget: {
                type: 'integer',
                description: 'The overall maximum budget for the trip.',
              },
              currency: {
                type: 'string',
                description: 'The currency for all financial figures (ISO 4217, e.g., "USD").',
              },

              # Special Requirements
              dietary: {
                type: 'array',
                items: { type: 'string' },
                description: 'Food allergies or dietary needs (e.g., "vegetarian", "gluten_free").',
              },
              accessibility: {
                type: 'array',
                items: { type: 'string' },
                description: 'Physical accessibility requirements (e.g., "wheelchair_access").',
              },

              # Dynamic Data
              ai_notes: {
                type: 'object',
                description: 'Key-value pairs inferred by the AI during conversation.',
              },
              user_notes: {
                type: 'string',
                description: 'A freeform text field for the user\'s own notes.',
              },

              # Legacy fields for backward compatibility
              interests: {
                type: 'array',
                items: { type: 'string' },
                description: 'An array of interests for the trip (legacy field).',
              },
              activities: {
                type: 'array',
                items: { type: 'string' },
                description: 'An array of specific activities or places to visit (legacy field).',
              },
              budget: {
                type: 'string',
                description: 'The budget for the trip (legacy field, e.g., "economy", "standard", "luxury").',
              },
              travelers: {
                type: 'string',
                description: 'The type of travelers (legacy field, e.g., "solo", "couple", "family with kids").',
              }
            },
          },
        },
      }
    end
  end
end