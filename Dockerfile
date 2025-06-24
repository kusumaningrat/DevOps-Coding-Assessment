ARG RUBY_VERSION=3.3.0
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl libjemalloc2 libvips postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Accept RAILS_ENV from build args or compose
ARG RAILS_ENV=development
ENV RAILS_ENV=$RAILS_ENV
ENV BUNDLE_PATH="/usr/local/bundle"

# Throw-away build stage
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy application code
COPY . .

# Precompile bootsnap (regardless of env)
RUN bundle exec bootsnap precompile app/ lib/

# Only precompile assets in production
RUN if [ "$RAILS_ENV" = "production" ]; then \
      SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile; \
    fi

FROM base

# Copy built artifacts: gems, app code
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Create and switch to non-root user
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp

# Entrypoint
COPY entrypoint.sh /rails/entrypoint.sh
RUN chmod +x /rails/entrypoint.sh
USER 1000:1000
ENTRYPOINT ["/rails/entrypoint.sh"]

# Expose port and run Rails server
EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]