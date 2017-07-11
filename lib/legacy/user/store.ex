defmodule Legacy.User.Store do
  @moduledoc """
  Methods for interacting with a Redis User store.

  ### Keys:
  * `users:id-counter`: Atomic increment for generating unique User IDs.
  * `users:key-to-id:<key>`: Stores the user ID for an API key.
  * `users:<user-id>:user`: Hash that stores a User's attributes.
  """

  import Legacy.Redis

  alias Legacy.User

  @doc """
  Creates a new user. Assigns a new unique ID for a user and persists the user's
  data.

  TODO: make sure there are no collisions in the API key.
  """
  @spec create(%User{}) :: %User{}
  def create(%User{id: id}) when not is_nil(id), do: raise "User already created"
  def create(%User{id: nil} = user) do
    user = struct user, id: generate_id()
    redis([
      make_cmd(:hmset, user_key(user.id), user),
      ~w(SET users:key-to-id:#{user.api_key} #{user.id})
    ])
    user
  end

  @spec show(String.t) :: %User{} | nil
  def show(id) do
    attrs = redis_map(user_key(id), fn key, value -> fix_value_type(key, value) end)

    case map_size(attrs) do
      0 -> nil
      _ -> struct(%User{}, attrs)
    end
  end

  def id_for_key(api_key) do
    case redis(~w(GET users:key-to-id:#{api_key})) do
      nil -> nil
      id -> fix_value_type(:id, id)
    end
  end

  defp generate_id, do: redis(~w(INCR users:id-counter))

  defp base_user_key(id), do: "users:#{id}"
  defp user_key(id), do: "#{base_user_key(id)}:user"

  defp fix_value_type(:id, id), do: elem(Integer.parse(id), 0)
  defp fix_value_type(:created_at, value), do: fix_date_value(value)
  defp fix_value_type(:updated_at, value), do: fix_date_value(value)
  defp fix_value_type(_, value), do: value

  defp fix_date_value(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, date, _offset} -> date
      {:error, err} -> raise "Bad date format. Got #{date_string}, error: #{err}"
    end
  end
end
