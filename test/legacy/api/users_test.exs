defmodule Legacy.Api.UsersTest do
  use ExUnit.Case, async: true
  use Legacy.ExtendedMaru, for: Legacy.Api.Users

  @moduletag :api
  describe "POST /users" do
    test "returns 201 and the created user" do
      res = post("/users")

      assert res.status == 201

      json = json_response res
      assert json["data"]
      assert json["data"]["id"]
      assert json["data"]["api_key"]
    end
  end
end
