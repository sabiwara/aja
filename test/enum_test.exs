defmodule Aja.EnumTest do
  use ExUnit.Case, async: true

  doctest Aja.Enum

  import Aja.TestHelpers

  describe "Aja.Enum" do
    test "all?/1 (vector)" do
      assert true == Aja.Vector.new() |> Aja.Enum.all?()

      assert true == Aja.Vector.new([1, true, "string", :atom, %{}, []]) |> Aja.Enum.all?()
      assert true == Aja.Vector.new(1..50) |> Aja.Enum.all?()
      assert true == Aja.Vector.new(1..500) |> Aja.Enum.all?()

      assert false == Aja.Vector.duplicate(true, 5) |> Aja.Vector.append(false) |> Aja.Enum.all?()
      assert false == Aja.Vector.new(1..50) |> Aja.Vector.append(nil) |> Aja.Enum.all?()
      assert false == Aja.Vector.new(1..500) |> Aja.Vector.append(nil) |> Aja.Enum.all?()
    end

    test "all?/2 (vector)" do
      {gt_zero?, pop_args} = spy_callback(&(&1 > 0))

      assert true == Aja.Vector.new() |> Aja.Enum.all?(gt_zero?)
      assert [] == pop_args.()

      assert true == Aja.Vector.new(5..1) |> Aja.Enum.all?(gt_zero?)
      assert [5, 4, 3, 2, 1] == pop_args.()

      assert true == Aja.Vector.new(50..1) |> Aja.Enum.all?(gt_zero?)
      assert Enum.to_list(50..1) == pop_args.()

      assert true == Aja.Vector.new(500..1) |> Aja.Enum.all?(gt_zero?)
      assert Enum.to_list(500..1) == pop_args.()

      assert false == Aja.Vector.new(5..0) |> Aja.Enum.all?(gt_zero?)
      assert [5, 4, 3, 2, 1, 0] == pop_args.()

      assert false == Aja.Vector.new(50..0) |> Aja.Enum.all?(gt_zero?)
      assert Enum.to_list(50..0) == pop_args.()

      assert false == Aja.Vector.new(500..0) |> Aja.Enum.all?(gt_zero?)
      assert Enum.to_list(500..0) == pop_args.()
    end

    test "any?/1 (vector)" do
      assert false == Aja.Vector.new() |> Aja.Enum.any?()

      assert false == Aja.Vector.duplicate(false, 5) |> Aja.Enum.any?()
      assert false == Aja.Vector.duplicate(nil, 50) |> Aja.Enum.any?()
      assert false == Aja.Vector.duplicate(false, 500) |> Aja.Enum.any?()

      assert true == Aja.Vector.duplicate(false, 5) |> Aja.Vector.append(true) |> Aja.Enum.any?()
      assert true == Aja.Vector.duplicate(nil, 50) |> Aja.Vector.append(55) |> Aja.Enum.any?()
      assert true == Aja.Vector.duplicate(false, 500) |> Aja.Vector.append(%{}) |> Aja.Enum.any?()
    end

    test "any?/2 (vector)" do
      {lt_zero?, pop_args} = spy_callback(&(&1 < 0))

      assert false == Aja.Vector.new() |> Aja.Enum.any?(lt_zero?)
      assert [] == pop_args.()

      assert false == Aja.Vector.new(5..0) |> Aja.Enum.any?(lt_zero?)
      assert [5, 4, 3, 2, 1, 0] == pop_args.()

      assert false == Aja.Vector.new(50..0) |> Aja.Enum.any?(lt_zero?)
      assert Enum.to_list(50..0) == pop_args.()

      assert false == Aja.Vector.new(500..0) |> Aja.Enum.any?(lt_zero?)
      assert Enum.to_list(500..0) == pop_args.()

      assert true == Aja.Vector.new(5..-5) |> Aja.Enum.any?(lt_zero?)
      assert [5, 4, 3, 2, 1, 0, -1] == pop_args.()

      assert true == Aja.Vector.new(50..-50) |> Aja.Enum.any?(lt_zero?)
      assert Enum.to_list(50..-1) == pop_args.()

      assert true == Aja.Vector.new(500..-500) |> Aja.Enum.any?(lt_zero?)
      assert Enum.to_list(500..-1) == pop_args.()
    end

    test "find/2 (vector)" do
      {lt_zero?, pop_args} = spy_callback(&(&1 < 0))

      assert nil == Aja.Vector.new() |> Aja.Enum.find(lt_zero?)
      assert [] == pop_args.()

      assert nil == Aja.Vector.new(5..0) |> Aja.Enum.find(lt_zero?)
      assert [5, 4, 3, 2, 1, 0] == pop_args.()

      assert nil == Aja.Vector.new(50..0) |> Aja.Enum.find(lt_zero?)
      assert Enum.to_list(50..0) == pop_args.()

      assert nil == Aja.Vector.new(500..0) |> Aja.Enum.find(lt_zero?)
      assert Enum.to_list(500..0) == pop_args.()

      assert -1 == Aja.Vector.new(5..-5) |> Aja.Enum.find(lt_zero?)
      assert [5, 4, 3, 2, 1, 0, -1] == pop_args.()

      assert -1 == Aja.Vector.new(50..-50) |> Aja.Enum.find(lt_zero?)
      assert Enum.to_list(50..-1) == pop_args.()

      assert -1 == Aja.Vector.new(500..-500) |> Aja.Enum.find(lt_zero?)
      assert Enum.to_list(500..-1) == pop_args.()
    end

    test "find_value/2 (vector)" do
      {spy, pop_args} =
        spy_callback(fn
          x when x < 0 -> -x
          _ -> nil
        end)

      assert nil == Aja.Vector.new() |> Aja.Enum.find_value(spy)
      assert [] == pop_args.()

      assert nil == Aja.Vector.new(5..0) |> Aja.Enum.find_value(spy)
      assert [5, 4, 3, 2, 1, 0] == pop_args.()

      assert nil == Aja.Vector.new(50..0) |> Aja.Enum.find_value(spy)
      assert Enum.to_list(50..0) == pop_args.()

      assert nil == Aja.Vector.new(500..0) |> Aja.Enum.find_value(spy)
      assert Enum.to_list(500..0) == pop_args.()

      assert 1 == Aja.Vector.new(5..-5) |> Aja.Enum.find_value(spy)
      assert [5, 4, 3, 2, 1, 0, -1] == pop_args.()

      assert 1 == Aja.Vector.new(50..-50) |> Aja.Enum.find_value(spy)
      assert Enum.to_list(50..-1) == pop_args.()

      assert 1 == Aja.Vector.new(500..-500) |> Aja.Enum.find_value(spy)
      assert Enum.to_list(500..-1) == pop_args.()
    end

    test "find_index/2 (vector)" do
      {lt_zero?, pop_args} = spy_callback(&(&1 < 0))

      assert nil == Aja.Vector.new() |> Aja.Enum.find_index(lt_zero?)
      assert [] == pop_args.()

      assert nil == Aja.Vector.new(5..0) |> Aja.Enum.find_index(lt_zero?)
      assert [5, 4, 3, 2, 1, 0] == pop_args.()

      assert nil == Aja.Vector.new(50..0) |> Aja.Enum.find_index(lt_zero?)
      assert Enum.to_list(50..0) == pop_args.()

      assert nil == Aja.Vector.new(500..0) |> Aja.Enum.find_index(lt_zero?)
      assert Enum.to_list(500..0) == pop_args.()

      assert 6 == Aja.Vector.new(5..-5) |> Aja.Enum.find_index(lt_zero?)
      assert [5, 4, 3, 2, 1, 0, -1] == pop_args.()

      assert 51 == Aja.Vector.new(50..-50) |> Aja.Enum.find_index(lt_zero?)
      assert Enum.to_list(50..-1) == pop_args.()

      assert 501 == Aja.Vector.new(500..-500) |> Aja.Enum.find_index(lt_zero?)
      assert Enum.to_list(500..-1) == pop_args.()
    end

    test "sum/1 (vector)" do
      assert 0 = Aja.Vector.new() |> Aja.Enum.sum()
      assert 15 = Aja.Vector.new(1..5) |> Aja.Enum.sum()
      assert 1275 = Aja.Vector.new(1..50) |> Aja.Enum.sum()
      assert 125_250 = Aja.Vector.new(1..500) |> Aja.Enum.sum()

      # floats are added in the same order as Enum.sum/1
      floats = 1..50 |> Enum.map(&(&1 * 0.001))
      assert Enum.sum(floats) === Aja.Vector.new(floats) |> Aja.Enum.sum()
    end

    test "product/1 (vector)" do
      assert 1 = Aja.Vector.new() |> Aja.Enum.product()
      assert 120 = Aja.Vector.new(1..5) |> Aja.Enum.product()
      assert Enum.reduce(1..50, &(&2 * &1)) == Aja.Vector.new(1..50) |> Aja.Enum.product()
      assert Enum.reduce(1..500, &(&2 * &1)) == Aja.Vector.new(1..500) |> Aja.Enum.product()
    end

    test "join/2 (vector)" do
      assert "" == Aja.Vector.new() |> Aja.Enum.join(",")
      assert "1" == Aja.Vector.new([1]) |> Aja.Enum.join(",")
      assert "1,2,3,4,5" == Aja.Vector.new(1..5) |> Aja.Enum.join(",")
      assert Enum.join(1..50, ",") == Aja.Vector.new(1..50) |> Aja.Enum.join(",")
      assert Enum.join(1..500, ",") == Aja.Vector.new(1..500) |> Aja.Enum.join(",")

      assert Enum.join(1..50) == Aja.Vector.new(1..50) |> Aja.Enum.join()
    end

    test "map_join/3 (vector)" do
      {add_one, pop_args} = spy_callback(&(&1 + 1))

      assert "" == Aja.Vector.new() |> Aja.Enum.map_join(",", add_one)
      assert [] == pop_args.()

      assert "2,3,4,5,6" == Aja.Vector.new(1..5) |> Aja.Enum.map_join(",", add_one)
      assert [1, 2, 3, 4, 5] == pop_args.()

      assert Enum.join(2..51, ",") == Aja.Vector.new(1..50) |> Aja.Enum.map_join(",", add_one)
      assert Enum.to_list(1..50) == pop_args.()

      assert Enum.join(2..501, ",") == Aja.Vector.new(1..500) |> Aja.Enum.map_join(",", add_one)
      assert Enum.to_list(1..500) == pop_args.()
    end

    test "intersperse/2 (vector)" do
      assert [] == Aja.Vector.new() |> Aja.Enum.intersperse(0)

      assert [1, 0, 2, 0, 3, 0, 4, 0, 5] ==
               Aja.Vector.new(1..5) |> Aja.Enum.intersperse(0)

      assert Enum.intersperse(1..50, 0) ==
               Aja.Vector.new(1..50) |> Aja.Enum.intersperse(0)

      assert Enum.intersperse(1..500, 0) ==
               Aja.Vector.new(1..500) |> Aja.Enum.intersperse(0)
    end

    test "map_intersperse/3 (vector)" do
      {add_one, pop_args} = spy_callback(&(&1 + 1))

      assert [] == Aja.Vector.new() |> Aja.Enum.map_intersperse(0, add_one)
      assert [] == pop_args.()

      assert [2, 0, 3, 0, 4, 0, 5, 0, 6] ==
               Aja.Vector.new(1..5) |> Aja.Enum.map_intersperse(0, add_one)

      assert [1, 2, 3, 4, 5] == pop_args.()

      assert Enum.intersperse(2..51, 0) ==
               Aja.Vector.new(1..50) |> Aja.Enum.map_intersperse(0, add_one)

      assert Enum.to_list(1..50) == pop_args.()

      assert Enum.intersperse(2..501, 0) ==
               Aja.Vector.new(1..500) |> Aja.Enum.map_intersperse(0, add_one)

      assert Enum.to_list(1..500) == pop_args.()
    end

    test "each/2 (all types)" do
      {spy, pop_args} = spy_callback(fn _ -> nil end)

      assert :ok = 1..5 |> Aja.Enum.each(spy)
      assert [1, 2, 3, 4, 5] == pop_args.()

      assert :ok = [1, 2, 3, 4, 5] |> Aja.Enum.each(spy)
      assert [1, 2, 3, 4, 5] == pop_args.()

      assert :ok = Aja.Vector.new(1..5) |> Aja.Enum.each(spy)
      assert [1, 2, 3, 4, 5] == pop_args.()

      assert :ok = MapSet.new(1..5) |> Aja.Enum.each(spy)
      assert [1, 2, 3, 4, 5] == pop_args.()
    end

    test "each/2 (vector)" do
      {spy, pop_args} = spy_callback(fn _ -> nil end)

      assert :ok = Aja.Vector.new() |> Aja.Enum.each(spy)
      assert [] == pop_args.()

      assert :ok = Aja.Vector.new(1..5) |> Aja.Enum.each(spy)
      assert [1, 2, 3, 4, 5] == pop_args.()

      assert :ok = Aja.Vector.new(1..50) |> Aja.Enum.each(spy)
      assert Enum.to_list(1..50) == pop_args.()

      assert :ok = Aja.Vector.new(1..500) |> Aja.Enum.each(spy)
      assert Enum.to_list(1..500) == pop_args.()
    end

    test "min/1 (vector)" do
      assert 1 = Aja.Vector.new(1..5) |> Aja.Enum.min()
      assert 1 = Aja.Vector.new(1..50) |> Aja.Enum.min()
      assert 1 = Aja.Vector.new(1..500) |> Aja.Enum.min()

      assert 1 = Aja.Vector.new(5..1) |> Aja.Enum.min()
      assert 1 = Aja.Vector.new(50..1) |> Aja.Enum.min()
      assert 1 = Aja.Vector.new(500..1) |> Aja.Enum.min()
    end

    test "max/1 (vector)" do
      assert 5 = Aja.Vector.new(1..5) |> Aja.Enum.max()
      assert 50 = Aja.Vector.new(1..50) |> Aja.Enum.max()
      assert 500 = Aja.Vector.new(1..500) |> Aja.Enum.max()

      assert 5 = Aja.Vector.new(5..1) |> Aja.Enum.max()
      assert 50 = Aja.Vector.new(50..1) |> Aja.Enum.max()
      assert 500 = Aja.Vector.new(500..1) |> Aja.Enum.max()
    end

    test "min/3" do
      numbers = [4, 2, 5, 1, 3]
      assert 1 = numbers |> Aja.Enum.min()
      assert 1 = Aja.Vector.new(numbers) |> Aja.Enum.min()
      assert 1 = MapSet.new(numbers) |> Aja.Enum.min()
      assert 1 = 1..5 |> Aja.Enum.min()

      dates = [~D[2017-03-31], ~D[2017-04-01]]
      assert ~D[2017-03-31] = dates |> Aja.Enum.min(Date)
      assert ~D[2017-03-31] = Aja.Vector.new(dates) |> Aja.Enum.min(Date)
      assert ~D[2017-03-31] = MapSet.new(dates) |> Aja.Enum.min(Date)

      assert_raise Enum.EmptyError, fn -> [] |> Aja.Enum.min() end
      assert_raise Enum.EmptyError, fn -> Aja.Vector.new() |> Aja.Enum.min() end
      assert_raise Enum.EmptyError, fn -> MapSet.new() |> Aja.Enum.min() end

      assert_raise Enum.EmptyError, fn -> [] |> Aja.Enum.min(&>=/2) end
      assert_raise Enum.EmptyError, fn -> Aja.Vector.new() |> Aja.Enum.min(&>=/2) end
      assert_raise Enum.EmptyError, fn -> MapSet.new() |> Aja.Enum.min(&>=/2) end

      assert 1 = numbers |> Aja.Enum.min(fn -> :empty end)
      assert 1 = Aja.Vector.new(numbers) |> Aja.Enum.min(fn -> :empty end)
      assert 1 = MapSet.new(numbers) |> Aja.Enum.min(fn -> :empty end)
      assert 1 = 1..5 |> Aja.Enum.min(fn -> :empty end)

      assert :empty = [] |> Aja.Enum.min(fn -> :empty end)
      assert :empty = Aja.Vector.new() |> Aja.Enum.min(fn -> :empty end)
      assert :empty = MapSet.new() |> Aja.Enum.min(fn -> :empty end)

      assert 0 = [] |> Aja.Enum.min(&>=/2, fn -> 0 end)
      assert 0 = Aja.Vector.new() |> Aja.Enum.min(&>=/2, fn -> 0 end)
      assert 0 = MapSet.new() |> Aja.Enum.min(&>=/2, fn -> 0 end)
    end

    test "max/3" do
      numbers = [4, 2, 5, 1, 3]
      assert 5 = numbers |> Aja.Enum.max()
      assert 5 = Aja.Vector.new(numbers) |> Aja.Enum.max()
      assert 5 = MapSet.new(numbers) |> Aja.Enum.max()
      assert 5 = 1..5 |> Aja.Enum.max()

      dates = [~D[2017-03-31], ~D[2017-04-01]]
      assert ~D[2017-04-01] = dates |> Aja.Enum.max(Date)
      assert ~D[2017-04-01] = Aja.Vector.new(dates) |> Aja.Enum.max(Date)
      assert ~D[2017-04-01] = MapSet.new(dates) |> Aja.Enum.max(Date)

      assert_raise Enum.EmptyError, fn -> [] |> Aja.Enum.max() end
      assert_raise Enum.EmptyError, fn -> Aja.Vector.new() |> Aja.Enum.max() end
      assert_raise Enum.EmptyError, fn -> MapSet.new() |> Aja.Enum.max() end

      assert_raise Enum.EmptyError, fn -> [] |> Aja.Enum.max(&>=/2) end
      assert_raise Enum.EmptyError, fn -> Aja.Vector.new() |> Aja.Enum.max(&>=/2) end
      assert_raise Enum.EmptyError, fn -> MapSet.new() |> Aja.Enum.max(&>=/2) end

      assert 5 = numbers |> Aja.Enum.max(fn -> :empty end)
      assert 5 = Aja.Vector.new(numbers) |> Aja.Enum.max(fn -> :empty end)
      assert 5 = MapSet.new(numbers) |> Aja.Enum.max(fn -> :empty end)
      assert 5 = 1..5 |> Aja.Enum.max(fn -> :empty end)

      assert :empty = [] |> Aja.Enum.max(fn -> :empty end)
      assert :empty = Aja.Vector.new() |> Aja.Enum.max(fn -> :empty end)
      assert :empty = MapSet.new() |> Aja.Enum.max(fn -> :empty end)

      assert 0 = [] |> Aja.Enum.max(&>=/2, fn -> 0 end)
      assert 0 = Aja.Vector.new() |> Aja.Enum.max(&>=/2, fn -> 0 end)
      assert 0 = MapSet.new() |> Aja.Enum.max(&>=/2, fn -> 0 end)
    end
  end
end
