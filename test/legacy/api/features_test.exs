defmodule Legacy.Api.FeaturesTest do
  import Legacy.ExtraAsserts

  use Legacy.RedisCase, async: true
  use Legacy.ExtendedMaru, for: Legacy.Api.Features

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
