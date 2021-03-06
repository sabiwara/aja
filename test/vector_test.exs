defmodule A.VectorTest do
  use ExUnit.Case, async: true

  import A, only: [vec: 1]

  doctest A.Vector

  import A.TestHelpers

  test "new/0 and new/1 return a constant when empty" do
    assert :erts_debug.same(A.Vector.new(), A.Vector.new())
    assert :erts_debug.same(A.Vector.new([]), A.Vector.new())
    assert :erts_debug.same(A.Vector.new([]), A.Vector.new([]))
  end

  test "at/2" do
    range = 0..500
    vector = A.Vector.new(range)

    result = for i <- range, do: A.Vector.at(vector, i)

    assert Enum.to_list(range) == result
  end

  test "replace_at/2" do
    range = 0..499
    vector = List.duplicate(nil, Enum.count(range)) |> A.Vector.new()

    result =
      Enum.reduce(range, vector, fn i, vec ->
        A.Vector.replace_at(vec, i, i)
      end)

    assert A.Vector.new(range) == result
  end

  test "update_at/2" do
    range = 0..499
    vector = A.Vector.new(range)

    result =
      Enum.reduce(range, vector, fn i, vec ->
        A.Vector.update_at(vec, i, &(&1 + 50))
      end)

    assert A.Vector.new(50..549) == result
  end

  test "append/2" do
    range = 1..5_000

    vector =
      Enum.reduce(range, A.Vector.new(), fn value, vec ->
        A.Vector.append(vec, value)
      end)

    expected = A.Vector.new(range)
    assert expected == vector
  end

  test "concat/2" do
    assert A.Vector.new() == A.Vector.new() |> A.Vector.concat([])

    assert A.Vector.new(1..5) == A.Vector.new(1..5) |> A.Vector.concat([])
    assert A.Vector.new(6..10) == A.Vector.new() |> A.Vector.concat(6..10)

    assert A.Vector.new(1..10) == A.Vector.new(1..5) |> A.Vector.concat(6..10)
    assert A.Vector.new(1..20) == A.Vector.new(1..10) |> A.Vector.concat(11..20)
    assert A.Vector.new(1..100) == A.Vector.new(1..50) |> A.Vector.concat(51..100)
    assert A.Vector.new(1..1000) == A.Vector.new(1..500) |> A.Vector.concat(501..1000)
  end

  test "pop_last!/1" do
    range = 1..5_000

    vector =
      Enum.reduce(range, A.Vector.new(), fn value, vec ->
        new_vec = A.Vector.append(vec, value)
        assert {^value, ^vec} = A.Vector.pop_last!(new_vec)
        new_vec
      end)

    expected = A.Vector.new(range)
    assert expected == vector
  end

  test "duplicate/2" do
    for i <-
          Enum.concat(0..255, [256, 257, 274, 500, 512, 513, 4353, 5_000, 8193, 50_000, 500_000]) do
      vector = A.Vector.duplicate(nil, i)
      list = List.duplicate(nil, i)

      assert i == A.Vector.size(vector)
      assert list == A.Vector.to_list(vector)
    end
  end

  test "reverse/1" do
    assert A.Vector.new() == A.Vector.new() |> A.Vector.reverse()
    assert A.Vector.new(5..1) == A.Vector.new(1..5) |> A.Vector.reverse()
    assert A.Vector.new(50..1) == A.Vector.new(1..50) |> A.Vector.reverse()
    assert A.Vector.new(500..1) == A.Vector.new(1..500) |> A.Vector.reverse()
  end

  test "take_while/2" do
    {gte_zero?, pop_args} = spy_callback(&(&1 >= 0))

    assert A.Vector.new() == A.Vector.new() |> A.Vector.take_while(gte_zero?)
    assert [] == pop_args.()

    assert A.Vector.new(5..0) == A.Vector.new(5..0) |> A.Vector.take_while(gte_zero?)
    assert [5, 4, 3, 2, 1, 0] == pop_args.()

    assert A.Vector.new(50..0) == A.Vector.new(50..0) |> A.Vector.take_while(gte_zero?)
    assert Enum.to_list(50..0) == pop_args.()

    assert A.Vector.new(500..0) == A.Vector.new(500..0) |> A.Vector.take_while(gte_zero?)
    assert Enum.to_list(500..0) == pop_args.()

    assert A.Vector.new(5..0) == A.Vector.new(5..-5) |> A.Vector.take_while(gte_zero?)
    assert [5, 4, 3, 2, 1, 0, -1] == pop_args.()

    assert A.Vector.new(50..0) == A.Vector.new(50..-50) |> A.Vector.take_while(gte_zero?)
    assert Enum.to_list(50..-1) == pop_args.()

    assert A.Vector.new(500..0) == A.Vector.new(500..-500) |> A.Vector.take_while(gte_zero?)
    assert Enum.to_list(500..-1) == pop_args.()

    assert A.Vector.new() == A.Vector.new([-1, 0, 1]) |> A.Vector.take_while(gte_zero?)

    assert Enum.to_list([-1]) == pop_args.()
  end

  test "drop_while/2" do
    {gte_zero?, pop_args} = spy_callback(&(&1 >= 0))

    assert A.Vector.new() == A.Vector.new() |> A.Vector.drop_while(gte_zero?)
    assert [] == pop_args.()

    assert A.Vector.new() == A.Vector.new(5..0) |> A.Vector.drop_while(gte_zero?)
    assert [5, 4, 3, 2, 1, 0] == pop_args.()

    assert A.Vector.new() == A.Vector.new(50..0) |> A.Vector.drop_while(gte_zero?)
    assert Enum.to_list(50..0) == pop_args.()

    assert A.Vector.new() == A.Vector.new(500..0) |> A.Vector.drop_while(gte_zero?)
    assert Enum.to_list(500..0) == pop_args.()

    assert A.Vector.new([-1, -2, -3, -4, -5]) ==
             A.Vector.new(5..-5) |> A.Vector.drop_while(gte_zero?)

    assert [5, 4, 3, 2, 1, 0, -1] == pop_args.()

    assert A.Vector.new(-1..-50) == A.Vector.new(50..-50) |> A.Vector.drop_while(gte_zero?)
    assert Enum.to_list(50..-1) == pop_args.()

    assert A.Vector.new(-1..-500) == A.Vector.new(500..-500) |> A.Vector.drop_while(gte_zero?)
    assert Enum.to_list(500..-1) == pop_args.()

    assert A.Vector.new([-1, 0, 1]) == A.Vector.new([-1, 0, 1]) |> A.Vector.drop_while(gte_zero?)

    assert Enum.to_list([-1]) == pop_args.()
  end

  test "split_while/2" do
    {gte_zero?, pop_args} = spy_callback(&(&1 >= 0))

    assert {A.Vector.new(), A.Vector.new()} == A.Vector.new() |> A.Vector.split_while(gte_zero?)
    assert [] == pop_args.()

    assert {A.Vector.new(5..0), A.Vector.new()} ==
             A.Vector.new(5..0) |> A.Vector.split_while(gte_zero?)

    assert [5, 4, 3, 2, 1, 0] == pop_args.()

    assert {A.Vector.new(50..0), A.Vector.new()} ==
             A.Vector.new(50..0) |> A.Vector.split_while(gte_zero?)

    assert Enum.to_list(50..0) == pop_args.()

    assert {A.Vector.new(500..0), A.Vector.new()} ==
             A.Vector.new(500..0) |> A.Vector.split_while(gte_zero?)

    assert Enum.to_list(500..0) == pop_args.()

    assert {A.Vector.new(5..0), A.Vector.new(-1..-5)} ==
             A.Vector.new(5..-5) |> A.Vector.split_while(gte_zero?)

    assert [5, 4, 3, 2, 1, 0, -1] == pop_args.()

    assert {A.Vector.new(50..0), A.Vector.new(-1..-50)} ==
             A.Vector.new(50..-50) |> A.Vector.split_while(gte_zero?)

    assert Enum.to_list(50..-1) == pop_args.()

    assert {A.Vector.new(500..0), A.Vector.new(-1..-500)} ==
             A.Vector.new(500..-500) |> A.Vector.split_while(gte_zero?)

    assert Enum.to_list(500..-1) == pop_args.()

    assert {A.Vector.new(), A.Vector.new([-1, 0, 1])} ==
             A.Vector.new([-1, 0, 1]) |> A.Vector.split_while(gte_zero?)

    assert Enum.to_list([-1]) == pop_args.()
  end

  test "intersperse/2" do
    assert A.Vector.new() == A.Vector.new() |> A.Vector.intersperse(0)

    assert A.Vector.new([1, 0, 2, 0, 3, 0, 4, 0, 5]) ==
             A.Vector.new(1..5) |> A.Vector.intersperse(0)

    assert Enum.intersperse(1..50, 0) |> A.Vector.new() ==
             A.Vector.new(1..50) |> A.Vector.intersperse(0)

    assert Enum.intersperse(1..500, 0) |> A.Vector.new() ==
             A.Vector.new(1..500) |> A.Vector.intersperse(0)
  end

  test "map_intersperse/3" do
    {add_one, pop_args} = spy_callback(&(&1 + 1))

    assert A.Vector.new() == A.Vector.new() |> A.Vector.map_intersperse(0, add_one)
    assert [] == pop_args.()

    assert A.Vector.new([2, 0, 3, 0, 4, 0, 5, 0, 6]) ==
             A.Vector.new(1..5) |> A.Vector.map_intersperse(0, add_one)

    assert [1, 2, 3, 4, 5] == pop_args.()

    assert Enum.intersperse(2..51, 0) |> A.Vector.new() ==
             A.Vector.new(1..50) |> A.Vector.map_intersperse(0, add_one)

    assert Enum.to_list(1..50) == pop_args.()

    assert Enum.intersperse(2..501, 0) |> A.Vector.new() ==
             A.Vector.new(1..500) |> A.Vector.map_intersperse(0, add_one)

    assert Enum.to_list(1..500) == pop_args.()
  end

  test "map/2" do
    {add_one, pop_args} = spy_callback(&(&1 + 1))

    assert A.Vector.new() == A.Vector.new() |> A.Vector.map(add_one)
    assert [] == pop_args.()

    assert A.Vector.new(2..6) == A.Vector.new(1..5) |> A.Vector.map(add_one)
    assert [1, 2, 3, 4, 5] == pop_args.()

    assert A.Vector.new(2..51) == A.Vector.new(1..50) |> A.Vector.map(add_one)
    assert Enum.to_list(1..50) == pop_args.()

    assert A.Vector.new(2..501) == A.Vector.new(1..500) |> A.Vector.map(add_one)
    assert Enum.to_list(1..500) == pop_args.()
  end

  test "filter/2" do
    odd? = &(rem(&1, 2) == 0)
    {spy, pop_args} = spy_callback(odd?)

    assert A.Vector.new() == A.Vector.new() |> A.Vector.filter(spy)
    assert [] == pop_args.()

    assert A.Vector.new([2, 4]) == A.Vector.new(1..5) |> A.Vector.filter(spy)
    assert [1, 2, 3, 4, 5] == pop_args.()

    assert Enum.filter(1..50, odd?) |> A.Vector.new() ==
             A.Vector.new(1..50) |> A.Vector.filter(spy)

    assert Enum.to_list(1..50) == pop_args.()

    assert Enum.filter(1..500, odd?) |> A.Vector.new() ==
             A.Vector.new(1..500) |> A.Vector.filter(spy)

    assert Enum.to_list(1..500) == pop_args.()
  end

  test "reject/2" do
    odd? = &(rem(&1, 2) == 0)
    {spy, pop_args} = spy_callback(odd?)

    assert A.Vector.new() == A.Vector.new() |> A.Vector.reject(spy)
    assert [] == pop_args.()

    assert A.Vector.new([1, 3, 5]) == A.Vector.new(1..5) |> A.Vector.reject(spy)
    assert [1, 2, 3, 4, 5] == pop_args.()

    assert Enum.reject(1..50, odd?) |> A.Vector.new() ==
             A.Vector.new(1..50) |> A.Vector.reject(spy)

    assert Enum.to_list(1..50) == pop_args.()

    assert Enum.reject(1..500, odd?) |> A.Vector.new() ==
             A.Vector.new(1..500) |> A.Vector.reject(spy)

    assert Enum.to_list(1..500) == pop_args.()
  end

  test "split_with/2" do
    odd? = &(rem(&1, 2) == 0)
    {spy, pop_args} = spy_callback(odd?)

    assert {A.Vector.new(), A.Vector.new()} == A.Vector.new() |> A.Vector.split_with(spy)
    assert [] == pop_args.()

    assert {A.Vector.new([2, 4]), A.Vector.new([1, 3, 5])} ==
             A.Vector.new(1..5) |> A.Vector.split_with(spy)

    assert [1, 2, 3, 4, 5] == pop_args.()

    {list1, list2} = Enum.split_with(1..50, odd?)

    assert {A.Vector.new(list1), A.Vector.new(list2)} ==
             A.Vector.new(1..50) |> A.Vector.split_with(spy)

    assert Enum.to_list(1..50) == pop_args.()

    {list1, list2} = Enum.split_with(1..500, odd?)

    assert {A.Vector.new(list1), A.Vector.new(list2)} ==
             A.Vector.new(1..500) |> A.Vector.split_with(spy)

    assert Enum.to_list(1..500) == pop_args.()
  end

  test "with_index/2" do
    assert A.Vector.new() == A.Vector.new() |> A.Vector.with_index()
    assert A.Vector.new() == A.Vector.new() |> A.Vector.with_index(77)

    assert A.Vector.new(a: 0, b: 1) == A.Vector.new([:a, :b]) |> A.Vector.with_index()
    assert A.Vector.new(a: 77, b: 78) == A.Vector.new([:a, :b]) |> A.Vector.with_index(77)
    assert A.Vector.new(a: -77, b: -76) == A.Vector.new([:a, :b]) |> A.Vector.with_index(-77)

    assert Enum.with_index(1..50) |> A.Vector.new() ==
             A.Vector.new(1..50) |> A.Vector.with_index()

    assert Enum.with_index(1..50, 77) |> A.Vector.new() ==
             A.Vector.new(1..50) |> A.Vector.with_index(77)

    assert Enum.with_index(1..500) |> A.Vector.new() ==
             A.Vector.new(1..500) |> A.Vector.with_index()

    assert Enum.with_index(1..500, 77) |> A.Vector.new() ==
             A.Vector.new(1..500) |> A.Vector.with_index(77)
  end

  test "zip/2" do
    assert A.Vector.new() == A.Vector.zip(A.Vector.new(), A.Vector.new(1..1000))
    assert A.Vector.new() == A.Vector.zip(A.Vector.new(1..1000), A.Vector.new())

    assert A.Vector.new(Enum.zip(-1..-5, 1..5)) ==
             A.Vector.zip(A.Vector.new(-1..-1000), A.Vector.new(1..5))

    assert A.Vector.new(Enum.zip(1..5, -1..-5)) ==
             A.Vector.zip(A.Vector.new(1..5), A.Vector.new(-1..-1000))

    assert A.Vector.new(Enum.zip(1..5, -1..-5)) ==
             A.Vector.zip(A.Vector.new(1..5), A.Vector.new(-1..-5))

    assert A.Vector.new(Enum.zip(-1..-50, 1..50)) ==
             A.Vector.zip(A.Vector.new(-1..-1000), A.Vector.new(1..50))

    assert A.Vector.new(Enum.zip(1..50, -1..-50)) ==
             A.Vector.zip(A.Vector.new(1..50), A.Vector.new(-1..-1000))

    assert A.Vector.new(Enum.zip(-1..-500, 1..500)) ==
             A.Vector.zip(A.Vector.new(-1..-1000), A.Vector.new(1..500))

    assert A.Vector.new(Enum.zip(1..500, -1..-500)) ==
             A.Vector.zip(A.Vector.new(1..500), A.Vector.new(-1..-1000))
  end

  test "zip_with/3" do
    assert A.Vector.new() == A.Vector.zip_with(A.Vector.new(), A.Vector.new(1..1000), &-/2)
    assert A.Vector.new() == A.Vector.zip_with(A.Vector.new(1..1000), A.Vector.new(), &-/2)

    assert A.Vector.new(1..5, &(&1 * 2)) ==
             A.Vector.zip_with(A.Vector.new(1..1000), A.Vector.new(-1..-5), &-/2)

    assert A.Vector.new(1..5, &(&1 * 2)) ==
             A.Vector.zip_with(A.Vector.new(1..5), A.Vector.new(-1..-1000), &-/2)

    assert A.Vector.new(1..5, &(&1 * 2)) ==
             A.Vector.zip_with(A.Vector.new(1..5), A.Vector.new(-1..-5), &-/2)

    assert A.Vector.new(1..50, &(&1 * 2)) ==
             A.Vector.zip_with(A.Vector.new(1..1000), A.Vector.new(-1..-50), &-/2)

    assert A.Vector.new(1..50, &(&1 * 2)) ==
             A.Vector.zip_with(A.Vector.new(1..50), A.Vector.new(-1..-1000), &-/2)

    assert A.Vector.new(1..500, &(&1 * 2)) ==
             A.Vector.zip_with(A.Vector.new(1..1000), A.Vector.new(-1..-500), &-/2)

    assert A.Vector.new(1..500, &(&1 * 2)) ==
             A.Vector.zip_with(A.Vector.new(1..500), A.Vector.new(-1..-1000), &-/2)
  end

  test "unzip/2" do
    assert {A.Vector.new(), A.Vector.new()} == A.Vector.unzip(A.Vector.new())

    assert {A.Vector.new(-1..-5), A.Vector.new(1..5)} ==
             A.Vector.unzip(A.Vector.new(Enum.zip(-1..-5, 1..5)))

    assert {A.Vector.new(-1..-50), A.Vector.new(1..50)} ==
             A.Vector.unzip(A.Vector.new(Enum.zip(-1..-50, 1..50)))

    assert {A.Vector.new(-1..-500), A.Vector.new(1..500)} ==
             A.Vector.unzip(A.Vector.new(Enum.zip(-1..-500, 1..500)))
  end

  test "slice/2" do
    assert A.Vector.new([]) == A.Vector.new() |> A.Vector.slice(1..5)
    assert A.Vector.new([2, 3, 4, 5, 6]) == A.Vector.new(1..10) |> A.Vector.slice(1..5)
    assert A.Vector.new([2, 3, 4, 5, 6]) == A.Vector.new(1..100) |> A.Vector.slice(1..5)
    assert A.Vector.new([18, 19]) == A.Vector.new(1..20) |> A.Vector.slice(-3, 2)
    assert A.Vector.new(2..99) == A.Vector.new(1..100) |> A.Vector.slice(1..98)
  end

  test "take/2" do
    assert A.Vector.new([]) == A.Vector.new() |> A.Vector.take(100)
    assert A.Vector.new([]) == A.Vector.new(1..100) |> A.Vector.take(0)

    assert A.Vector.new([1, 2, 3]) == A.Vector.new(1..5) |> A.Vector.take(3)
    assert A.Vector.new([1, 2, 3]) == A.Vector.new(1..50) |> A.Vector.take(3)
    assert A.Vector.new(1..25) == A.Vector.new(1..50) |> A.Vector.take(25)
    assert A.Vector.new(1..49) == A.Vector.new(1..50) |> A.Vector.take(49)

    assert A.Vector.new(1..5) == A.Vector.new(1..5) |> A.Vector.take(1000)
    assert A.Vector.new(1..50) == A.Vector.new(1..50) |> A.Vector.take(1000)

    assert A.Vector.new([3, 4, 5]) == A.Vector.new(1..5) |> A.Vector.take(-3)
    assert A.Vector.new(21..50) == A.Vector.new(1..50) |> A.Vector.take(-30)

    assert A.Vector.new([1]) == A.Vector.new(1..273) |> A.Vector.take(1)
    assert A.Vector.new(1..20) == A.Vector.new(1..500) |> A.Vector.take(20)
    assert A.Vector.new(1..20) == A.Vector.new(1..5000) |> A.Vector.take(20)
    assert A.Vector.new(1..20) == A.Vector.new(1..50_000) |> A.Vector.take(20)
  end

  test "drop/2" do
    assert A.Vector.new([]) == A.Vector.new() |> A.Vector.drop(100)
    assert A.Vector.new([]) == A.Vector.new(1..100) |> A.Vector.drop(100)

    assert A.Vector.new(1..10) == A.Vector.new(1..10) |> A.Vector.drop(0)

    assert A.Vector.new([5]) == A.Vector.new(1..5) |> A.Vector.drop(4)
    assert A.Vector.new([2, 3, 4, 5]) == A.Vector.new(1..5) |> A.Vector.drop(1)

    assert A.Vector.new([50]) == A.Vector.new(1..50) |> A.Vector.drop(49)
    assert A.Vector.new(2..50) == A.Vector.new(1..50) |> A.Vector.drop(1)

    assert A.Vector.new([1, 2, 3, 4]) == A.Vector.new(1..5) |> A.Vector.drop(-1)
    assert A.Vector.new([1]) == A.Vector.new(1..5) |> A.Vector.drop(-4)
    assert A.Vector.new([]) == A.Vector.new(1..5) |> A.Vector.drop(-5)
    assert A.Vector.new([]) == A.Vector.new(1..5) |> A.Vector.drop(-100_000)

    assert A.Vector.new(1..49) == A.Vector.new(1..50) |> A.Vector.drop(-1)
    assert A.Vector.new([1, 2, 3, 4, 5]) == A.Vector.new(1..50) |> A.Vector.drop(-45)
    assert A.Vector.new([]) == A.Vector.new(1..50) |> A.Vector.drop(-50)
    assert A.Vector.new([]) == A.Vector.new(1..50) |> A.Vector.drop(-100_000)

    assert A.Vector.new(1..20) == A.Vector.new(1..500) |> A.Vector.drop(-480)
    assert A.Vector.new(1..20) == A.Vector.new(1..5000) |> A.Vector.drop(-4980)
    assert A.Vector.new(1..20) == A.Vector.new(1..50_000) |> A.Vector.drop(-49_980)

    assert A.Vector.new(1..9744) == A.Vector.new(1..9745) |> A.Vector.drop(-1)
  end

  test "Enum.to_list/1" do
    assert [] == A.Vector.new() |> Enum.to_list()
    assert [1, 2, 3, 4, 5] == A.Vector.new(1..5) |> Enum.to_list()
    assert Enum.to_list(1..50) == A.Vector.new(1..50) |> Enum.to_list()
    assert Enum.to_list(1..500) == A.Vector.new(1..500) |> Enum.to_list()
  end

  test "Enum.member?/2" do
    refute 0 in A.Vector.new()

    small = A.Vector.new(1..5)
    refute 0 in small
    assert 1 in small
    assert 5 in small
    refute 6 in small

    full_tail = A.Vector.new(1..16)
    assert 16 in full_tail
    refute 17 in full_tail

    large = A.Vector.new(1..500)
    refute 0 in large
    assert 1 in large
    assert 5 in large
    assert 50 in large
    assert 500 in large
    refute 501 in large
  end

  test "Enum.slice/2" do
    assert [] == A.Vector.new() |> Enum.slice(1..5)
    assert [2, 3, 4, 5, 6] == A.Vector.new(1..10) |> Enum.slice(1..5)
    assert [2, 3, 4, 5, 6] == A.Vector.new(1..100) |> Enum.slice(1..5)
    assert [18, 19] == A.Vector.new(1..20) |> Enum.slice(-3, 2)
    assert Enum.to_list(2..99) == A.Vector.new(1..100) |> Enum.slice(1..98)
  end
end
