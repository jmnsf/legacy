defmodule Maru.Exceptions.Unauthorized do
  @moduledoc """
  Raised when the request is unauthorized and trying to access a protected
  resource.
  """

  defexception [:message]

  def message(_e) do
    "Unauthorized"
  end
end
