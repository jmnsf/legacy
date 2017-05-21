defmodule Legacy.Api.FeaturesTest do
  import Legacy.ExtraAsserts

  use Legacy.RedisCase, async: true
  use Legacy.ExtendedMaru, for: Legacy.Api.Features

  setup_all do
    now = DateTime.to_unix DateTime.utc_now

    Legacy.Features.init("ft-api-feat-9")
    Legacy.Calls.Store.incr("ft-api-feat-9", now, {5, 5}) # now
    Legacy.Calls.Store.incr("ft-api-feat-9", now - 86400, {2, 3}) # 1 day
    Legacy.Calls.Store.incr("ft-api-feat-9", now - 2 * 86400, {4, 3}) # 2 day
    Legacy.Calls.Store.incr("ft-api-feat-9", now - 3 * 86400, {1, 4}) # 3 day
    Legacy.Calls.Store.incr("ft-api-feat-9", now - 4 * 86400, {5, 4}) # 4 day
    Legacy.Calls.Store.incr("ft-api-feat-9", now - 5 * 86400, {2, 4}) # 5 day
    Legacy.Calls.Store.incr("ft-api-feat-9", now - 6 * 86400, {1, 1}) # 6 day
    Legacy.Calls.Store.incr("ft-api-feat-9", now - 7 * 86400, {3, 1}) # 7 day
    Legacy.Calls.Store.incr("ft-api-feat-9", now - 8 * 86400, {3, 3}) # 8 day
    Legacy.Calls.Store.incr("ft-api-feat-9", now - 9 * 86400, {2, 8}) # 9 day

    {:ok, now: now}
  end

  @moduletag :api
  describe "GET /features/:feature_name" do
    test "returns 404 Not Found when there is no feature with such name" do
      assert_raise Maru.Exceptions.NotFound, fn -> get("/no-name") end
    end

    test "returns the feature as JSON when it does exist" do
      Legacy.Features.init "ft-api-feat-1"
      response = get("/ft-api-feat-1")

      assert response.status == 200

      feature = json_response response

      assert feature["description"] == "ft-api-feat-1"
      assert feature["expire_period"] == 30
      assert_date_approx feature["created_at"], DateTime.utc_now
      assert_date_approx feature["updated_at"], DateTime.utc_now
    end
  end

  describe "GET /features/:feature_name/breakdown" do
    test "returns 404 Not Found for a non-existing feature" do
      assert_raise Maru.Exceptions.NotFound, fn -> get("/no-name/breakdown") end
    end

    test "returns all empty arrays if there is no data" do
      Legacy.Features.init "ft-api-feat-8"
      response = get "/ft-api-feat-8/breakdown"
      json = json_response response

      assert response.status == 200
      assert json["data"]
      assert json["data"]["ts"] == []
      assert json["data"]["rate"] == []
      assert json["data"]["trendline"] == []
    end

    test "returns a timeseries as JSON for the last week's timestamps", %{now: now} do
      json = json_response get "/ft-api-feat-9/breakdown?from=#{now}"

      assert json["data"]["ts"] ==
        for n <- (6..0), do: Utils.GranularTime.base_ts(now - n * 86400)
    end

    test "returns last week's daily new/old rate, in weighted average", %{now: now} do
      json = json_response get "/ft-api-feat-9/breakdown?from=#{now}"

      assert json["data"]["rate"] ==
        Legacy.Analysis.moving_average(
          [3 / 6, 3 / 4, 1 / 2, 2 / 6, 5 / 9, 1 / 5, 4 / 7, 2 / 5, 5 / 10],
          3,
          :weighted
        )
    end

    test "returns a rendered trendline for last week's rate", %{now: now} do
      json = json_response get "/ft-api-feat-9/breakdown?from=#{now}"

      ts = for n <- (6..0), do: Utils.GranularTime.base_ts(now - n * 86400)
      mv_avg = Legacy.Analysis.moving_average(
        [3 / 6, 3 / 4, 1 / 2, 2 / 6, 5 / 9, 1 / 5, 4 / 7, 2 / 5, 5 / 10],
        3,
        :weighted
      )
      regression = Legacy.Analysis.simple_regression_model(ts, mv_avg)

      assert json["data"]["trendline"] == Enum.map(ts, &regression.(&1))
    end
  end

  describe "POST /features" do
    test "errors out if a feature exists with the given name" do
      Legacy.Features.init "ft-api-feat-2"

      res = post_body "/", %{feature_name: "ft-api-feat-2"}

      assert res.status == 409
      assert json_response(res) == %{"errors" => ["A Feature with this name already exists."]}
    end

    test "creates a new feature with the given name & settings" do
      post_body "/", %{feature_name: 'ft-api-feat-3', expire_period: 45}

      feature = Legacy.Features.Store.show 'ft-api-feat-3'
      assert feature
      assert feature[:expire_period] == 45
      assert feature[:description] == "ft-api-feat-3"
      assert_date_approx feature[:created_at], DateTime.utc_now
      assert_date_approx feature[:updated_at], DateTime.utc_now
    end

    test "returns the new feature as JSON" do
      res = post_body "/", %{feature_name: "ft-api-feat-4"}
      json = json_response res

      assert res.status == 201
      assert json["data"]

      feature = json["data"]

      assert feature["description"] == "ft-api-feat-4"
      assert feature["expire_period"] == 30
      assert_date_approx feature["created_at"], DateTime.utc_now
      assert_date_approx feature["updated_at"], DateTime.utc_now
    end
  end

  describe "PATCH /features/:feature_name" do
    test "returns 404 Not Found when there is no feature with such name" do
      assert_raise Maru.Exceptions.NotFound, fn -> patch_body("/no-name", %{}) end
    end

    test "updates the existing feature with the given data" do
      Legacy.Features.init "ft-api-feat-5"

      patch_body "/ft-api-feat-5", %{alert_email: 'an@email.com', expire_period: 45}

      feature = Legacy.Features.Store.show "ft-api-feat-5"
      assert feature[:alert_email] == "an@email.com"
      assert feature[:expire_period] == 45
      assert feature[:description] == "ft-api-feat-5"
    end

    test "returns the updated feature as JSON" do
      Legacy.Features.init "ft-api-feat-6"

      res = patch_body "/ft-api-feat-6", %{alert_endpoint: 'https://endpoint.com/legacy', rate_threshold: 0.1}
      json = json_response res

      assert res.status == 200
      assert json["data"]

      feature = json["data"]

      assert feature["description"] == "ft-api-feat-6"
      assert feature["expire_period"] == 30
      assert feature["rate_threshold"] == 0.1
      assert feature["alert_endpoint"] == "https://endpoint.com/legacy"
      assert_date_approx feature["created_at"], DateTime.utc_now
      assert_date_approx feature["updated_at"], DateTime.utc_now
    end

    test "validates the passed parameters" do
      Legacy.Features.init "ft-api-feat-7"

      assert_raise Maru.Exceptions.Validation, fn ->
        patch_body "/ft-api-feat-7", %{rate_threshold: 1.2}
      end
    end
  end
end
