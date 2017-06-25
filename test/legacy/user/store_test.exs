defmodule Legacy.User.StoreTest do
  use Legacy.RedisCase, async: true
  import Legacy.ExtraAsserts

  alias Legacy.User

  setup do
    now = DateTime.to_iso8601 DateTime.utc_now
    {:ok, now: now}
  end

  describe "Legacy.User.Store.create/1" do
    test "returns the user with a new ID", %{now: now} do
      user = struct %User{}, api_key: "user-store-key-1", created_at: now, updated_at: now
      new_user = Legacy.User.Store.create(user)

      assert new_user.id
      assert new_user.api_key == user.api_key
      assert new_user.created_at == user.created_at
      assert new_user.updated_at == user.updated_at
    end

    test "persists the given user in Redis", %{now: now, redis: redis} do
      user = struct %User{}, api_key: "user-store-key-2", created_at: now, updated_at: now

      %{id: id} = Legacy.User.Store.create(user)

      assert id
      assert Redix.command!(redis, ~w(HGETALL users:#{id}:user)) == [
        "api_key", "user-store-key-2", "created_at", now, "id", "#{id}", "updated_at", now
      ]
    end

    test "maps the user's api key to its ID in Redis", %{redis: redis} do
      user = struct %User{}, api_key: "user-store-key-4"

      %{id: id} = Legacy.User.Store.create(user)

      assert Redix.command!(redis, ~w(GET users:key-to-id:user-store-key-4)) == "#{id}"
    end

    test "errors out if the given user already has an ID" do
      user = struct %User{}, id: 42

      assert_raise RuntimeError, "User already created", fn -> Legacy.User.Store.create(user) end
    end
  end

  describe "Legacy.User.Store.show/1" do
    test "returns nil when no user by ID exists" do
      assert Legacy.User.Store.show(42) == nil
    end

    test "returns the struct for the given user ID", %{now: now} do
      %{id: id} = Legacy.User.Store.create(
        struct %User{}, api_key: "user-store-key-3", created_at: now, updated_at: now
      )

      user = Legacy.User.Store.show(id)

      assert user
      assert user.__struct__ == User
      assert user.id == id
      assert user.api_key == "user-store-key-3"
      assert_date_approx user.created_at, now
      assert_date_approx user.updated_at, now
    end
  end

  describe "Legacy.User.Store.id_for_key/1" do
    test "returns nil when key does not exist" do
      assert Legacy.User.Store.id_for_key("something-something") == nil
    end

    test "returns the user's ID, when the api key does exist" do
      user = Legacy.User.Store.create(struct %User{}, api_key: "user-store-key-5")
      assert Legacy.User.Store.id_for_key("user-store-key-5") == user.id
    end
  end
end
