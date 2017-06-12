defmodule Legacy.View.EmailTest do
  use ExUnit.Case

  test "Legacy.View.Email.threshold_notification/2" do
    email = Legacy.View.Email.threshold_notification "some@email.com", "a-feature", 0.05

    assert email.from == "Legacy <hello@legacy.jmnsf.com>"
    assert email.to == "some@email.com"
    assert email.subject == "Threshold reached for a-feature"
    assert email.html_body =~ ~r/html/
    assert email.html_body =~ ~r/call rate.+a-feature.+threshold of 0.05/
    assert email.text_body =~ ~r/call rate.+a-feature.+threshold of 0.05/
  end
end
