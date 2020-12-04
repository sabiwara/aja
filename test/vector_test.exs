defmodule A.VectorTest do
  use ExUnit.Case, async: true

  doctest A.Vector

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

  test "append_many/2" do
    assert A.Vector.new() == A.Vector.new() |> A.Vector.append_many([])

    assert A.Vector.new(1..5) == A.Vector.new(1..5) |> A.Vector.append_many([])
    assert A.Vector.new(6..10) == A.Vector.new() |> A.Vector.append_many(6..10)

    assert A.Vector.new(1..10) == A.Vector.new(1..5) |> A.Vector.append_many(6..10)
    assert A.Vector.new(1..20) == A.Vector.new(1..10) |> A.Vector.append_many(11..20)
    assert A.Vector.new(1..100) == A.Vector.new(1..50) |> A.Vector.append_many(51..100)
    assert A.Vector.new(1..1000) == A.Vector.new(1..500) |> A.Vector.append_many(501..1000)
  end

  test "pop_last!/1" do
    range = 1..5_000

    vector =
      Enum.reduce(range, A.Vector.new(), fn value, vec ->
        new_vec = A.Vector.append(vec, value)
        assert {^value, updated} = A.Vector.pop_last!(new_vec)
        assert vec.internal == updated.internal
        assert {^value, ^vec} = A.Vector.pop_last!(new_vec)
        new_vec
      end)

    expected = A.Vector.new(range)
    assert expected == vector
  end

  test "duplicate/2" do
    for i <- Enum.concat(0..50, [500, 5_000, 50_000]) do
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

  test "sum/1" do
    assert 0 = A.Vector.new() |> A.Vector.sum()
    assert 15 = A.Vector.new(1..5) |> A.Vector.sum()
    assert 1275 = A.Vector.new(1..50) |> A.Vector.sum()
    assert 125_250 = A.Vector.new(1..500) |> A.Vector.sum()

    # floats are added in the same order as Enum.sum/1
    floats = 1..50 |> Enum.map(&(&1 * 0.001))
    assert Enum.sum(floats) === A.Vector.new(floats) |> A.Vector.sum()
  end

  test "join/2" do
    assert "" == A.Vector.new() |> A.Vector.join(",")
    assert "1,2,3,4,5" == A.Vector.new(1..5) |> A.Vector.join(",")
    assert Enum.join(1..50, ",") == A.Vector.new(1..50) |> A.Vector.join(",")
    assert Enum.join(1..500, ",") == A.Vector.new(1..500) |> A.Vector.join(",")
  end

  test "min/1" do
    assert 1 = A.Vector.new(1..5) |> A.Vector.min()
    assert 1 = A.Vector.new(1..50) |> A.Vector.min()
    assert 1 = A.Vector.new(1..500) |> A.Vector.min()
  end

  test "max/1" do
    assert 5 = A.Vector.new(1..5) |> A.Vector.max()
    assert 50 = A.Vector.new(1..50) |> A.Vector.max()
    assert 500 = A.Vector.new(1..500) |> A.Vector.max()
  end

  test "map/2" do
    range = 1..5000
    result = range |> A.Vector.new() |> A.Vector.map(&(&1 + 1))
    expected = range |> Enum.map(&(&1 + 1)) |> A.Vector.new()

    assert expected == result
  end

  test "filter/2" do
    range = 1..5000
    multiple_of_2? = &(rem(&1, 2) == 0)
    result = range |> A.Vector.new() |> A.Vector.filter(multiple_of_2?)
    expected = range |> Enum.filter(multiple_of_2?) |> A.Vector.new()

    assert expected == result
  end

  test "Enum.to_list/1" do
    # TODO add some property testing coverage
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

    large = A.Vector.new(1..500)
    refute 0 in large
    assert 1 in large
    assert 5 in large
    assert 50 in large
    assert 500 in large
    refute 501 in large
  end

  test "Enum.slice/2" do
    # TODO add some property testing coverage
    assert [] = A.Vector.new() |> Enum.slice(1..5)
    assert [2, 3, 4, 5, 6] = A.Vector.new(1..100) |> Enum.slice(1..5)
    assert [18, 19] = A.Vector.new(1..20) |> Enum.slice(-3, 2)
  end
end
