# Tripyo Data Schema: The `Trip` Model

This document outlines the data structure for a `Trip` in Tripyo, covering both the native columns in the `trips` PostgreSQL table and the flexible schema for the `trip_data` JSONB field.

---

## Part 1: `trips` Table - Native Columns

These are the primary columns on the `trips` table. They are native columns because they are frequently used for filtering, sorting, and indexing. For example, finding all of a user's "active" trips.

| Column | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `title` | `string` | The main name of the trip, provided by the user. Note: Aliased as `name` in the model. | `"Road Trip to the Grand Canyon"` |
| `description` | `text` | A longer, free-text description of the trip's goals or details. | `"A 10-day family road trip..."` |
| `status` | `string` | The current stage of the trip planning process. | `"planning"` |
| `start_date` | `date` | The official start date of the trip. | `2025-12-20` |
| `end_date` | `date` | The official end date of the trip. | `2026-01-05` |
| `origin` | `string` | The starting location of the journey. | `"San Francisco, CA"` |
| `destination` | `string` | The final or primary destination of the journey. | `"Denver, CO"` |
| `public_trip` | `boolean`| Whether the trip is visible to the public. | `false` |
| `trip_data` | `jsonb` | A flexible JSON field for detailed user preferences. See Part 2. | `{ "pace": "moderate", ... }` |

---

## Part 2: `trip_data` - JSONB Schema Definition

This JSONB field stores rich, detailed preferences that guide the AI conversation but are not typically used for direct, high-performance database queries.

#### **1. Top-Level Metadata**

| Attribute | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `schema_version` | String | Version of this schema for future migrations. | `"1.1"` |
| `trip_type` | Enum | The overall nature of the trip's geography. | `"road_trip"` (`one_way`, `round_trip`, `multi_city`) |
| `date_flexibility`| Object | How much the native `start_date` and `end_date` can shift. | `{ "days_before": 2, "days_after": 2 }` |

#### **2. Participants**

| Attribute | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `group_composition`| Object | A breakdown of the travel party. | `{ "adults": 2, "children": [ { "age": 5 } ] ... }` |
| `...adults` | Integer | Number of adults (18+). | `2` |
| `...children` | Array(Obj) | List of children by age. | `[ { "age": 5 }, { "age": 12 } ]` |
| `...infants` | Integer | Number of infants (< 2). | `1` |
| `...pets` | Array(Obj) | Details about any accompanying pets. | `[ { "type": "dog", "size": "large" } ]` |

#### **3. Itinerary & Pace**

| Attribute | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `pace` | Enum | The desired intensity of the trip. | `"moderate"` (`relaxed`, `fast_paced`, `packed`) |
| `stops` | Array(Obj) | The planned sequence of stops in the itinerary. | `[ { "location_name": "Lake Tahoe", ... } ]` |
| `...stop_id` | UUID | A unique identifier for the stop. | `"a1b2c3d4-..."` |
| `...location_name`| String | Human-readable name of the stop. | `"Lake Tahoe, CA"` |
| `...coordinates` | Object | Geographic coordinates. | `{ "lat": 39.0968, "lon": -120.0324 }` |
| `...arrival_dt` | String | Planned arrival date/time (ISO 8601). | `"2025-12-22T14:00:00Z"` |
| `...departure_dt`| String | Planned departure date/time (ISO 8601). | `"2025-12-25T10:00:00Z"` |
| `...purpose` | Array | Reasons for the stop. | `["rest", "skiing"]` |
| `timing_constraints`| Array(Obj)| Fixed events or dates that must be respected. | `[ { "description": "New Year's Eve in Bariloche", "date": "2025-12-31" } ]` |

#### **4. Transportation**

How the user will travel between stops.

| Attribute | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `primary_mode` | Enum | The main method of transport. | `"car"` (`rv`, `plane`, `train`, `bicycle`, `motorcycle`) |
| `route_preferences` | Object | Preferences for road travel. | `{ "avoid": ["tolls", "dirt_roads"], "prefer": ["scenic_routes"] }` |
| `...max_daily_drive_h` | Integer | Max hours to drive in a single day. | `8` |
| `...ev_charging_req` | Boolean | If the vehicle is electric and needs charging stops. | `true` |
| `rental_info` | Object | Details if a vehicle rental is needed. | `{ "type": "suv", "company": "Hertz" }` |

#### **5. Lodging**

Accommodation preferences.

| Attribute | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `preferred_types` | Array | List of acceptable lodging types. | `["hotel", "vacation_rental", "camping"]` |
| `preferences` | Object | Specific requirements for lodging. | `{ "min_rating": 4.0, "amenities": ["wifi", "pool"] ...}` |
| `...min_rating`| Float | Minimum review score (e.g., on Google/Booking). | `4.0` |
| `...amenities` | Array | Must-have amenities. | `["wifi", "pool", "kitchen", "pet_friendly"]`|
| `...proximity_to`| Array | Desired location characteristics. | `["city_center", "beach", "public_transport"]` |

#### **6. Interests & Activities**

What the user wants to do.

| Attribute | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `categories` | Array | Broad areas of interest. | `["nature", "history", "gastronomy", "nightlife"]`|
| `specific_interests` | Array | Granular hobbies or activities. | `["hiking", "wine_tasting", "museums"]` |
| `must_do` | Array | Non-negotiable activities or sights. | `["See the Grand Canyon"]` |
| `things_to_avoid` | Array | Known dislikes or things to skip. | `["crowded_places", "tourist_traps"]` |

#### **7. Budget & Finance**

Financial profile for the trip.

| Attribute | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `profile` | Enum | General spending level. | `"mid-range"` (`budget`, `mid-range`, `luxury`) |
| `total_budget`| Integer | The overall maximum budget for the trip. | `5000` |
| `currency` | String | The currency for all financial figures (ISO 4217). | `"USD"` |

#### **8. Special Requirements**

Important constraints and needs.

| Attribute | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `dietary` | Array | Food allergies or dietary needs. | `["vegetarian", "gluten_free", "peanut_allergy"]`|
| `accessibility`| Array | Physical accessibility requirements. | `["wheelchair_access", "step_free_ramps"]` |

#### **9. Dynamic & Unstructured Data**

A flexible space for AI-inferred or user-provided custom data.

| Attribute | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `ai_notes` | Object | Key-value pairs inferred by the AI during conversation. | `{ "user_is_light_sleeper": true, "prefers_window_seat": true }` |
| `user_notes` | String | A freeform text field for the user's own notes. | `"Remember to buy souvenirs for family."` |