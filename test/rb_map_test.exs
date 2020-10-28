defmodule A.RBMapTest do
  use ExUnit.Case, async: true

  doctest A.RBMap

  defmodule User do
    defstruct name: nil, age: nil
  end

  test "new/1 should accept an A.RBMap and leave it untouched" do
    rb_map = A.RBMap.new(%{1 => 1, 2 => 4, 3 => 9})
    assert ^rb_map = A.RBMap.new(rb_map)
  end

  test "put" do
    assert [{1, "一"}, {2, "二"}, {3, "三"}] =
             A.RBMap.new()
             |> A.RBMap.put(3, "三")
             |> A.RBMap.put(1, "一")
             |> A.RBMap.put(2, "二")
             |> Enum.to_list()
  end

  test "Enum.to_list/1" do
    expected = [{1, "一"}, {2, "二"}, {3, "三"}]
    assert ^expected = expected |> A.RBMap.new() |> Enum.to_list()
  end

  test "inspect" do
    assert "#A.RBMap<%{}>" = A.RBMap.new() |> inspect()
    assert "#A.RBMap<%{a: 1, b: 2}>" = A.RBMap.new(b: 2, a: 1) |> inspect()

    assert "#A.RBMap<%{1 => 1, 2 => 4, 3 => 9}>" =
             A.RBMap.new(1..3, fn i -> {i, i * i} end) |> inspect()

    assert "#A.RBMap<%{5 => :integer, :foo => :atom}>" =
             A.RBMap.new([{:foo, :atom}, {5, :integer}]) |> inspect()
  end

  test "iterator/1" do
    map = A.RBMap.new([{"一", 1}, {"二", 2}])
    iterator = A.RBMap.iterator(map)

    assert {{"一", 1}, iterator} = A.RBMap.next(iterator)
    assert {{"二", 2}, iterator} = A.RBMap.next(iterator)
    assert nil == A.RBMap.next(iterator)

    map = A.RBMap.new([])
    iterator = A.RBMap.iterator(map)
    assert nil == A.RBMap.next(iterator)
  end

  test "from_struct/1" do
    rb_map = %User{name: "John", age: 44} |> A.RBMap.from_struct()
    expected = A.RBMap.new(age: 44, name: "John")
    assert ^expected = rb_map
  end
end
