import Config

# Configure the test environment
config :scenic_mcp,
  # Use a different port for tests to avoid conflicts
  port: 9998,
  # Don't auto-start in test mode
  auto_start: false

# Reduce log level in tests
config :logger,
  level: :warning

# Configure ExCoveralls
config :excoveralls,
  highlight_files: true,
  minimum_coverage: 80