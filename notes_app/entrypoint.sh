#!/bin/bash
set -e

# Wait for PostgreSQL to be ready
until pg_isready -h database -U "$POSTGRES_USER"; do
  echo "Waiting for PostgreSQL..."
  sleep 2
done

# Run pending migrations
echo "Running pending migrations..."
bundle exec rails db:migrate

# Start the app
exec "$@"