defmodule Legacy.Api.CallsTest do
  use Legacy.RedisCase, async: true
  use Legacy.ExtendedMaru, for: Legacy.Api |> Legacy.Api.Calls

  @moduletag :api

  describe "POST /" do
    test "returns 200 and the new counts" do
      res = post_body "/", %{feature_name: "ft-api-call-1", new: 2, old: 5, ts: 1483228799000}

      assert res.status == 200
      assert json_response(res) == %{"data" => %{"new" => 2, "old" => 5}}
    end

    test "increments calls for the given timestamp" do
      post_body "/", %{feature_name: "ft-api-call-2", new: 5, old: 2, ts: 1483228799000}

      assert Legacy.Calls.get("ft-api-call-2", 1483228799) == {5, 2}
    end

    test "it increments and returns single calls" do
      assert json_response(
        post_body "/", %{feature_name: "ft-api-call-3", new: 18, ts: 1483228799000}
      ) == %{"data" => %{"new" => 18}}

      assert json_response(
        post_body "/", %{feature_name: "ft-api-call-3", old: 12, ts: 1483228799000}
      ) == %{"data" => %{"old" => 12}}

      assert Legacy.Calls.get("ft-api-call-3", 1483228799) == {18, 12}
    end

    test "validates needed parameters" do
      assert_raise Maru.Exceptions.InvalidFormat, ~r/feature_name/, fn ->
        post_body("/", %{new: 15, ts: 1483228799000})
      end

      assert_raise Maru.Exceptions.Validation, ~r/feature_name/, fn ->
        post_body("/", %{new: 15, ts: 1483228799000, feature_name: 'bang!'})
      end

      assert_raise Maru.Exceptions.InvalidFormat, ~r/ts/, fn ->
        post_body("/", %{new: 15, feature_name: 'valid'})
      end

      assert_raise Maru.Exceptions.Validation, ~r/new.+old/, fn ->
        post_body("/", %{ts: 1483228799000, feature_name: 'valid'})
      end
    end
  end
end

defmodule Legacy.Api.NestedCallsTest do
  use Legacy.RedisCase, async: true
  use Legacy.ExtendedMaru, for: Legacy.Api.Features |> Legacy.Api.Calls

  @moduletag :api

  describe "POST /features/:feature_name/calls" do
    test "works like rooted call, extracting name from route" do
      # REVIEW: There's no way to test route params on nested routers, afaik
      res = post_body "/?feature_name=ft-api-call-4", %{new: 2, old: 5, ts: 1483228799000}

      assert res.status == 200
      assert json_response(res) == %{"data" => %{"new" => 2, "old" => 5}}
      assert Legacy.Calls.get("ft-api-call-4", 1483228799) == {2, 5}
    end
  end
end
