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
        [
          ((1 * 1) + (2 * 2) + (3 * 3)) / 6,
          ((2 * 1) + (3 * 2) + (4 * 3)) / 6,
          ((3 * 1) + (4 * 2) + (5 * 3)) / 6,
          ((4 * 1) + (5 * 2) + (6 * 3)) / 6,
          ((5 * 1) + (6 * 2) + (7 * 3)) / 6
        ]
    end
  end
end
