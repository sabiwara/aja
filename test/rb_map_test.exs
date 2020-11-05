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

  test "stream suspension" do
    rb_map = A.RBMap.new(%{1 => "一", 2 => "二", 3 => "三"})

    assert [{{1, "一"}, 0}, {{2, "二"}, 1}] =
             rb_map
             |> Stream.zip(Stream.interval(1))
             |> Enum.take(2)
  end

  test "Enum.count/1" do
    rb_map = A.RBMap.new(%{1 => 1, 2 => 4, 3 => 9})
    assert 3 = Enum.count(rb_map)
  end

  test "in/2" do
    rb_map = A.RBMap.new(%{1 => 1, 2 => 4, 3 => 9})

    assert {1, 1} in rb_map
    assert {2, 4} in rb_map
    assert {3, 9} in rb_map
    assert {1.0, 1} in rb_map

    refute {1, 1.0} in rb_map
    refute {1, 2} in rb_map
    refute {2, 2} in rb_map
    refute 1 in rb_map
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

    assert {"一", 1, iterator} = A.RBMap.next(iterator)
    assert {"二", 2, iterator} = A.RBMap.next(iterator)
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
