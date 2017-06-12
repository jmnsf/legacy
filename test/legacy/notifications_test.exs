defmodule Legacy.NotificationTest do
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  use Bamboo.Test, shared: true

  setup_all do
    ExVCR.Config.cassette_library_dir "fixtures/vcr_cassettes"
    :ok
  end

  describe "Legacy.Notification.notify_threshold_reached/1" do
    test "returns an error if the feature has no notification methods" do
      {:error, err} = Legacy.Notification.notify_threshold_reached(%Legacy.Feature{})

      %Legacy.Notification.Error{
        message: msg,
        email_msg: email_msg,
        webhook_msg: webhook_msg
      } = err

      assert msg == "Could not send Notification"
      assert email_msg == "No email to notify."
      assert webhook_msg == "No endpoint to notify."
    end

    test "notifies through email" do
      email = Legacy.View.Email.threshold_notification "some@email.com", "a-name", 0.05

      {:ok, reply} = Legacy.Notification.notify_threshold_reached(
        struct %Legacy.Feature{}, name: "a-name", alert_email: "some@email.com"
      )

      assert_delivered_email email

      [email: {:ok, _}, webhook: {:error, "No endpoint to notify."}] = reply
    end

    test "notifies through webhook" do
      endpoint = "http://www.mocky.io/v2/593bcbe7100000570dc4774c"

      use_cassette "notify_threshold_reached", match_requests_on: [:request_body] do
        {:ok, reply} = Legacy.Notification.notify_threshold_reached(
          struct %Legacy.Feature{}, name: "a-successful-feature", alert_endpoint: endpoint
        )

        [email: {:error, "No email to notify."}, webhook: {:ok, nil}] = reply
      end
    end

    test "notifies through both" do
      email = Legacy.View.Email.threshold_notification "some@email.com", "a-successful-feature", 0.05

      use_cassette "notify_threshold_reached", match_requests_on: [:request_body] do
        {:ok, reply} = Legacy.Notification.notify_threshold_reached(
          struct(
            %Legacy.Feature{},
            name: "a-successful-feature",
            alert_endpoint: "http://www.mocky.io/v2/593bcbe7100000570dc4774c",
            alert_email: "some@email.com"
          )
        )

        assert_delivered_email email

        [email: {:ok, _}, webhook: {:ok, nil}] = reply
      end
    end
  end
end
