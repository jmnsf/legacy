defmodule Maru.Validations.Min do
  def validate_param!(attr_name, value, option) do
    value >= option ||
      raise Maru.Exceptions.Validation, [
        param: attr_name, validator: :length, value: value, option: option
      ]
  end
end
