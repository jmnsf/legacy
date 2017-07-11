defmodule Legacy.UserTest do
  use ExUnit.Case, async: true

  describe "Legacy.User.register/1" do
    test "creates a new user with unique ID and api_key" do
      user = Legacy.User.register()

      assert user
      assert user.id

      stored_user = Legacy.User.Store.show(user.id)

      assert user.api_key
      assert user.api_key == stored_user.api_key
      assert user.id == stored_user.id
    end
  end

  describe "Legacy.User.find_by_key/1" do
    test "returns nil when the user isn't found" do
      assert Legacy.User.find_by_key("lelelelelel") == nil
    end

    test "retursn the user when it exists" do
      user = Legacy.User.register()
      found = Legacy.User.find_by_key(user.api_key)

      assert found
      assert found.id == user.id
    end
  end
end
