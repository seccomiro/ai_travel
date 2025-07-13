# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Tripyo is an AI-powered travel planning platform built with Ruby on Rails 8.0.2 that transforms trip planning into an intelligent, conversational experience. The app is currently in Phase 2, implementing AI integration features.

## Essential Commands

### Development

```bash
# Docker Development (recommended)
bin/docker-dev setup              # Initial setup
bin/docker-dev start              # Start all services
bin/docker-dev rails console      # Rails console
bin/docker-dev shell              # Container shell

You must only use rails commands through `bin/docker-dev`.

### Testing

```bash
# Run full test suite
bin/docker-dev test              # Docker

# Run specific test
bin/docker-dev bundle exec rspec spec/models/user_spec.rb
bin/docker-devbundle exec rspec spec/models/user_spec.rb:15  # Specific line
```

### Code Quality

```bash
# Linting (uses Rubocop with Rails Omakase style)
bin/docker-dev bundle exec rubocop              # Check all files
bin/docker-dev bundle exec rubocop -a           # Auto-correct offenses
bin/docker-dev bundle exec rubocop -f github           # GitHub Actions format
```

### Database

```bash
# Migrations
bin/docker-dev rails db:migrate            # Run pending migrations
bin/docker-dev rails db:rollback          # Rollback last migration
bin/docker-dev rails db:reset             # Drop, create, migrate, seed
```

## Architecture & Key Patterns

### Service Objects Pattern

The codebase heavily uses service objects for business logic, especially for AI integration:

```
app/services/
├── ai_prompts/              # AI prompt templates (new)
├── ai_tools/                # AI tool implementations
│   └── plan_route_tool.rb   # Route planning AI tool
├── chat_response_service.rb # Chat message handling
├── openai_chat_service.rb   # OpenAI API integration
├── route_optimization_service.rb # Route optimization logic
└── route_request_detector_service.rb # Detect route requests in chat
```

### Real-time Updates with Hotwire

Uses Turbo Streams for real-time UI updates without full page reloads:
- Chat messages stream updates
- Trip modifications broadcast changes
- Form submissions use Turbo for seamless UX

### AI Integration Architecture

1. **Chat Flow**: ChatMessage → ChatResponseService → OpenAIChatService → AI Tools
2. **Route Planning**: Google Maps for geocoding/directions

### Testing Patterns

- **WebMock**: Stubs external HTTP requests
- **VCR**: Records HTTP interactions for consistent AI/API tests
- **FactoryBot**: Test data generation
- **DatabaseCleaner**: Ensures test isolation

## Code Style Guidelines

### Ruby/Rails Conventions

- **Quotes**: Single quotes preferred (enforced by Rubocop)
- **Trailing Commas**: Required for multi-line hashes/arrays
- **Rails Omakase**: Follow Rails default patterns
- **Service Objects**: Return success/failure with clear interfaces
- **Trailing spaces**: Always remove trailing spaces

### Testing Best Practices

- Write request specs for API endpoints
- Use factories instead of fixtures
- Stub external services with WebMock (preferable) or VCR
- Test service objects in isolation

## Current Development Context

### Active Branch: feat-custom-attributes

Working on route optimization features:
- RouteOptimizationService: Complex route calculation
- AI tools for planning routes
- Integration with Google Maps API
- Real-time trip modifications via AI

### Key Models

- **User**: Devise authentication with language preferences
- **Trip**: Flexible JSON data storage for itineraries
- **ChatSession**: AI conversation context
- **ChatMessage**: Individual messages with AI responses

### Environment Variables

Required for development:
- `OPENAI_API_KEY`: OpenAI API access
- `GOOGLE_MAPS_API_KEY`: Google Maps services
- `RAILS_MASTER_KEY`: Rails credentials (auto-generated)

## Common Tasks

### Adding a New AI Tool

1. Create service in `app/services/ai_tools/`
2. Implement standard interface (call method)
3. Add to OpenAIChatService tool registry
4. Write comprehensive specs with WebMocks

### Modifying Chat Behavior

1. Update `app/services/chat_response_service.rb`
2. Test with real OpenAI calls
3. Ensure Turbo Stream broadcasts work correctly

### Database Migrations with pgvector

When adding vector columns:
```ruby
add_column :table_name, :embedding, :vector, limit: 1536
add_index :table_name, :embedding, using: :ivfflat, opclass: :vector_l2_ops
```
