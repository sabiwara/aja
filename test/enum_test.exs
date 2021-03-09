defmodule A.EnumTest do
  use ExUnit.Case, async: true

  doctest A.Enum

  # TODO move to test helper
  defp spy_callback(fun) do
    {:ok, agent} = Agent.start_link(fn -> [] end)

    callback = fn arg ->
      Agent.update(agent, fn state -> [arg | state] end)
      fun.(arg)
    end

    pop_args = fn ->
      Agent.get_and_update(agent, fn state -> {Enum.reverse(state), []} end)
    end

    {callback, pop_args}
  end

  test "all?/1 (vector)" do
    assert true == A.Vector.new() |> A.Enum.all?()

    assert true == A.Vector.new([1, true, "string", :atom, %{}, []]) |> A.Enum.all?()
    assert true == A.Vector.new(1..50) |> A.Enum.all?()
    assert true == A.Vector.new(1..500) |> A.Enum.all?()

    assert false == A.Vector.duplicate(true, 5) |> A.Vector.append(false) |> A.Enum.all?()
    assert false == A.Vector.new(1..50) |> A.Vector.append(nil) |> A.Enum.all?()
    assert false == A.Vector.new(1..500) |> A.Vector.append(nil) |> A.Enum.all?()
  end

  test "all?/2 (vector)" do
    {gt_zero?, pop_args} = spy_callback(&(&1 > 0))

    assert true == A.Vector.new() |> A.Enum.all?(gt_zero?)
    assert [] == pop_args.()

    assert true == A.Vector.new(5..1) |> A.Enum.all?(gt_zero?)
    assert [5, 4, 3, 2, 1] == pop_args.()

    assert true == A.Vector.new(50..1) |> A.Enum.all?(gt_zero?)
    assert Enum.to_list(50..1) == pop_args.()

    assert true == A.Vector.new(500..1) |> A.Enum.all?(gt_zero?)
    assert Enum.to_list(500..1) == pop_args.()

    assert false == A.Vector.new(5..0) |> A.Enum.all?(gt_zero?)
    assert [5, 4, 3, 2, 1, 0] == pop_args.()

    assert false == A.Vector.new(50..0) |> A.Enum.all?(gt_zero?)
    assert Enum.to_list(50..0) == pop_args.()

    assert false == A.Vector.new(500..0) |> A.Enum.all?(gt_zero?)
    assert Enum.to_list(500..0) == pop_args.()
  end

  test "any?/1 (vector)" do
    assert false == A.Vector.new() |> A.Enum.any?()

    assert false == A.Vector.duplicate(false, 5) |> A.Enum.any?()
    assert false == A.Vector.duplicate(nil, 50) |> A.Enum.any?()
    assert false == A.Vector.duplicate(false, 500) |> A.Enum.any?()

    assert true == A.Vector.duplicate(false, 5) |> A.Vector.append(true) |> A.Enum.any?()
    assert true == A.Vector.duplicate(nil, 50) |> A.Vector.append(55) |> A.Enum.any?()
    assert true == A.Vector.duplicate(false, 500) |> A.Vector.append(%{}) |> A.Enum.any?()
  end

  test "any?/2 (vector)" do
    {lt_zero?, pop_args} = spy_callback(&(&1 < 0))

    assert false == A.Vector.new() |> A.Enum.any?(lt_zero?)
    assert [] == pop_args.()

    assert false == A.Vector.new(5..0) |> A.Enum.any?(lt_zero?)
    assert [5, 4, 3, 2, 1, 0] == pop_args.()

    assert false == A.Vector.new(50..0) |> A.Enum.any?(lt_zero?)
    assert Enum.to_list(50..0) == pop_args.()

    assert false == A.Vector.new(500..0) |> A.Enum.any?(lt_zero?)
    assert Enum.to_list(500..0) == pop_args.()

    assert true == A.Vector.new(5..-5) |> A.Enum.any?(lt_zero?)
    assert [5, 4, 3, 2, 1, 0, -1] == pop_args.()

    assert true == A.Vector.new(50..-50) |> A.Enum.any?(lt_zero?)
    assert Enum.to_list(50..-1) == pop_args.()

    assert true == A.Vector.new(500..-500) |> A.Enum.any?(lt_zero?)
    assert Enum.to_list(500..-1) == pop_args.()
  end

  test "find/2 (vector)" do
    {lt_zero?, pop_args} = spy_callback(&(&1 < 0))

    assert nil == A.Vector.new() |> A.Enum.find(lt_zero?)
    assert [] == pop_args.()

    assert nil == A.Vector.new(5..0) |> A.Enum.find(lt_zero?)
    assert [5, 4, 3, 2, 1, 0] == pop_args.()

    assert nil == A.Vector.new(50..0) |> A.Enum.find(lt_zero?)
    assert Enum.to_list(50..0) == pop_args.()

    assert nil == A.Vector.new(500..0) |> A.Enum.find(lt_zero?)
    assert Enum.to_list(500..0) == pop_args.()

    assert -1 == A.Vector.new(5..-5) |> A.Enum.find(lt_zero?)
    assert [5, 4, 3, 2, 1, 0, -1] == pop_args.()

    assert -1 == A.Vector.new(50..-50) |> A.Enum.find(lt_zero?)
    assert Enum.to_list(50..-1) == pop_args.()

    assert -1 == A.Vector.new(500..-500) |> A.Enum.find(lt_zero?)
    assert Enum.to_list(500..-1) == pop_args.()
  end

  test "find_value/2 (vector)" do
    {spy, pop_args} =
      spy_callback(fn
        x when x < 0 -> -x
        _ -> nil
      end)

    assert nil == A.Vector.new() |> A.Enum.find_value(spy)
    assert [] == pop_args.()

    assert nil == A.Vector.new(5..0) |> A.Enum.find_value(spy)
    assert [5, 4, 3, 2, 1, 0] == pop_args.()

    assert nil == A.Vector.new(50..0) |> A.Enum.find_value(spy)
    assert Enum.to_list(50..0) == pop_args.()

    assert nil == A.Vector.new(500..0) |> A.Enum.find_value(spy)
    assert Enum.to_list(500..0) == pop_args.()

    assert 1 == A.Vector.new(5..-5) |> A.Enum.find_value(spy)
    assert [5, 4, 3, 2, 1, 0, -1] == pop_args.()

    assert 1 == A.Vector.new(50..-50) |> A.Enum.find_value(spy)
    assert Enum.to_list(50..-1) == pop_args.()

    assert 1 == A.Vector.new(500..-500) |> A.Enum.find_value(spy)
    assert Enum.to_list(500..-1) == pop_args.()
  end

  test "find_index/2 (vector)" do
    {lt_zero?, pop_args} = spy_callback(&(&1 < 0))

    assert nil == A.Vector.new() |> A.Enum.find_index(lt_zero?)
    assert [] == pop_args.()

    assert nil == A.Vector.new(5..0) |> A.Enum.find_index(lt_zero?)
    assert [5, 4, 3, 2, 1, 0] == pop_args.()

    assert nil == A.Vector.new(50..0) |> A.Enum.find_index(lt_zero?)
    assert Enum.to_list(50..0) == pop_args.()

    assert nil == A.Vector.new(500..0) |> A.Enum.find_index(lt_zero?)
    assert Enum.to_list(500..0) == pop_args.()

    assert 6 == A.Vector.new(5..-5) |> A.Enum.find_index(lt_zero?)
    assert [5, 4, 3, 2, 1, 0, -1] == pop_args.()

    assert 51 == A.Vector.new(50..-50) |> A.Enum.find_index(lt_zero?)
    assert Enum.to_list(50..-1) == pop_args.()

    assert 501 == A.Vector.new(500..-500) |> A.Enum.find_index(lt_zero?)
    assert Enum.to_list(500..-1) == pop_args.()
  end

  test "sum/1 (vector)" do
    assert 0 = A.Vector.new() |> A.Enum.sum()
    assert 15 = A.Vector.new(1..5) |> A.Enum.sum()
    assert 1275 = A.Vector.new(1..50) |> A.Enum.sum()
    assert 125_250 = A.Vector.new(1..500) |> A.Enum.sum()

    # floats are added in the same order as Enum.sum/1
    floats = 1..50 |> Enum.map(&(&1 * 0.001))
    assert Enum.sum(floats) === A.Vector.new(floats) |> A.Enum.sum()
  end

  test "product/1 (vector)" do
    assert 1 = A.Vector.new() |> A.Enum.product()
    assert 120 = A.Vector.new(1..5) |> A.Enum.product()
    assert Enum.reduce(1..50, &(&2 * &1)) == A.Vector.new(1..50) |> A.Enum.product()
    assert Enum.reduce(1..500, &(&2 * &1)) == A.Vector.new(1..500) |> A.Enum.product()
  end

  test "join/2 (vector)" do
    assert "" == A.Vector.new() |> A.Enum.join(",")
    assert "1" == A.Vector.new([1]) |> A.Enum.join(",")
    assert "1,2,3,4,5" == A.Vector.new(1..5) |> A.Enum.join(",")
    assert Enum.join(1..50, ",") == A.Vector.new(1..50) |> A.Enum.join(",")
    assert Enum.join(1..500, ",") == A.Vector.new(1..500) |> A.Enum.join(",")

    assert Enum.join(1..50) == A.Vector.new(1..50) |> A.Enum.join()
  end

  test "map_join/3 (vector)" do
    {add_one, pop_args} = spy_callback(&(&1 + 1))

    assert "" == A.Vector.new() |> A.Enum.map_join(",", add_one)
    assert [] == pop_args.()

    assert "2,3,4,5,6" == A.Vector.new(1..5) |> A.Enum.map_join(",", add_one)
    assert [1, 2, 3, 4, 5] == pop_args.()

    assert Enum.join(2..51, ",") == A.Vector.new(1..50) |> A.Enum.map_join(",", add_one)
    assert Enum.to_list(1..50) == pop_args.()

    assert Enum.join(2..501, ",") == A.Vector.new(1..500) |> A.Enum.map_join(",", add_one)
    assert Enum.to_list(1..500) == pop_args.()
  end

  test "intersperse/2 (vector)" do
    assert [] == A.Vector.new() |> A.Enum.intersperse(0)

    assert [1, 0, 2, 0, 3, 0, 4, 0, 5] ==
             A.Vector.new(1..5) |> A.Enum.intersperse(0)

    assert Enum.intersperse(1..50, 0) ==
             A.Vector.new(1..50) |> A.Enum.intersperse(0)

    assert Enum.intersperse(1..500, 0) ==
             A.Vector.new(1..500) |> A.Enum.intersperse(0)
  end

  test "map_intersperse/3 (vector)" do
    {add_one, pop_args} = spy_callback(&(&1 + 1))

    assert [] == A.Vector.new() |> A.Enum.map_intersperse(0, add_one)
    assert [] == pop_args.()

    assert [2, 0, 3, 0, 4, 0, 5, 0, 6] ==
             A.Vector.new(1..5) |> A.Enum.map_intersperse(0, add_one)

    assert [1, 2, 3, 4, 5] == pop_args.()

    assert Enum.intersperse(2..51, 0) ==
             A.Vector.new(1..50) |> A.Enum.map_intersperse(0, add_one)

    assert Enum.to_list(1..50) == pop_args.()

    assert Enum.intersperse(2..501, 0) ==
             A.Vector.new(1..500) |> A.Enum.map_intersperse(0, add_one)

    assert Enum.to_list(1..500) == pop_args.()
  end

  test "each/2 (all types)" do
    {spy, pop_args} = spy_callback(fn _ -> nil end)

    assert :ok = 1..5 |> A.Enum.each(spy)
    assert [1, 2, 3, 4, 5] == pop_args.()

    assert :ok = [1, 2, 3, 4, 5] |> A.Enum.each(spy)
    assert [1, 2, 3, 4, 5] == pop_args.()

    assert :ok = A.Vector.new(1..5) |> A.Enum.each(spy)
    assert [1, 2, 3, 4, 5] == pop_args.()

    assert :ok = MapSet.new(1..5) |> A.Enum.each(spy)
    assert [1, 2, 3, 4, 5] == pop_args.()
  end

  test "each/2 (vector)" do
    {spy, pop_args} = spy_callback(fn _ -> nil end)

    assert :ok = A.Vector.new() |> A.Enum.each(spy)
    assert [] == pop_args.()

    assert :ok = A.Vector.new(1..5) |> A.Enum.each(spy)
    assert [1, 2, 3, 4, 5] == pop_args.()

    assert :ok = A.Vector.new(1..50) |> A.Enum.each(spy)
    assert Enum.to_list(1..50) == pop_args.()

    assert :ok = A.Vector.new(1..500) |> A.Enum.each(spy)
    assert Enum.to_list(1..500) == pop_args.()
  end

  test "min/1 (vector)" do
    assert 1 = A.Vector.new(1..5) |> A.Enum.min()
    assert 1 = A.Vector.new(1..50) |> A.Enum.min()
    assert 1 = A.Vector.new(1..500) |> A.Enum.min()

    assert 1 = A.Vector.new(5..1) |> A.Enum.min()
    assert 1 = A.Vector.new(50..1) |> A.Enum.min()
    assert 1 = A.Vector.new(500..1) |> A.Enum.min()
  end

  test "max/1 (vector)" do
    assert 5 = A.Vector.new(1..5) |> A.Enum.max()
    assert 50 = A.Vector.new(1..50) |> A.Enum.max()
    assert 500 = A.Vector.new(1..500) |> A.Enum.max()

    assert 5 = A.Vector.new(5..1) |> A.Enum.max()
    assert 50 = A.Vector.new(50..1) |> A.Enum.max()
    assert 500 = A.Vector.new(500..1) |> A.Enum.max()
  end

  test "min/3" do
    numbers = [4, 2, 5, 1, 3]
    assert 1 = numbers |> A.Enum.min()
    assert 1 = A.Vector.new(numbers) |> A.Enum.min()
    assert 1 = MapSet.new(numbers) |> A.Enum.min()
    assert 1 = 1..5 |> A.Enum.min()

    dates = [~D[2017-03-31], ~D[2017-04-01]]
    assert ~D[2017-03-31] = dates |> A.Enum.min(Date)
    assert ~D[2017-03-31] = A.Vector.new(dates) |> A.Enum.min(Date)
    assert ~D[2017-03-31] = MapSet.new(dates) |> A.Enum.min(Date)

    assert_raise Enum.EmptyError, fn -> [] |> A.Enum.min() end
    assert_raise Enum.EmptyError, fn -> A.Vector.new() |> A.Enum.min() end
    assert_raise Enum.EmptyError, fn -> MapSet.new() |> A.Enum.min() end

    assert_raise Enum.EmptyError, fn -> [] |> A.Enum.min(&>=/2) end
    assert_raise Enum.EmptyError, fn -> A.Vector.new() |> A.Enum.min(&>=/2) end
    assert_raise Enum.EmptyError, fn -> MapSet.new() |> A.Enum.min(&>=/2) end

    assert 1 = numbers |> A.Enum.min(fn -> :empty end)
    assert 1 = A.Vector.new(numbers) |> A.Enum.min(fn -> :empty end)
    assert 1 = MapSet.new(numbers) |> A.Enum.min(fn -> :empty end)
    assert 1 = 1..5 |> A.Enum.min(fn -> :empty end)

    assert :empty = [] |> A.Enum.min(fn -> :empty end)
    assert :empty = A.Vector.new() |> A.Enum.min(fn -> :empty end)
    assert :empty = MapSet.new() |> A.Enum.min(fn -> :empty end)

    assert 0 = [] |> A.Enum.min(&>=/2, fn -> 0 end)
    assert 0 = A.Vector.new() |> A.Enum.min(&>=/2, fn -> 0 end)
    assert 0 = MapSet.new() |> A.Enum.min(&>=/2, fn -> 0 end)
  end

  test "max/3" do
    numbers = [4, 2, 5, 1, 3]
    assert 5 = numbers |> A.Enum.max()
    assert 5 = A.Vector.new(numbers) |> A.Enum.max()
    assert 5 = MapSet.new(numbers) |> A.Enum.max()
    assert 5 = 1..5 |> A.Enum.max()

    dates = [~D[2017-03-31], ~D[2017-04-01]]
    assert ~D[2017-04-01] = dates |> A.Enum.max(Date)
    assert ~D[2017-04-01] = A.Vector.new(dates) |> A.Enum.max(Date)
    assert ~D[2017-04-01] = MapSet.new(dates) |> A.Enum.max(Date)

    assert_raise Enum.EmptyError, fn -> [] |> A.Enum.max() end
    assert_raise Enum.EmptyError, fn -> A.Vector.new() |> A.Enum.max() end
    assert_raise Enum.EmptyError, fn -> MapSet.new() |> A.Enum.max() end

    assert_raise Enum.EmptyError, fn -> [] |> A.Enum.max(&>=/2) end
    assert_raise Enum.EmptyError, fn -> A.Vector.new() |> A.Enum.max(&>=/2) end
    assert_raise Enum.EmptyError, fn -> MapSet.new() |> A.Enum.max(&>=/2) end

    assert 5 = numbers |> A.Enum.max(fn -> :empty end)
    assert 5 = A.Vector.new(numbers) |> A.Enum.max(fn -> :empty end)
    assert 5 = MapSet.new(numbers) |> A.Enum.max(fn -> :empty end)
    assert 5 = 1..5 |> A.Enum.max(fn -> :empty end)

    assert :empty = [] |> A.Enum.max(fn -> :empty end)
    assert :empty = A.Vector.new() |> A.Enum.max(fn -> :empty end)
    assert :empty = MapSet.new() |> A.Enum.max(fn -> :empty end)

    assert 0 = [] |> A.Enum.max(&>=/2, fn -> 0 end)
    assert 0 = A.Vector.new() |> A.Enum.max(&>=/2, fn -> 0 end)
    assert 0 = MapSet.new() |> A.Enum.max(&>=/2, fn -> 0 end)
  end

  test "A.Enum.sort_uniq/1" do
    assert [] = A.Enum.sort_uniq([])
    assert [1, 2, 3] = A.Enum.sort_uniq([3, 3, 3, 2, 2, 1])
    assert [1, 2, 3, 4, 5] = A.Enum.sort_uniq(5..1)
    assert [1.0, 1, 2.0, 2] = A.Enum.sort_uniq([2, 1, 1.0, 2.0])
  end
end
