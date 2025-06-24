#!/bin/bash
set -e

echo "Waiting for PostgreSQL..."
until pg_isready -h "$DATABASE_HOST" -U "$POSTGRES_USER"; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done

echo "PostgreSQL is up - running migrations"
bundle exec rails db:migrate

echo "Starting Rails server"
exec "$@"
