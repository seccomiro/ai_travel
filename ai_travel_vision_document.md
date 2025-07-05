
# Vision Document – AI-Powered Travel Planning Platform

## Overview

The platform aims to help users plan personalized trips through an intelligent, interactive assistant powered by AI. The user will engage in a conversation with the system to build their travel itinerary step-by-step, with suggestions, constraints, and optimizations presented in real time.

---

## Core Features

### 1. Travel Management
- Users can **create, edit, and save trips**.
- Each trip includes metadata such as name, travel dates, participants, user preferences, and conversation history.

### 2. Conversational Interface (AI Chat)
- The main interaction happens via a **chat powered by AI** where users can:
  - Provide trip parameters in natural language.
  - Request suggestions, changes, clarifications, and constraints dynamically.
- The chat must be:
  - Highly flexible and able to handle free-form input.
  - Incremental, maintaining the full context and state of the trip.
  - Proactive, suggesting next steps such as:
    - “Would you like to generate the travel guide now?”
    - “How long would you like to stay in this location?”

### 3. Collaboration and Sharing
- Users may **share trips with others** to:
  - View the full guide.
  - Co-edit the trip or contribute with comments.

---

## Input Parameters

The AI and the platform should accept (and suggest) various variables, such as:

- **Transportation mode**: car, plane, RV, electric vehicle, bicycle, etc.
- **Key dates**: start/end dates, desired dates in specific locations.
- **Required or desired stops** (e.g., "I want to spend New Year’s Eve in Bariloche").
- **Travel limits**: maximum distance per leg, daily driving time.
- **Roadway preferences**:
  - Avoid dirt roads or tolls.
  - Prefer highways with structure, duplicated lanes, fuel stations every 100km.
- **Stop criteria**:
  - Cities with infrastructure: lodging, markets, fuel, camping.
  - Geographic preference: beach, mountain, nature, city.
- **Preferred lodging**: hotel, hostel, camping, AirBnB, ecolodges.
- **Tourism interests**: cultural activities, nature, hiking, shopping, nightlife.
- **Physical or personal restrictions**: accessibility, pets, kids, medical needs.
- **Budget constraints** or spending profile (budget, moderate, luxury).
- **Preferred climates or seasons**.

✅ *Bonus*: support importing calendars (Google, Apple) and booking data (Airbnb, Booking) to enhance suggestions.

---

## Platform Output

At any point, the system should be able to generate:

- **Structured trip summary**, including:
  - Daily itinerary with segments, distances, schedules.
  - Justified stops and durations.
  - Estimated cost breakdown by category (transport, lodging, food, activities).
- **Interactive Map**:
  - With route, stops, points of interest, fuel stations.
- **Smart Suggestions**:
  - Lodging options (with links, filters, reviews).
  - Attractions, activities (with official links).
  - Alternative routes with explanations and trade-offs.
- **Logistics Info**:
  - ATM/currency exchange locations, gas stations, emergency facilities.
  - Legal requirements, required vehicle items, documentation.
- **Interactive checklist**:
  - Documents, emergency items, seasonal-specific gear.
- **Useful Links**:
  - Tour operators, local guides, government tourism resources.

✅ *Bonus*: offline support to access the trip guide during the journey.

---

## Technical Recommendations and Initial Architecture

### Tech Stack

- **Backend**:  
  - Framework: **Ruby on Rails 8** with **Hotwire** (Turbo/Stimulus).  
  - Database: **PostgreSQL** with `pgvector` extension for vector search.  
  - Background jobs: **Sidekiq** + Redis.  
  - Authentication: Devise with OAuth (Google, Apple).
  - UI: Bootstrap.

- **Frontend**:  
  - Hotwire-based HTML-over-the-wire frontend.  
  - Real-time chat using Turbo Streams.  
  - Dynamic components via Stimulus controllers.

- **Automated Testing**:
  - **RSpec** for unit, integration, and system tests.
  - **FactoryBot** for test data creation.
  - **Shoulda-Matchers** for declarative model tests.
  - **WebMock** to mock/block external HTTP requests.
  - (Optional) **VCR** to record/replay external requests.
  - **Capybara + Turbo helpers** for E2E tests with Hotwire.
  - **SimpleCov** for coverage reporting.

### AI and LLM

#### Conversational AI
- Chat must retain state across user interactions.
- The AI generates suggestions incrementally based on current trip state.

#### RAG (Retrieval-Augmented Generation)
- **Vector Database** (e.g. pgvector, Weaviate, Qdrant) stores embeddings of travel content.
- Each user interaction triggers a query to the vector DB to retrieve relevant documents to enrich prompts.

#### AI Tools
- External data integrations (Google Maps, lodging, weather, gas, currency) exposed as JSON-based tools that the LLM can call dynamically.

#### Prompt Structure
1. **System Prompt**: defines the AI behavior (e.g., expert travel planner).
2. **Context**: user's preferences, current state, documents from RAG.
3. **User Message**: latest input.
4. **Function List**: available tools and their JSON schema.

---

## Next Steps for the Development Team

### 1. Application Setup
- Initialize a Ruby on Rails 8 project.
- Configure Hotwire (Turbo/Stimulus).
- Set up PostgreSQL with pgvector.
- Add Redis + Sidekiq for background jobs.

### 2. AI Infrastructure
- Choose and integrate LLM provider (OpenAI, Mistral, Claude, etc).
- Implement RAG pipeline (ETL > embedding > vector DB > retrieval).
- Define and register AI tools (functions).
- Build prompt system with reusable templates.

### 3. Data Acquisition & Integrations
- Configure APIs: Google Maps, Booking, Airbnb, Weather, Exchange Rates.
- Schedule periodic ETL and caching.

### 4. Chat MVP
- Build chat UI with real-time context-aware interaction.
- Store user inputs, preferences, decisions.

### 5. Metrics & Analytics
- Track interactions, usage, and AI feedback for refinement.
- Create admin dashboards.

### 6. MVP Scope
- Target use case: road trip with up to 5 stops.
- Deliver itinerary, lodging, and basic day-by-day guide.

### 7. Testing Implementation
- Configure:
  - `rspec-rails`
  - `factory_bot_rails`
  - `shoulda-matchers`
  - `webmock`
  - `vcr` (optional)
  - `capybara` with Hotwire support
  - `simplecov`

✅ Apply minimum coverage thresholds for core layers (models, services, controllers, AI interactions).

---

## Additional Requirements

### 1. Full Internationalization Support
- The platform must be fully internationalized (i18n).
- All user-facing strings, including UI labels, buttons, messages, and notifications, must support multiple languages.
- Users must be able to configure their preferred language.
- All interactions with the AI (LLMs) must **respect the user's selected language**:
  - Prompts must be dynamically internationalized or generated in the user’s language.
  - System instructions, responses, and retrieved documents should be aligned with the user’s locale.

### 2. Learning and Reusing User Preferences
- The platform must identify and learn from user behavior and choices over time.
- Preferences should be stored and reused to tailor future suggestions.
- Examples include:
  - Preferred travel styles (e.g., adventure, cultural, luxury).
  - Preferred transportation modes (e.g., car, plane).
  - Budget preferences (e.g., economical, premium).
- Onboarding questions (in natural language) can be used to gather initial preferences quickly.

### 3. Enhanced Interactive Chat Interface
- The chat UI must be more than a simple conversation box.
- A **real-time interactive sidebar or panel** must display the **current trip plan**, updating live based on the conversation.
- This panel may include:
  - Trip timeline or map.
  - Planned stops and travel segments.
  - Active preferences, constraints, or unanswered questions.
  - Suggested actions (e.g., “Add hotel”, “Finalize destination”).

