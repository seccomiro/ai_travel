# 🐳 Docker Development Environment

This project supports both local development and Docker-based development. The Docker environment provides consistent, isolated development across different machines.

## 🚀 Quick Start

### 1. First Time Setup

```bash
# Setup Docker development environment
bin/docker-dev setup
```

This will:
- Build the Docker images
- Start PostgreSQL, Redis containers
- Create and migrate databases
- Set up the development environment

### 2. Start Development

```bash
# Start all services (Rails, PostgreSQL, Redis, Sidekiq)
bin/docker-dev start
```

Your app will be available at: http://localhost:3000

### 3. Stop Development

```bash
# Stop all containers
bin/docker-dev stop
```

## 📋 Available Commands

| Command | Description |
|---------|-------------|
| `bin/docker-dev setup` | Initial setup (first time only) |
| `bin/docker-dev start` | Start all services |
| `bin/docker-dev stop` | Stop all services |
| `bin/docker-dev restart` | Restart all services |
| `bin/docker-dev reset` | Reset environment (removes data) |
| `bin/docker-dev logs [service]` | Show logs |
| `bin/docker-dev shell` | Open bash shell in web container |
| `bin/docker-dev rails <cmd>` | Run Rails commands |
| `bin/docker-dev test` | Run test suite |
| `bin/docker-dev local` | Switch back to local development |

## 🔧 Development Workflow

### Running Rails Commands

```bash
# Rails console
bin/docker-dev rails console

# Generate migration
bin/docker-dev rails generate migration AddFieldToModel

# Run migrations
bin/docker-dev rails db:migrate

# Rollback migration
bin/docker-dev rails db:rollback
```

### Running Tests

```bash
# Run all tests
bin/docker-dev test

# Run specific test file
docker compose exec web bundle exec rspec spec/models/user_spec.rb

# Run tests with coverage
docker compose exec web bundle exec rspec --require spec_helper
```

### Database Management

```bash
# Reset database
bin/docker-dev rails db:reset

# Seed database
bin/docker-dev rails db:seed

# Access PostgreSQL console
docker compose exec postgres psql -U ai_travel -d ai_travel_development
```

### Debugging

```bash
# View logs
bin/docker-dev logs web
bin/docker-dev logs postgres
bin/docker-dev logs sidekiq

# Shell access
bin/docker-dev shell

# Tail all logs
docker compose logs -f
```

## 🏗️ Architecture

### Services

- **web**: Rails application (port 3000)
- **postgres**: PostgreSQL 15 with pgvector (port 5432)
- **postgres_test**: Test database (port 5433)
- **redis**: Redis for caching and Sidekiq (port 6379)
- **sidekiq**: Background job processing

### Volumes

- **postgres_data**: PostgreSQL data persistence
- **redis_data**: Redis data persistence  
- **bundle_cache**: Gem cache for faster builds
- **node_modules**: Node.js modules cache

### Environment Variables

The Docker setup uses these environment variables:

```bash
DATABASE_URL=postgres://ai_travel:password@postgres/ai_travel_development
TEST_DATABASE_URL=postgres://ai_travel:password@postgres_test/ai_travel_test
REDIS_URL=redis://redis:6379/0
RAILS_ENV=development
```

## 🔄 Switching Between Local and Docker

### To Docker (from local)

```bash
# Stop local services
brew services stop postgresql
brew services stop redis

# Start Docker environment
bin/docker-dev setup
bin/docker-dev start
```

### To Local (from Docker)

```bash
# Stop Docker
bin/docker-dev local

# Start local services
brew services start postgresql
brew services start redis

# Use local development
bin/dev
```

## ⚠️ Port Conflicts

If you're running local PostgreSQL/Redis, you may need to stop them:

```bash
# Stop local PostgreSQL
brew services stop postgresql

# Stop local Redis  
brew services stop redis

# Check what's using port 5432
lsof -i :5432
```

## 🐛 Troubleshooting

### PostgreSQL Connection Issues

```bash
# Check if PostgreSQL is ready
docker compose exec postgres pg_isready -U ai_travel

# Restart PostgreSQL
docker compose restart postgres

# Check logs
bin/docker-dev logs postgres
```

### Gem Installation Issues

```bash
# Rebuild with fresh bundle
docker compose build --no-cache web

# Clear bundle cache
docker compose down -v
bin/docker-dev reset
```

### Permission Issues

```bash
# Fix ownership (if needed)
sudo chown -R $(whoami):$(whoami) .

# Rebuild containers
docker compose build --no-cache
```

### Reset Everything

```bash
# Nuclear option - removes all data
bin/docker-dev reset
```

## 📊 Performance Tips

1. **Use volume caches**: Bundle and node_modules are cached in volumes
2. **Partial rebuilds**: Only rebuild when Gemfile/package.json changes
3. **Local file changes**: Code changes are reflected immediately via volume mounts
4. **Database persistence**: Data survives container restarts

## 🔍 Monitoring

### Check Service Health

```bash
# Check all services
docker compose ps

# Check specific service health
docker compose exec postgres pg_isready
docker compose exec redis redis-cli ping
```

### Resource Usage

```bash
# Monitor resource usage
docker stats

# Monitor specific container
docker stats ai_travel_web_1
```

## 🆚 Docker vs Local Development

| Aspect | Docker | Local |
|--------|--------|-------|
| **Consistency** | ✅ Same everywhere | ❌ Varies by machine |
| **Isolation** | ✅ Completely isolated | ❌ Shared system |
| **Setup Time** | ⏳ Slower initial setup | ⚡ Faster if already installed |
| **Performance** | 🐌 Slightly slower | ⚡ Native speed |
| **Dependencies** | ✅ Everything included | ❌ Manual installation |
| **PostgreSQL** | ✅ Automatic pgvector | ⚠️ Manual extension setup |

Choose based on your needs:
- **Docker**: For consistency, CI/CD parity, easy onboarding
- **Local**: For maximum performance, familiar environment 