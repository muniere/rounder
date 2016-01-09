use Mix.Config

config :logger, :console,
  level: :debug,
  format: "[$level] $message\n",
  colors: [
    enabled: true,
    debug:   :green,
    info:    :cyan,
    warn:    :yellow,
    error:   :red
  ]
