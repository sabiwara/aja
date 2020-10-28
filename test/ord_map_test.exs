defmodule A.OrdMapTest do
  use ExUnit.Case, async: true

  doctest A.OrdMap

  defmodule User do
    defstruct name: nil, age: nil
  end

  test "new/1 should accept an A.OrdMap and leave it untouched" do
    ord_map = A.OrdMap.new(b: 2, a: 1, c: 3)
    assert ^ord_map = A.OrdMap.new(ord_map)
  end

  test "put" do
    assert [{"一", 1}, {"二", 2}, {"三", 3}] =
             A.OrdMap.new()
             |> A.OrdMap.put("一", 1)
             |> A.OrdMap.put("二", 2)
             |> A.OrdMap.put("三", 3)
             |> Enum.to_list()
  end

  test "Enum.to_list/1" do
    expected = [{"一", 1}, {"二", 2}, {"三", 3}]
    assert ^expected = expected |> A.OrdMap.new() |> Enum.to_list()
  end

  test "inspect" do
    assert "#A<ord(%{})>" = A.OrdMap.new() |> inspect()
    assert "#A<ord(%{a: 1, b: 2})>" = A.OrdMap.new(a: 1, b: 2) |> inspect()

    assert "#A<ord(%{1 => 1, 2 => 4, 3 => 9})>" =
             A.OrdMap.new(1..3, fn i -> {i, i * i} end) |> inspect()

    assert "#A<ord(%{:foo => :atom, 5 => :integer})>" =
             A.OrdMap.new([{:foo, :atom}, {5, :integer}]) |> inspect()
  end

  test "iterator/1" do
    ord_map = A.OrdMap.new([{"一", 1}, {"二", 2}])
    iterator = A.OrdMap.iterator(ord_map)

    assert {"一", 1, iterator} = A.OrdMap.next(iterator)
    assert {"二", 2, iterator} = A.OrdMap.next(iterator)
    assert nil == A.OrdMap.next(iterator)

    ord_map = A.OrdMap.new([])
    iterator = A.OrdMap.iterator(ord_map)
    assert nil == A.OrdMap.next(iterator)
  end

  test "from_struct/1" do
    ord_map = %User{name: "John", age: 44} |> A.OrdMap.from_struct()
    expected = A.OrdMap.new(age: 44, name: "John")
    assert ^expected = ord_map
  end
end
