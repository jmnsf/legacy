defmodule Legacy.Feature do
  @moduledoc """
  Helpers for complex operations involving updating and reading Features.

  In lieu of a model schema, the Feature has these fields:

  * description: The feature name by default, but can be any descriptive text for the feature.
  * expire_period: How many days of historical data to keep for this feature,
  and how many days of inactivity in this feature until it is deleted.
  * rate_threshold: The desired rate of old/new calls for the feature. Defaults to 5%.
  * alert_endpoint: When defined, this endpoint will receive a webhook when the `rate_threshold` is
  reached.
  * alert_email: Same as `alert_endpoint` but will receive an email at this address.
  * notified: Whether this feature has triggered a rate notification.
  * created_at: When the feature was first seen.
  * updated_at: Last time the feature data was edited.

  """

  defstruct [
    name: nil,
    description: nil,
    expire_period: 30,
    rate_threshold: 0.05,
    notified: false,
    alert_email: nil,
    alert_endpoint: nil,
    created_at: nil,
    updated_at: nil
  ]

  alias Legacy.Feature.Store

  @doc """
  Initialize a feature structure if it doesn't exist, update it with `opts` if
  it does exist. `opts` will also be used to override defaults when initializing.
  """
  @spec init(String.t, keyword) :: String.t
  def init(name, opts \\ []) do
    default_feature = struct %__MODULE__{}, feature_defaults(name)

    Store.set_missing(
      name,
      Keyword.drop(to_clean_list(default_feature), Keyword.keys(opts))
    )
    Store.update name, opts
  end

  @doc """
  Returns a stream that yields all features in the DB. It _might_ return the
  same feature more than once.
  """
  @spec stream_all_features :: Stream.t
  def stream_all_features do
    Store.stream_all_feature_names
    |> Stream.map(&Store.show(&1))
  end

  defp feature_defaults(name) do
    now = DateTime.to_iso8601 DateTime.utc_now
    [
      description: name,
      created_at: now,
      updated_at: now,
    ]
  end

  defp to_clean_list(feature) do
    Map.to_list(feature)
    |> Enum.filter(fn {key, value} -> !is_nil(value) && key != :__struct__ end)
  end
end
