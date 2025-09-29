.PHONY: build run test clean docker-up docker-down install-deps init-db

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

# Show help
help:
	@echo "Available targets:"
	@echo "  make build       - Build all agents"
	@echo "  make docker-up   - Start Docker services"
	@echo "  make docker-down - Stop Docker services"
	@echo "  make init-db     - Initialize PostgreSQL database"
	@echo "  make run         - Run main agent only"
	@echo "  make run-all     - Run all agents"
	@echo "  make test        - Run tests"
	@echo "  make install-deps- Install Go dependencies"
	@echo "  make clean       - Clean build artifacts and Docker volumes"
	@echo "  make dev         - Setup development environment"
	@echo "  make help        - Show this help message"