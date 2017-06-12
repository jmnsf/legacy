defmodule Legacy.WebhookTest do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  setup_all do
    ExVCR.Config.cassette_library_dir "fixtures/vcr_cassettes"
    :ok
  end

  describe "Legacy.Webhook.notify_threshold_reached/3" do
    test "sends a threshold reached webhook to the given endpoint" do
      use_cassette "notify_threshold_reached", match_requests_on: [:request_body] do
        res = Legacy.Webhook.notify_threshold_reached(
          "http://www.mocky.io/v2/593bcbe7100000570dc4774c", "a-successful-feature", 0.05
        )

        assert res == {:ok, nil}
      end
    end

    test "errors out if the response is non 200" do
      use_cassette "notify_threshold_reached_404", match_requests_on: [:request_body] do
        res = Legacy.Webhook.notify_threshold_reached(
          "http://www.mocky.io/v2/593bcc61100000620dc4774d", "a-404-feature", 0.10
        )

        assert res == {:error, "Non 200 status returned from endpoint: 404 - \"\""}
      end
    end

    test "errors out if there's a general error" do
      use_cassette "notify_threshold_reached_error", match_requests_on: [:request_body] do
        res = Legacy.Webhook.notify_threshold_reached(
          "http://www.bad-endpoint.com/trash", "a-bad-feature", 0.15
        )

        assert res == {:error, "HTTP error during request: id - , reason - nxdomain"}
      end
    end
  end
end
