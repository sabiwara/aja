defmodule Aja.ListTest do
  use ExUnit.Case, async: true

  doctest Aja.List

  describe "Aja.List" do
    test "Aja.List.repeat/2" do
      counter = :counters.new(1, [])

      fun = fn ->
        :counters.add(counter, 1, 1)
        :counters.get(counter, 1)
      end

      assert [] = Aja.List.repeat(fun, 0)
      assert [1, 2, 3, 4, 5] = Aja.List.repeat(fun, 5)
      assert [6, 7, 8, 9, 10, 11, 12, 13, 14, 15] = Aja.List.repeat(fun, 10)

      assert_raise FunctionClauseError, fn -> Aja.List.repeat(fun, -1) end
    end
  end
end
