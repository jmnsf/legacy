defmodule Legacy.User do
  @moduledoc """
  The User structure. A User has and belongs to Projects. It's identified by an
  ID, and possesses an `api_key` for authentication.
  """

  defstruct [
    id: nil,
    api_key: nil,
    created_at: nil,
    updated_at: nil
  ]

  alias Legacy.User.Store

  def register() do
    user = struct %__MODULE__{}, user_defaults()
    user = struct user, api_key: generate_api_key()
    Store.create user
  end

  def find_by_key(api_key) do
    case Store.id_for_key(api_key) do
      nil -> nil
      id -> Store.show(id)
    end
  end

  defp generate_api_key do
    :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
  end

  defp user_defaults do
    now = DateTime.to_iso8601 DateTime.utc_now
    %{
      created_at: now,
      updated_at: now
    }
  end
end
