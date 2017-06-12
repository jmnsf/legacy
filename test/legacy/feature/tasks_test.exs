defmodule Legacy.Feature.TasksTest do
  use Legacy.RedisCase, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney
  use Bamboo.Test, shared: true

  setup_all do
    ExVCR.Config.cassette_library_dir "fixtures/vcr_cassettes"

    now = DateTime.to_unix DateTime.utc_now

    Legacy.Feature.init("feat-task-notify-1") # no alert settings
    Legacy.Feature.init("feat-task-notify-2", alert_endpoint: "http://www.mocky.io/v2/593bcc61100000620dc4774d")
    Legacy.Feature.init("feat-task-notify-3", alert_endpoint: "http://www.mocky.io/v2/593bcbe7100000570dc4774c")
    Legacy.Feature.init("feat-task-notify-4", alert_email: "some@email.com")
    Legacy.Feature.init("feat-task-notify-5", alert_email: "some@email.com", notified: true)

    Legacy.Calls.Store.incr("feat-task-notify-1", now - 86400, {100, 4})
    Legacy.Calls.Store.incr("feat-task-notify-2", now - 86400, {100, 4})
    Legacy.Calls.Store.incr("feat-task-notify-3", now - 86400, {100, 20})
    Legacy.Calls.Store.incr("feat-task-notify-4", now - 86400, {100, 4})
    Legacy.Calls.Store.incr("feat-task-notify-5", now - 86400, {100, 4})

    {:ok, now: now}
  end

  describe "Legacy.Feature.Tasks.notify_thresholds/1" do
    test "sends notifications for features with last day's rate below threshold", %{now: now} do
      use_cassette "notify_threshold_reached_404" do
        email = Legacy.View.Email.threshold_notification "some@email.com", "feat-task-notify-4", 0.05

        Legacy.Feature.Tasks.notify_thresholds(now)

        assert_delivered_email email

        feat2 = Legacy.Feature.Store.show("feat-task-notify-2")
        feat4 = Legacy.Feature.Store.show("feat-task-notify-4")

        assert feat2.notified == false
        assert feat4.notified == true
      end
    end
  end
end
