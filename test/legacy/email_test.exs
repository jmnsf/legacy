defmodule Legacy.EmailTest do
  use ExUnit.Case, async: true
  use Bamboo.Test

  describe "Legacy.email.notify_threshold_reached/3" do
    test "sends threshold notification email" do
      email = Legacy.View.Email.threshold_notification "some@email.com", "a-feature", 0.05
      {:ok, _html} = Legacy.Email.notify_threshold_reached "some@email.com", "a-feature", 0.05

      assert_delivered_email email
    end
  end
end
