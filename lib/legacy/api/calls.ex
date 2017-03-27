defmodule Legacy.Api.Calls do
  use Maru.Router

  helpers Legacy.Api.SharedParams

  params do
    use :feature_name
    requires :ts, type: Timestamp
    optional :new, type: Integer
    optional :old, type: Integer
    at_least_one_of [:new, :old]
  end

  desc "registers feature calls"
  post do
    response = case Enum.map([:new, :old], &Map.has_key?(params, &1)) do
      [true, true] ->
        {new, old} = Legacy.Calls.incr(
          params[:feature_name], params[:ts], {params[:new], params[:old]}
        )
        %{new: new, old: old}
      [false, true] ->
        %{old: Legacy.Calls.incr_old(params[:feature_name], params[:ts], params[:old])}
      [true, false] ->
        %{new: Legacy.Calls.incr_new(params[:feature_name], params[:ts], params[:new])}
    end

    conn |> json(%{data: response})
  end
end
