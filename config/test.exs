use Mix.Config

config :logger,
  compile_time_purge_level: :error

config :maru, Legacy.Api,
  http: [port: 8888]

config :legacy, Legacy.Redis,
  endpoint: "redis://localhost/15"

config :legacy, Legacy.Mailer,
  adapter: Bamboo.TestAdapter,
  domain: "sandbox8246b405168e441db2aa4d88533e3f07.mailgun.org"
