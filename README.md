# 🚀 Tripyo

Tripyo is an AI-powered travel planning platform that transforms trip planning from a research task into an intelligent, conversational experience.

## 🎯 Features

- **Conversational AI Planning**: Natural language trip planning with intelligent AI assistance
- **User Authentication**: Secure registration and login with multi-language support
- **Trip Management**: Create, edit, and manage travel itineraries
- **Internationalization**: Support for English and Spanish (extensible)
- **Responsive Design**: Mobile-first Bootstrap UI

## 🏗️ Technical Stack

- **Backend**: Ruby on Rails 8.0.2 with Hotwire (Turbo + Stimulus)
- **Database**: PostgreSQL 15 with pgvector extension
- **Frontend**: Bootstrap 5 with responsive design
- **Authentication**: Devise with custom user fields
- **Testing**: RSpec with 109 comprehensive tests
- **Background Jobs**: Sidekiq with Redis
- **AI Integration**: OpenAI integration ready
- **Deployment**: Docker + Kamal

## 🚀 Quick Start

### Option 1: Docker Development (Recommended)

Perfect for consistency across machines and easy setup:

```bash
# First time setup
bin/docker-dev setup

# Start development
bin/docker-dev start
```

Visit: http://localhost:3000

See [Docker Development Guide](DOCKER_DEVELOPMENT.md) for detailed instructions.

### Option 2: Local Development

For maximum performance with local tools:

```bash
# Install dependencies
bundle install
yarn install

# Setup database
bin/rails db:create db:migrate

# Start development
bin/dev
```

Visit: http://localhost:3000

## 📋 Development Commands

### Docker Development

```bash
bin/docker-dev setup     # Initial setup
bin/docker-dev start     # Start all services
bin/docker-dev test      # Run tests
bin/docker-dev rails c   # Rails console
bin/docker-dev shell     # Container shell
bin/docker-dev local     # Switch to local dev
```

### Local Development

```bash
bin/dev                   # Start development server
bin/rails console        # Rails console
bundle exec rspec        # Run tests
bin/rails db:reset       # Reset database
```

## 🧪 Testing

The project has comprehensive test coverage with 109 tests:

```bash
# Docker
bin/docker-dev test

# Local
bundle exec rspec

# With coverage
bundle exec rspec --require spec_helper
```

**Test Coverage:**
- Model tests: 48 examples
- Request tests: 17 examples  
- Helper tests: 43 examples
- Integration tests: 2 examples

## 🌍 Internationalization

The application supports multiple languages:

- **English** (en) - Default
- **Spanish** (es) - Complete translation

Add new languages by creating locale files in `config/locales/`.

## 📊 System Requirements

### Local Development

- **Ruby**: 3.4.4
- **Node.js**: 24.2.0
- **PostgreSQL**: 15+ with pgvector extension
- **Redis**: 7+
- **Yarn**: 1.22.22

### Docker Development

- **Docker**: Latest
- **Docker Compose**: v3.8+

## 🏗️ Architecture

### Models

- **User**: Authentication with preferences and language settings
- **Trip**: Travel itineraries with flexible JSON data storage

### Key Features

- **Hotwire Integration**: Real-time updates with Turbo Streams
- **Helper Methods**: 11 tested helper methods for consistent UI
- **Bootstrap Components**: Professional responsive design
- **Security**: Comprehensive authentication and authorization
- **CI/CD**: GitHub Actions with testing and security scanning

## 🚀 Deployment

### Production (Kamal)

```bash
# Deploy to production
kamal deploy
```

### Docker Production

```bash
# Build production image
docker build -t tripyo .

# Run production container
docker run -d -p 80:80 -e RAILS_MASTER_KEY=<key> tripyo
```

## 📚 Development Phases

- ✅ **Phase 1**: Foundation (Rails app, authentication, basic CRUD)
- 🔄 **Phase 2**: AI Integration (Coming next)
- 📋 **Phase 3**: Advanced AI Features
- 📋 **Phase 4**: Collaboration & Export
- 📋 **Phase 5**: Polish & Launch

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Run tests (`bin/docker-dev test` or `bundle exec rspec`)
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## 📝 License

This project is private and proprietary.

## 🆘 Support

- [Docker Development Guide](DOCKER_DEVELOPMENT.md)
- [Development Plan](tripyo_development_plan.md)
- [Technical Roadmap](tripyo_technical_roadmap.md)
