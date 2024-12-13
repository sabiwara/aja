defmodule Aja.VectorTest do
  use ExUnit.Case, async: true

  import Aja, only: [vec: 1]

  doctest Aja.Vector

  import Aja.TestHelpers

  describe "Aja.Vector" do
    test "new/0 and new/1 return a constant when empty" do
      assert :erts_debug.same(Aja.Vector.new(), Aja.Vector.new())
      assert :erts_debug.same(Aja.Vector.new([]), Aja.Vector.new())
      assert :erts_debug.same(Aja.Vector.new([]), Aja.Vector.new([]))
    end

    test "at/2" do
      range = 0..500
      vector = Aja.Vector.new(range)

      result = for i <- range, do: Aja.Vector.at(vector, i)

      assert Enum.to_list(range) == result
    end

    test "replace_at/2" do
      range = 0..499
      vector = List.duplicate(nil, Enum.count(range)) |> Aja.Vector.new()

      result =
        Enum.reduce(range, vector, fn i, vec ->
          Aja.Vector.replace_at(vec, i, i)
        end)

      assert Aja.Vector.new(range) == result
    end

    test "update_at/2" do
      range = 0..499
      vector = Aja.Vector.new(range)

      result =
        Enum.reduce(range, vector, fn i, vec ->
          Aja.Vector.update_at(vec, i, &(&1 + 50))
        end)

      assert Aja.Vector.new(50..549) == result
    end

    test "append/2" do
      range = 1..5_000

      vector =
        Enum.reduce(range, Aja.Vector.new(), fn value, vec ->
          Aja.Vector.append(vec, value)
        end)

      expected = Aja.Vector.new(range)
      assert expected == vector
    end

    test "concat/2" do
      assert Aja.Vector.new() == Aja.Vector.new() |> Aja.Vector.concat([])

      assert Aja.Vector.new(1..5) == Aja.Vector.new(1..5) |> Aja.Vector.concat([])
      assert Aja.Vector.new(6..10) == Aja.Vector.new() |> Aja.Vector.concat(6..10)

      assert Aja.Vector.new(1..10) == Aja.Vector.new(1..5) |> Aja.Vector.concat(6..10)
      assert Aja.Vector.new(1..20) == Aja.Vector.new(1..10) |> Aja.Vector.concat(11..20)
      assert Aja.Vector.new(1..100) == Aja.Vector.new(1..50) |> Aja.Vector.concat(51..100)
      assert Aja.Vector.new(1..1000) == Aja.Vector.new(1..500) |> Aja.Vector.concat(501..1000)

      right_list = List.duplicate(0, 16)
      right_vec = Aja.Vector.duplicate(0, 16)

      # an attempt at finding concat edge cases near "interesting" sizes,
      # when tries are full or partially full
      for n <- 2..11, k = Integer.pow(4, n), p <- [k, k * 2], i <- (p - 16)..(p + 16) do
        expected = Aja.Vector.duplicate(0, i + 16)
        assert Aja.Vector.duplicate(0, i) |> Aja.Vector.concat(right_list) == expected
        assert Aja.Vector.duplicate(0, i) |> Aja.Vector.concat(right_vec) == expected
      end
    end

    test "pop_last!/1" do
      range = 1..5_000

      vector =
        Enum.reduce(range, Aja.Vector.new(), fn value, vec ->
          new_vec = Aja.Vector.append(vec, value)
          assert {^value, ^vec} = Aja.Vector.pop_last!(new_vec)
          new_vec
        end)

      expected = Aja.Vector.new(range)
      assert expected == vector
    end

    test "duplicate/2" do
      for i <-
            Enum.concat(0..255, [256, 257, 274, 500, 512, 513, 4353, 5_000, 8193, 50_000, 500_000]) do
        vector = Aja.Vector.duplicate(nil, i)
        list = List.duplicate(nil, i)

        assert i == Aja.Vector.size(vector)
        assert list == Aja.Vector.to_list(vector)
      end
    end

    test "reverse/1" do
      assert Aja.Vector.new() == Aja.Vector.new() |> Aja.Vector.reverse()
      assert Aja.Vector.new(5..1//-1) == Aja.Vector.new(1..5) |> Aja.Vector.reverse()
      assert Aja.Vector.new(50..1//-1) == Aja.Vector.new(1..50) |> Aja.Vector.reverse()
      assert Aja.Vector.new(500..1//-1) == Aja.Vector.new(1..500) |> Aja.Vector.reverse()
    end

    test "take_while/2" do
      {gte_zero?, pop_args} = spy_callback(&(&1 >= 0))

      assert Aja.Vector.new() == Aja.Vector.new() |> Aja.Vector.take_while(gte_zero?)
      assert [] == pop_args.()

      assert Aja.Vector.new(5..0//-1) ==
               Aja.Vector.new(5..0//-1) |> Aja.Vector.take_while(gte_zero?)

      assert [5, 4, 3, 2, 1, 0] == pop_args.()

      assert Aja.Vector.new(50..0//-1) ==
               Aja.Vector.new(50..0//-1) |> Aja.Vector.take_while(gte_zero?)

      assert Enum.to_list(50..0//-1) == pop_args.()

      assert Aja.Vector.new(500..0//-1) ==
               Aja.Vector.new(500..0//-1) |> Aja.Vector.take_while(gte_zero?)

      assert Enum.to_list(500..0//-1) == pop_args.()

      assert Aja.Vector.new(5..0//-1) ==
               Aja.Vector.new(5..-5//-1) |> Aja.Vector.take_while(gte_zero?)

      assert [5, 4, 3, 2, 1, 0, -1] == pop_args.()

      assert Aja.Vector.new(50..0//-1) ==
               Aja.Vector.new(50..-50//-1) |> Aja.Vector.take_while(gte_zero?)

      assert Enum.to_list(50..-1//-1) == pop_args.()

      assert Aja.Vector.new(500..0//-1) ==
               Aja.Vector.new(500..-500//-1) |> Aja.Vector.take_while(gte_zero?)

      assert Enum.to_list(500..-1//-1) == pop_args.()

      assert Aja.Vector.new() == Aja.Vector.new([-1, 0, 1]) |> Aja.Vector.take_while(gte_zero?)

      assert Enum.to_list([-1]) == pop_args.()
    end

    test "drop_while/2" do
      {gte_zero?, pop_args} = spy_callback(&(&1 >= 0))

      assert Aja.Vector.new() == Aja.Vector.new() |> Aja.Vector.drop_while(gte_zero?)
      assert [] == pop_args.()

      assert Aja.Vector.new() == Aja.Vector.new(5..0//-1) |> Aja.Vector.drop_while(gte_zero?)
      assert [5, 4, 3, 2, 1, 0] == pop_args.()

      assert Aja.Vector.new() == Aja.Vector.new(50..0//-1) |> Aja.Vector.drop_while(gte_zero?)
      assert Enum.to_list(50..0//-1) == pop_args.()

      assert Aja.Vector.new() == Aja.Vector.new(500..0//-1) |> Aja.Vector.drop_while(gte_zero?)
      assert Enum.to_list(500..0//-1) == pop_args.()

      assert Aja.Vector.new([-1, -2, -3, -4, -5]) ==
               Aja.Vector.new(5..-5//-1) |> Aja.Vector.drop_while(gte_zero?)

      assert [5, 4, 3, 2, 1, 0, -1] == pop_args.()

      assert Aja.Vector.new(-1..-50//-1) ==
               Aja.Vector.new(50..-50//-1) |> Aja.Vector.drop_while(gte_zero?)

      assert Enum.to_list(50..-1//-1) == pop_args.()

      assert Aja.Vector.new(-1..-500//-1) ==
               Aja.Vector.new(500..-500//-1) |> Aja.Vector.drop_while(gte_zero?)

      assert Enum.to_list(500..-1//-1) == pop_args.()

      assert Aja.Vector.new([-1, 0, 1]) ==
               Aja.Vector.new([-1, 0, 1]) |> Aja.Vector.drop_while(gte_zero?)

      assert Enum.to_list([-1]) == pop_args.()
    end

    test "split_while/2" do
      {gte_zero?, pop_args} = spy_callback(&(&1 >= 0))

      assert {Aja.Vector.new(), Aja.Vector.new()} ==
               Aja.Vector.new() |> Aja.Vector.split_while(gte_zero?)

      assert [] == pop_args.()

      assert {Aja.Vector.new(5..0//-1), Aja.Vector.new()} ==
               Aja.Vector.new(5..0//-1) |> Aja.Vector.split_while(gte_zero?)

      assert [5, 4, 3, 2, 1, 0] == pop_args.()

      assert {Aja.Vector.new(50..0//-1), Aja.Vector.new()} ==
               Aja.Vector.new(50..0//-1) |> Aja.Vector.split_while(gte_zero?)

      assert Enum.to_list(50..0//-1) == pop_args.()

      assert {Aja.Vector.new(500..0//-1), Aja.Vector.new()} ==
               Aja.Vector.new(500..0//-1) |> Aja.Vector.split_while(gte_zero?)

      assert Enum.to_list(500..0//-1) == pop_args.()

      assert {Aja.Vector.new(5..0//-1), Aja.Vector.new(-1..-5//-1)} ==
               Aja.Vector.new(5..-5//-1) |> Aja.Vector.split_while(gte_zero?)

      assert [5, 4, 3, 2, 1, 0, -1] == pop_args.()

      assert {Aja.Vector.new(50..0//-1), Aja.Vector.new(-1..-50//-1)} ==
               Aja.Vector.new(50..-50//-1) |> Aja.Vector.split_while(gte_zero?)

      assert Enum.to_list(50..-1//-1) == pop_args.()

      assert {Aja.Vector.new(500..0//-1), Aja.Vector.new(-1..-500//-1)} ==
               Aja.Vector.new(500..-500//-1) |> Aja.Vector.split_while(gte_zero?)

      assert Enum.to_list(500..-1//-1) == pop_args.()

      assert {Aja.Vector.new(), Aja.Vector.new([-1, 0, 1])} ==
               Aja.Vector.new([-1, 0, 1]) |> Aja.Vector.split_while(gte_zero?)

      assert Enum.to_list([-1]) == pop_args.()
    end

    test "intersperse/2" do
      assert Aja.Vector.new() == Aja.Vector.new() |> Aja.Vector.intersperse(0)

      assert Aja.Vector.new([1, 0, 2, 0, 3, 0, 4, 0, 5]) ==
               Aja.Vector.new(1..5) |> Aja.Vector.intersperse(0)

      assert Enum.intersperse(1..50, 0) |> Aja.Vector.new() ==
               Aja.Vector.new(1..50) |> Aja.Vector.intersperse(0)

      assert Enum.intersperse(1..500, 0) |> Aja.Vector.new() ==
               Aja.Vector.new(1..500) |> Aja.Vector.intersperse(0)
    end

    test "map_intersperse/3" do
      {add_one, pop_args} = spy_callback(&(&1 + 1))

      assert Aja.Vector.new() == Aja.Vector.new() |> Aja.Vector.map_intersperse(0, add_one)
      assert [] == pop_args.()

      assert Aja.Vector.new([2, 0, 3, 0, 4, 0, 5, 0, 6]) ==
               Aja.Vector.new(1..5) |> Aja.Vector.map_intersperse(0, add_one)

      assert [1, 2, 3, 4, 5] == pop_args.()

      assert Enum.intersperse(2..51, 0) |> Aja.Vector.new() ==
               Aja.Vector.new(1..50) |> Aja.Vector.map_intersperse(0, add_one)

      assert Enum.to_list(1..50) == pop_args.()

      assert Enum.intersperse(2..501, 0) |> Aja.Vector.new() ==
               Aja.Vector.new(1..500) |> Aja.Vector.map_intersperse(0, add_one)

      assert Enum.to_list(1..500) == pop_args.()
    end

    test "map/2" do
      {add_one, pop_args} = spy_callback(&(&1 + 1))

      assert Aja.Vector.new() == Aja.Vector.new() |> Aja.Vector.map(add_one)
      assert [] == pop_args.()

      assert Aja.Vector.new(2..6) == Aja.Vector.new(1..5) |> Aja.Vector.map(add_one)
      assert [1, 2, 3, 4, 5] == pop_args.()

      assert Aja.Vector.new(2..51) == Aja.Vector.new(1..50) |> Aja.Vector.map(add_one)
      assert Enum.to_list(1..50) == pop_args.()

      assert Aja.Vector.new(2..501) == Aja.Vector.new(1..500) |> Aja.Vector.map(add_one)
      assert Enum.to_list(1..500) == pop_args.()
    end

    test "filter/2" do
      odd? = &(rem(&1, 2) == 0)
      {spy, pop_args} = spy_callback(odd?)

      assert Aja.Vector.new() == Aja.Vector.new() |> Aja.Vector.filter(spy)
      assert [] == pop_args.()

      assert Aja.Vector.new([2, 4]) == Aja.Vector.new(1..5) |> Aja.Vector.filter(spy)
      assert [1, 2, 3, 4, 5] == pop_args.()

      assert Enum.filter(1..50, odd?) |> Aja.Vector.new() ==
               Aja.Vector.new(1..50) |> Aja.Vector.filter(spy)

      assert Enum.to_list(1..50) == pop_args.()

      assert Enum.filter(1..500, odd?) |> Aja.Vector.new() ==
               Aja.Vector.new(1..500) |> Aja.Vector.filter(spy)

      assert Enum.to_list(1..500) == pop_args.()
    end

    test "reject/2" do
      odd? = &(rem(&1, 2) == 0)
      {spy, pop_args} = spy_callback(odd?)

      assert Aja.Vector.new() == Aja.Vector.new() |> Aja.Vector.reject(spy)
      assert [] == pop_args.()

      assert Aja.Vector.new([1, 3, 5]) == Aja.Vector.new(1..5) |> Aja.Vector.reject(spy)
      assert [1, 2, 3, 4, 5] == pop_args.()

      assert Enum.reject(1..50, odd?) |> Aja.Vector.new() ==
               Aja.Vector.new(1..50) |> Aja.Vector.reject(spy)

      assert Enum.to_list(1..50) == pop_args.()

      assert Enum.reject(1..500, odd?) |> Aja.Vector.new() ==
               Aja.Vector.new(1..500) |> Aja.Vector.reject(spy)

      assert Enum.to_list(1..500) == pop_args.()
    end

    test "split_with/2" do
      odd? = &(rem(&1, 2) == 0)
      {spy, pop_args} = spy_callback(odd?)

      assert {Aja.Vector.new(), Aja.Vector.new()} ==
               Aja.Vector.new() |> Aja.Vector.split_with(spy)

      assert [] == pop_args.()

      assert {Aja.Vector.new([2, 4]), Aja.Vector.new([1, 3, 5])} ==
               Aja.Vector.new(1..5) |> Aja.Vector.split_with(spy)

      assert [1, 2, 3, 4, 5] == pop_args.()

      {list1, list2} = Enum.split_with(1..50, odd?)

      assert {Aja.Vector.new(list1), Aja.Vector.new(list2)} ==
               Aja.Vector.new(1..50) |> Aja.Vector.split_with(spy)

      assert Enum.to_list(1..50) == pop_args.()

      {list1, list2} = Enum.split_with(1..500, odd?)

      assert {Aja.Vector.new(list1), Aja.Vector.new(list2)} ==
               Aja.Vector.new(1..500) |> Aja.Vector.split_with(spy)

      assert Enum.to_list(1..500) == pop_args.()
    end

    test "with_index/2" do
      assert Aja.Vector.new() == Aja.Vector.new() |> Aja.Vector.with_index()
      assert Aja.Vector.new() == Aja.Vector.new() |> Aja.Vector.with_index(77)

      assert Aja.Vector.new(a: 0, b: 1) == Aja.Vector.new([:a, :b]) |> Aja.Vector.with_index()
      assert Aja.Vector.new(a: 77, b: 78) == Aja.Vector.new([:a, :b]) |> Aja.Vector.with_index(77)

      assert Aja.Vector.new(a: -77, b: -76) ==
               Aja.Vector.new([:a, :b]) |> Aja.Vector.with_index(-77)

      assert Enum.with_index(1..50) |> Aja.Vector.new() ==
               Aja.Vector.new(1..50) |> Aja.Vector.with_index()

      assert Enum.with_index(1..50, 77) |> Aja.Vector.new() ==
               Aja.Vector.new(1..50) |> Aja.Vector.with_index(77)

      assert Enum.with_index(1..500) |> Aja.Vector.new() ==
               Aja.Vector.new(1..500) |> Aja.Vector.with_index()

      assert Enum.with_index(1..500, 77) |> Aja.Vector.new() ==
               Aja.Vector.new(1..500) |> Aja.Vector.with_index(77)
    end

    test "zip/2" do
      assert Aja.Vector.new() == Aja.Vector.zip(Aja.Vector.new(), Aja.Vector.new(1..1000))
      assert Aja.Vector.new() == Aja.Vector.zip(Aja.Vector.new(1..1000), Aja.Vector.new())

      assert Aja.Vector.new(Enum.zip(-1..-5//-1, 1..5)) ==
               Aja.Vector.zip(Aja.Vector.new(-1..-1000//-1), Aja.Vector.new(1..5))

      assert Aja.Vector.new(Enum.zip(1..5, -1..-5//-1)) ==
               Aja.Vector.zip(Aja.Vector.new(1..5), Aja.Vector.new(-1..-1000//-1))

      assert Aja.Vector.new(Enum.zip(1..5, -1..-5//-1)) ==
               Aja.Vector.zip(Aja.Vector.new(1..5), Aja.Vector.new(-1..-5//-1))

      assert Aja.Vector.new(Enum.zip(-1..-50//-1, 1..50)) ==
               Aja.Vector.zip(Aja.Vector.new(-1..-1000//-1), Aja.Vector.new(1..50))

      assert Aja.Vector.new(Enum.zip(1..50, -1..-50//-1)) ==
               Aja.Vector.zip(Aja.Vector.new(1..50), Aja.Vector.new(-1..-1000//-1))

      assert Aja.Vector.new(Enum.zip(-1..-500//-1, 1..500)) ==
               Aja.Vector.zip(Aja.Vector.new(-1..-1000//-1), Aja.Vector.new(1..500))

      assert Aja.Vector.new(Enum.zip(1..500, -1..-500//-1)) ==
               Aja.Vector.zip(Aja.Vector.new(1..500), Aja.Vector.new(-1..-1000//-1))
    end

    test "zip_with/3" do
      assert Aja.Vector.new() ==
               Aja.Vector.zip_with(Aja.Vector.new(), Aja.Vector.new(1..1000), &-/2)

      assert Aja.Vector.new() ==
               Aja.Vector.zip_with(Aja.Vector.new(1..1000), Aja.Vector.new(), &-/2)

      assert Aja.Vector.new(1..5, &(&1 * 2)) ==
               Aja.Vector.zip_with(Aja.Vector.new(1..1000), Aja.Vector.new(-1..-5//-1), &-/2)

      assert Aja.Vector.new(1..5, &(&1 * 2)) ==
               Aja.Vector.zip_with(Aja.Vector.new(1..5), Aja.Vector.new(-1..-1000//-1), &-/2)

      assert Aja.Vector.new(1..5, &(&1 * 2)) ==
               Aja.Vector.zip_with(Aja.Vector.new(1..5), Aja.Vector.new(-1..-5//-1), &-/2)

      assert Aja.Vector.new(1..50, &(&1 * 2)) ==
               Aja.Vector.zip_with(Aja.Vector.new(1..1000), Aja.Vector.new(-1..-50//-1), &-/2)

      assert Aja.Vector.new(1..50, &(&1 * 2)) ==
               Aja.Vector.zip_with(Aja.Vector.new(1..50), Aja.Vector.new(-1..-1000//-1), &-/2)

      assert Aja.Vector.new(1..500, &(&1 * 2)) ==
               Aja.Vector.zip_with(Aja.Vector.new(1..1000), Aja.Vector.new(-1..-500//-1), &-/2)

      assert Aja.Vector.new(1..500, &(&1 * 2)) ==
               Aja.Vector.zip_with(Aja.Vector.new(1..500), Aja.Vector.new(-1..-1000//-1), &-/2)
    end

    test "unzip/2" do
      assert {Aja.Vector.new(), Aja.Vector.new()} == Aja.Vector.unzip(Aja.Vector.new())

      assert {Aja.Vector.new(-1..-5//-1), Aja.Vector.new(1..5)} ==
               Aja.Vector.unzip(Aja.Vector.new(Enum.zip(-1..-5//-1, 1..5)))

      assert {Aja.Vector.new(-1..-50//-1), Aja.Vector.new(1..50)} ==
               Aja.Vector.unzip(Aja.Vector.new(Enum.zip(-1..-50//-1, 1..50)))

      assert {Aja.Vector.new(-1..-500//-1), Aja.Vector.new(1..500)} ==
               Aja.Vector.unzip(Aja.Vector.new(Enum.zip(-1..-500//-1, 1..500)))
    end

    test "slice/2" do
      assert Aja.Vector.new([]) == Aja.Vector.new() |> Aja.Vector.slice(1..5)
      assert Aja.Vector.new([2, 3, 4, 5, 6]) == Aja.Vector.new(1..10) |> Aja.Vector.slice(1..5)
      assert Aja.Vector.new([2, 3, 4, 5, 6]) == Aja.Vector.new(1..100) |> Aja.Vector.slice(1..5)
      assert Aja.Vector.new([18, 19]) == Aja.Vector.new(1..20) |> Aja.Vector.slice(-3, 2)
      assert Aja.Vector.new(2..99) == Aja.Vector.new(1..100) |> Aja.Vector.slice(1..98)
    end

    test "take/2" do
      assert Aja.Vector.new([]) == Aja.Vector.new() |> Aja.Vector.take(100)
      assert Aja.Vector.new([]) == Aja.Vector.new(1..100) |> Aja.Vector.take(0)

      assert Aja.Vector.new([1, 2, 3]) == Aja.Vector.new(1..5) |> Aja.Vector.take(3)
      assert Aja.Vector.new([1, 2, 3]) == Aja.Vector.new(1..50) |> Aja.Vector.take(3)
      assert Aja.Vector.new(1..25) == Aja.Vector.new(1..50) |> Aja.Vector.take(25)
      assert Aja.Vector.new(1..49) == Aja.Vector.new(1..50) |> Aja.Vector.take(49)

      assert Aja.Vector.new(1..5) == Aja.Vector.new(1..5) |> Aja.Vector.take(1000)
      assert Aja.Vector.new(1..50) == Aja.Vector.new(1..50) |> Aja.Vector.take(1000)

      assert Aja.Vector.new([3, 4, 5]) == Aja.Vector.new(1..5) |> Aja.Vector.take(-3)
      assert Aja.Vector.new(21..50) == Aja.Vector.new(1..50) |> Aja.Vector.take(-30)

      assert Aja.Vector.new([1]) == Aja.Vector.new(1..273) |> Aja.Vector.take(1)
      assert Aja.Vector.new(1..20) == Aja.Vector.new(1..500) |> Aja.Vector.take(20)
      assert Aja.Vector.new(1..20) == Aja.Vector.new(1..5000) |> Aja.Vector.take(20)
      assert Aja.Vector.new(1..20) == Aja.Vector.new(1..50_000) |> Aja.Vector.take(20)
    end

    test "drop/2" do
      assert Aja.Vector.new([]) == Aja.Vector.new() |> Aja.Vector.drop(100)
      assert Aja.Vector.new([]) == Aja.Vector.new(1..100) |> Aja.Vector.drop(100)

      assert Aja.Vector.new(1..10) == Aja.Vector.new(1..10) |> Aja.Vector.drop(0)

      assert Aja.Vector.new([5]) == Aja.Vector.new(1..5) |> Aja.Vector.drop(4)
      assert Aja.Vector.new([2, 3, 4, 5]) == Aja.Vector.new(1..5) |> Aja.Vector.drop(1)

      assert Aja.Vector.new([50]) == Aja.Vector.new(1..50) |> Aja.Vector.drop(49)
      assert Aja.Vector.new(2..50) == Aja.Vector.new(1..50) |> Aja.Vector.drop(1)

      assert Aja.Vector.new([1, 2, 3, 4]) == Aja.Vector.new(1..5) |> Aja.Vector.drop(-1)
      assert Aja.Vector.new([1]) == Aja.Vector.new(1..5) |> Aja.Vector.drop(-4)
      assert Aja.Vector.new([]) == Aja.Vector.new(1..5) |> Aja.Vector.drop(-5)
      assert Aja.Vector.new([]) == Aja.Vector.new(1..5) |> Aja.Vector.drop(-100_000)

      assert Aja.Vector.new(1..49) == Aja.Vector.new(1..50) |> Aja.Vector.drop(-1)
      assert Aja.Vector.new([1, 2, 3, 4, 5]) == Aja.Vector.new(1..50) |> Aja.Vector.drop(-45)
      assert Aja.Vector.new([]) == Aja.Vector.new(1..50) |> Aja.Vector.drop(-50)
      assert Aja.Vector.new([]) == Aja.Vector.new(1..50) |> Aja.Vector.drop(-100_000)

      assert Aja.Vector.new(1..20) == Aja.Vector.new(1..500) |> Aja.Vector.drop(-480)
      assert Aja.Vector.new(1..20) == Aja.Vector.new(1..5000) |> Aja.Vector.drop(-4980)
      assert Aja.Vector.new(1..20) == Aja.Vector.new(1..50_000) |> Aja.Vector.drop(-49_980)

      assert Aja.Vector.new(1..9744) == Aja.Vector.new(1..9745) |> Aja.Vector.drop(-1)
    end

    test "Enum.to_list/1" do
      assert [] == Aja.Vector.new() |> Enum.to_list()
      assert [1, 2, 3, 4, 5] == Aja.Vector.new(1..5) |> Enum.to_list()
      assert Enum.to_list(1..50) == Aja.Vector.new(1..50) |> Enum.to_list()
      assert Enum.to_list(1..500) == Aja.Vector.new(1..500) |> Enum.to_list()
    end

    test "Enum.member?/2" do
      refute 0 in Aja.Vector.new()

      small = Aja.Vector.new(1..5)
      refute 0 in small
      assert 1 in small
      assert 5 in small
      refute 6 in small

      full_tail = Aja.Vector.new(1..16)
      assert 16 in full_tail
      refute 17 in full_tail

      large = Aja.Vector.new(1..500)
      refute 0 in large
      assert 1 in large
      assert 5 in large
      assert 50 in large
      assert 500 in large
      refute 501 in large
    end

    test "Enum.slice/2" do
      assert [] == Aja.Vector.new() |> Enum.slice(1..5)
      assert [2, 3, 4, 5, 6] == Aja.Vector.new(1..10) |> Enum.slice(1..5)
      assert [2, 3, 4, 5, 6] == Aja.Vector.new(1..100) |> Enum.slice(1..5)
      assert [18, 19] == Aja.Vector.new(1..20) |> Enum.slice(-3, 2)
      assert Enum.to_list(2..99) == Aja.Vector.new(1..100) |> Enum.slice(1..98)
    end

    @tag skip: Version.compare(System.version(), "1.18.0-rc.0") == :lt
    test "JSON.encode!/1" do
      result = Aja.Vector.new(["un", 2, :trois]) |> JSON.encode!()
      assert result == "[\"un\",2,\"trois\"]"
    end

    test "Jason.encode!/1" do
      result = Aja.Vector.new(["un", 2, :trois]) |> Jason.encode!()
      assert result == "[\"un\",2,\"trois\"]"
    end
  end
end
