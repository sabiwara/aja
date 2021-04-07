defmodule A.OrdMapTest do
  use ExUnit.Case, async: true

  import A, only: [ord: 1]

  doctest A.OrdMap

  defmodule User do
    defstruct name: nil, age: nil
  end

  test "new/1 should accept an A.OrdMap and leave it untouched" do
    ord_map = A.OrdMap.new(b: 2, a: 1, c: 3)
    assert ^ord_map = A.OrdMap.new(ord_map)
  end

  test "new/2" do
    list = [b: 2, a: 1, c: 3]
    vector = A.Vector.new(list)
    ord_map = A.OrdMap.new(list)

    assert ^ord_map = A.OrdMap.new(ord_map, fn x -> x end)
    assert ^ord_map = A.OrdMap.new(vector, fn x -> x end)
    assert ^ord_map = A.OrdMap.new(list, fn x -> x end)
  end

  test "new/0 and new/1 return a constant when empty" do
    assert :erts_debug.same(A.OrdMap.new(), A.OrdMap.new())
    assert :erts_debug.same(A.OrdMap.new([]), A.OrdMap.new())
    assert :erts_debug.same(A.OrdMap.new([]), A.OrdMap.new([]))

    import A

    assert :erts_debug.same(ord(%{}), ord(%{}))
    assert :erts_debug.same(ord(%{}), A.OrdMap.new())
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

  test "stream suspension" do
    ord_map = A.OrdMap.new([{"一", 1}, {"二", 2}, {"三", 3}])

    assert [{{"一", 1}, 0}, {{"二", 2}, 1}] =
             ord_map
             |> Stream.zip(Stream.interval(1))
             |> Enum.take(2)
  end

  test "Enum.count/1" do
    ord_map = A.OrdMap.new(b: 2, a: 1, c: 3)
    assert 3 = Enum.count(ord_map)
    assert 3 = A.Enum.count(ord_map)
  end

  test "in/2" do
    ord_map = A.OrdMap.new(b: 2, a: 1, c: 3)

    assert {:a, 1} in ord_map
    assert {:b, 2} in ord_map
    assert {:c, 3} in ord_map

    refute {:a, 2} in ord_map
    refute {:b, 1} in ord_map
    refute :a in ord_map
  end

  test "inspect" do
    assert "ord(%{})" = A.OrdMap.new() |> inspect()
    assert "ord(%{a: 1, b: 2})" = A.OrdMap.new(a: 1, b: 2) |> inspect()

    assert "ord(%{1 => 1, 2 => 4, 3 => 9})" =
             A.OrdMap.new(1..3, fn i -> {i, i * i} end) |> inspect()

    assert "ord(%{:foo => :atom, 5 => :integer})" =
             A.OrdMap.new([{:foo, :atom}, {5, :integer}]) |> inspect()
  end

  test "from_struct/1" do
    ord_map = %User{name: "John", age: 44} |> A.OrdMap.from_struct()
    expected = A.OrdMap.new(age: 44, name: "John")
    assert ^expected = ord_map
  end

  test "get_and_update/3" do
    ord_map = A.OrdMap.new(a: 1, b: 2)
    message = "the given function must return a two-element tuple or :pop, got: 1"

    assert_raise RuntimeError, message, fn ->
      A.OrdMap.get_and_update(ord_map, :a, fn value -> value end)
    end
  end

  test "get_and_update!/3" do
    ord_map = A.OrdMap.new(a: 1, b: 2)
    message = "the given function must return a two-element tuple or :pop, got: 2"

    assert_raise RuntimeError, message, fn ->
      A.OrdMap.get_and_update!(ord_map, :b, fn value -> value end)
    end
  end
end
