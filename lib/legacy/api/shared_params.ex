defmodule Legacy.Api.SharedParams do
  use Maru.Helper

  params :feature_name do
    requires :feature_name, type: String, regexp: ~r/^[\w_-]+$/
  end
end
