defmodule A.ArrayTest do
  use ExUnit.Case, async: true

  doctest A.Array

  test "new/1 should accept an array and leave it untouched" do
    array = A.Array.new([1, 2, 3, 5, 8])
    assert ^array = A.Array.new(array)
  end

  test "improved errors" do
    assert_raise ArgumentError, "fixed? must be a boolean, got: nil", fn ->
      A.Array.new([1, 2, 3], fixed?: nil)
    end

    fixed = A.Array.new([1, 2, 3, 5, 8], fixed?: true)

    assert_raise ArgumentError, "index must be a non-negative integer, got: -1", fn ->
      A.Array.get(fixed, -1)
    end

    assert_raise ArgumentError, "index must be a non-negative integer, got: -1", fn ->
      A.Array.set(fixed, -1, 11)
    end

    assert_raise ArgumentError, "index must be a non-negative integer, got: :atom", fn ->
      A.Array.set(fixed, :atom, 11)
    end

    assert_raise ArgumentError,
                 "cannot access index above fixed size, expected index < 5, got: 5",
                 fn -> A.Array.get(fixed, 5) end

    assert_raise ArgumentError,
                 "cannot access index above fixed size, expected index < 5, got: 5",
                 fn -> A.Array.set(fixed, 5, 11) end
  end

  test "enum protocol" do
    array = A.Array.new([1, 2, 3, 5, 8])

    1 = Enum.at(array, 0)
    5 = Enum.at(array, 3)
    [2, 3] = Enum.slice(array, 1..2)
    [2, 3, 5, 8] = Enum.slice(array, 1..100)
    [2, 5] = Enum.drop_every(array, 2)
  end

  test "collectable protocol" do
    array = A.Array.new([1, 2, 3])

    new_array = [5, 8] |> Enum.into(array)

    assert 8 = A.Array.get(new_array, 4)

    assert [1, 2, 3, 5, 8] = new_array |> Enum.to_list()
  end

  test "streams" do
    assert [1, 4, 9] = A.Array.new(1..3) |> Stream.map(&(&1 * &1)) |> Enum.to_list()

    assert A.Array.new([1, 4, 9]) ==
             A.Array.new(1..3) |> Stream.map(&(&1 * &1)) |> Enum.into(A.Array.new())
  end
end
