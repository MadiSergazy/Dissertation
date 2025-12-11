.PHONY: build run test clean docker-up docker-down docker-status docker-restart docker-logs install-deps init-db migrate-up migrate-down migrate-status migrate-reset start stop status restart logs

# Build all agents
build:
	@echo "Building main-agent..."
	@go build -o bin/main-agent cmd/main-agent/main.go
	@echo "Building scanner-agent..."
	@go build -o bin/scanner-agent cmd/scanner-agent/main.go
	@echo "Building analyzer-agent..."
	@go build -o bin/analyzer-agent cmd/analyzer-agent/main.go
	@echo "Building reporter-agent..."
	@go build -o bin/reporter-agent cmd/reporter-agent/main.go
	@echo "Build complete!"

# Initialize database
init-db: docker-up
	@echo "Initializing database..."
	@sleep 5
	@docker exec -i pentool-postgres psql -U admin -d pentool < scripts/init-db.sql
	@echo "Database initialized!"

# Run docker services
docker-up:
	@echo "Starting Docker services..."
	@docker-compose -f deployments/docker-compose.yml up -d
	@echo "Waiting for services to be ready..."
	@sleep 5
	@echo "Services are up!"

# Stop docker services
docker-down:
	@echo "Stopping Docker services..."
	@docker-compose -f deployments/docker-compose.yml down
	@echo "Services stopped!"

# Show docker services status
docker-status:
	@docker-compose -f deployments/docker-compose.yml ps

# Restart docker services
docker-restart: docker-down docker-up
	@echo "Services restarted!"

# Show docker logs
docker-logs:
	@docker-compose -f deployments/docker-compose.yml logs -f

# ===========================================
# Short aliases for quick access
# ===========================================

# Start services (alias for docker-up)
start: docker-up

# Stop services (alias for docker-down)
stop: docker-down

# Show status (alias for docker-status)
status: docker-status

# Restart services (alias for docker-restart)
restart: docker-restart

# Show logs (alias for docker-logs)
logs: docker-logs

# Run main agent
run: docker-up
	@echo "Starting main agent..."
	@./bin/main-agent

# Run all agents
run-all: build docker-up
	@echo "Starting all agents..."
	@./bin/main-agent &
	@./bin/scanner-agent &
	@./bin/analyzer-agent &
	@./bin/reporter-agent &
	@echo "All agents started! Press Ctrl+C to stop."
	@wait

# Run tests
test:
	@echo "Running tests..."
	@go test -v ./...

# Install dependencies
install-deps:
	@echo "Installing Go dependencies..."
	@go get github.com/spf13/cobra@latest
	@go get github.com/nats-io/nats.go@latest
	@go get github.com/sirupsen/logrus@latest
	@go get github.com/lib/pq@latest
	@go get github.com/google/uuid@latest
	@go get github.com/go-redis/redis/v8@latest
	@go mod tidy
	@echo "Dependencies installed!"

# Clean build artifacts
clean:
	@echo "Cleaning up..."
	@rm -rf bin/
	@docker-compose -f deployments/docker-compose.yml down -v
	@echo "Cleanup complete!"

# Quick start for development
dev: install-deps docker-up init-db build
	@echo "Development environment ready!"
	@echo "Run 'make run-all' to start all agents"

# Database migrations with Goose
DB_URL := postgres://admin:secret123@localhost:15433/pentool?sslmode=disable

migrate-up:
	@echo "Running database migrations..."
	@goose -dir migrations postgres "$(DB_URL)" up
	@echo "Migrations applied!"

migrate-down:
	@echo "Rolling back last migration..."
	@goose -dir migrations postgres "$(DB_URL)" down
	@echo "Migration rolled back!"

migrate-status:
	@echo "Migration status:"
	@goose -dir migrations postgres "$(DB_URL)" status

migrate-reset:
	@echo "Resetting database..."
	@goose -dir migrations postgres "$(DB_URL)" reset
	@echo "Database reset complete!"

migrate-create:
	@echo "Creating new migration: $(name)"
	@goose -dir migrations create $(name) sql
	@echo "Migration created!"

# Show help
help:
	@echo "=== Docker Services (Quick Commands) ==="
	@echo "  make start         - Start all services (PostgreSQL, NATS, Redis)"
	@echo "  make stop          - Stop all services"
	@echo "  make status        - Show services status"
	@echo "  make restart       - Restart all services"
	@echo "  make logs          - Show services logs (follow mode)"
	@echo ""
	@echo "=== Build & Run ==="
	@echo "  make build         - Build all agents"
	@echo "  make run           - Run main agent only"
	@echo "  make run-all       - Run all agents"
	@echo "  make test          - Run tests"
	@echo ""
	@echo "=== Database ==="
	@echo "  make init-db       - Initialize PostgreSQL database"
	@echo "  make migrate-up    - Run database migrations"
	@echo "  make migrate-down  - Rollback last migration"
	@echo "  make migrate-status- Check migration status"
	@echo "  make migrate-reset - Reset all migrations"
	@echo ""
	@echo "=== Setup & Cleanup ==="
	@echo "  make install-deps  - Install Go dependencies"
	@echo "  make dev           - Setup full dev environment"
	@echo "  make clean         - Clean build artifacts and Docker volumes"