use Mix.Config

config :logger,
  backends: [{LoggerFileBackend, :debug_log},],
  level: :debug,
  metadata: [:function]

config :logger, :debug_log,
  path: "./log/debug.log",
  level: :debug
