defmodule Legacy.AnalysisTest do
  use ExUnit.Case, async: true
  doctest Legacy.Analysis

  describe "Legacy.Analysis.moving_average" do
    test "returns empty array when values is empty" do
      assert Legacy.Analysis.moving_average([], 1, :weighted) == []
    end

    test "returns the values when size is 1" do
      assert Legacy.Analysis.moving_average([1, 2, 3], 1, :weighted) == [1, 2, 3]
    end

    test "calculates the weighted average of the given values by sized sample" do
      assert Legacy.Analysis.moving_average([1, 2, 3, 4, 5, 6, 7], 3, :weighted) ==
        [14 / 6, 20 / 6, 26 / 6, 32 / 6, 38 / 6]
    end
  end
end
