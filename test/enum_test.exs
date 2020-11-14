defmodule A.EnumTest do
  use ExUnit.Case, async: true

  doctest A.Enum

  test "A.Enum.sort_uniq/1" do
    assert [] = A.Enum.sort_uniq([])
    assert [1, 2, 3] = A.Enum.sort_uniq([3, 3, 3, 2, 2, 1])
    assert [1, 2, 3, 4, 5] = A.Enum.sort_uniq(5..1)
    assert [1.0, 1, 2.0, 2] = A.Enum.sort_uniq([2, 1, 1.0, 2.0])
  end
end
