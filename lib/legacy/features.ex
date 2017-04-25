defmodule Legacy.Features do
  @moduledoc """
  Helpers for complex operations involving updating and reading Features.
  """

  alias Legacy.Features.Store

  @doc """
  Initialize a feature structure if it doesn't exist, update it with `opts` if
  it does exist. `opts` will also be used to override defaults when initializing.
  """
  def init(name, opts \\ []) do
    defaults = feature_defaults name
    Store.set_missing name, Keyword.drop(defaults, Keyword.keys(opts))
    Store.update name, opts
  end

  defp feature_defaults(name) do
    now = DateTime.to_iso8601 DateTime.utc_now
    [description: name, expire_period: 30, created_at: now, updated_at: now]
  end
end
