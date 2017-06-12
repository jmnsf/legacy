defmodule Legacy.Notification.Error do
  defexception message: "Could not send Notification", email_msg: nil, webhook_msg: nil
end

defimpl String.Chars, for: Legacy.Notification.Error do
  def to_string(%Legacy.Notification.Error{} = err) do
    err.message <> email_error(err) <> webhook_error(err)
  end

  defp email_error(%Legacy.Notification.Error{email_msg: nil}), do: ""
  defp email_error(%Legacy.Notification.Error{email_msg: msg}) do
    "\nEmail error: #{msg}"
  end

  defp webhook_error(%Legacy.Notification.Error{webhook_msg: nil}), do: ""
  defp webhook_error(%Legacy.Notification.Error{webhook_msg: msg}) do
    "\nWebhook error: #{msg}"
  end
end
