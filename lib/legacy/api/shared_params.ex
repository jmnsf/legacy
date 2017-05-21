defmodule Legacy.Api.SharedParams do
  use Maru.Helper

  params :feature_name do
    requires :feature_name, type: String, regexp: ~r/^[\w_-]+$/
  end

  params :timeseries_range do
    optional :from, type: Timestamp
    optional :periods, type: Integer
    optional :period_size, type: Integer
    optional :period_granularity, type: Atom, values: [:day, :week, :month, :year]
  end
end
