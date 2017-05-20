defmodule Maru.Validations.Between do
  def validate_param!(attr_name, value, {min, max} = option) do
    value >= min && value <= max ||
      raise Maru.Exceptions.Validation, [
        param: attr_name, validator: :length, value: value, option: option
      ]
  end
end
