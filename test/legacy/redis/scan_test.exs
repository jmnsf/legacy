defmodule Legacy.Redis.ScanTest do
  use Legacy.RedisCase, async: true

  alias Legacy.Redis.Scan

  doctest Legacy.Redis.Scan

  # Enumerable Implementation:
  describe "Legacy.Redis.Scan.count/1" do
    test "returns 0 when there are no keys" do
      assert Enum.count(%Scan{match: "scan-none:*"}) == 0
    end

    test "returns the number of keys scanned", %{redis: redis} do
      Redix.command! redis, ~w(INCR scan-1:lel)
      Redix.command! redis, ~w(INCR scan-1:lel1)
      Redix.command! redis, ~w(INCR scan-1:lel2)
      Redix.command! redis, ~w(INCR scan-1:lel3)
      assert Enum.count(%Scan{match: "scan-1:*"}) == 4
    end

    test "considers the `match` argument", %{redis: redis} do
      Redix.command! redis, ~w(INCR scan-2:lel)
      Redix.command! redis, ~w(INCR scan-2:lol)
      Redix.command! redis, ~w(INCR scan-2:lel1)
      Redix.command! redis, ~w(INCR scan-2:lol2)
      assert Enum.count(%Scan{match: "scan-2:lel*"}) == 2
    end
  end

  describe "Legacy.Redis.Scan.member?/2" do
    test "returns false when there are no keys" do
      assert Enum.member?(%Scan{match: "scan-none:*"}, "scan-none:") == false
    end

    test "returns false when the key does not exist", %{redis: redis} do
      Redix.command! redis, ~w(INCR scan-3:lel)
      assert Enum.member?(%Scan{match: "scan-3:*"}, "scan-3:lol") == false
    end

    test "returns true when the key is found", %{redis: redis} do
      Redix.command! redis, ~w(INCR scan-4:lel)
      assert Enum.member?(%Scan{match: "scan-4:*"}, "scan-4:lel") == true
    end

    test "considers the `match` argument", %{redis: redis} do
      Redix.command! redis, ~w(INCR scan-5:lel)
      assert Enum.member?(%Scan{match: "scan-5:lol"}, "scan-5:lel") == false
    end
  end

  def reducer(value, acc), do: [value | acc]

  describe "Legacy.Redis.Scan.reduce/3" do
    test "returns the accumulator when no keys exist" do
      assert Enum.reduce(%Scan{match: "scan-none:*"}, [], &reducer(&1, &2)) == []
    end

    test "applies the given function to all the existing keys", %{redis: redis} do
      Redix.command! redis, ~w(INCR scan-6:lel)
      Redix.command! redis, ~w(INCR scan-6:lol)

      keys = Enum.reduce(%Scan{match: "scan-6:*"}, [], &reducer(&1, &2))

      assert length(keys) == 2
      assert Enum.member? keys, "scan-6:lol"
      assert Enum.member? keys, "scan-6:lel"
    end

    test "considers the `match` argument", %{redis: redis} do
      Redix.command! redis, ~w(INCR scan-7:lel)
      Redix.command! redis, ~w(INCR scan-7:lol)
      assert Enum.reduce(%Scan{match: "scan-7:lel*"}, [], &reducer(&1, &2)) == ["scan-7:lel"]
    end
  end
end
