# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :legacy, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:legacy, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"

config :logger,
  backends: [:console],
  compile_time_purge_level: :info

config :maru, Legacy.Api,
  http: [port: 80]

config :legacy, Legacy.Redis,
  endpoint: "redis://localhost/14"

config :legacy, Legacy.Mailer,
  adapter: Bamboo.MailgunAdapter,
  api_key: System.get_env("MAIGUN_API_KEY"),
  domain: "legacy.jmnsf.com"

config :legacy, Legacy.Email,
  from: "Legacy <hello@legacy.jmnsf.com>"

import_config "#{Mix.env}.exs"
