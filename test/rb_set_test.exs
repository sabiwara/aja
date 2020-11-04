defmodule A.RBSetTest do
  use ExUnit.Case, async: true

  doctest A.RBSet

  test "new/1" do
    result = A.RBSet.new(1..5)
    assert A.RBSet.equal?(result, Enum.into(1..5, A.RBSet.new()))

    # passing the set again
    assert ^result = A.RBSet.new(result)
  end

  test "new/2" do
    result = A.RBSet.new(1..5, &(&1 + 2))
    assert A.RBSet.equal?(result, Enum.into(3..7, A.RBSet.new()))
  end

  test "put/2" do
    result = A.RBSet.put(A.RBSet.new(), 1)
    assert A.RBSet.equal?(result, A.RBSet.new([1]))

    result = A.RBSet.put(A.RBSet.new([1, 3, 4]), 2)
    assert A.RBSet.equal?(result, A.RBSet.new(1..4))

    result = A.RBSet.put(A.RBSet.new(5..100), 10)
    assert A.RBSet.equal?(result, A.RBSet.new(5..100))
  end

  test "union/2" do
    result = A.RBSet.union(A.RBSet.new([1, 3, 4]), A.RBSet.new())
    assert A.RBSet.equal?(result, A.RBSet.new([1, 3, 4]))

    result = A.RBSet.union(A.RBSet.new(5..15), A.RBSet.new(10..25))
    assert A.RBSet.equal?(result, A.RBSet.new(5..25))

    result = A.RBSet.union(A.RBSet.new(1..120), A.RBSet.new(1..100))
    assert A.RBSet.equal?(result, A.RBSet.new(1..120))
  end

  test "intersection/2" do
    result = A.RBSet.intersection(A.RBSet.new(), A.RBSet.new(1..21))
    assert A.RBSet.equal?(result, A.RBSet.new())

    result = A.RBSet.intersection(A.RBSet.new(1..21), A.RBSet.new(4..24))
    assert A.RBSet.equal?(result, A.RBSet.new(4..21))

    result = A.RBSet.intersection(A.RBSet.new(2..100), A.RBSet.new(1..120))
    assert A.RBSet.equal?(result, A.RBSet.new(2..100))
  end

  test "difference/2" do
    result = A.RBSet.difference(A.RBSet.new(2..20), A.RBSet.new())
    assert A.RBSet.equal?(result, A.RBSet.new(2..20))

    result = A.RBSet.difference(A.RBSet.new(2..20), A.RBSet.new(1..21))
    assert A.RBSet.equal?(result, A.RBSet.new())

    result = A.RBSet.difference(A.RBSet.new(1..101), A.RBSet.new(2..100))
    assert A.RBSet.equal?(result, A.RBSet.new([1, 101]))
  end

  test "disjoint?/2" do
    assert A.RBSet.disjoint?(A.RBSet.new(), A.RBSet.new())
    assert A.RBSet.disjoint?(A.RBSet.new(1..6), A.RBSet.new(8..20))
    refute A.RBSet.disjoint?(A.RBSet.new(1..6), A.RBSet.new(5..15))
    refute A.RBSet.disjoint?(A.RBSet.new(1..120), A.RBSet.new(1..6))
  end

  test "subset?/2" do
    assert A.RBSet.subset?(A.RBSet.new(), A.RBSet.new())
    assert A.RBSet.subset?(A.RBSet.new(1..6), A.RBSet.new(1..10))
    assert A.RBSet.subset?(A.RBSet.new(1..6), A.RBSet.new(1..120))
    refute A.RBSet.subset?(A.RBSet.new(1..120), A.RBSet.new(1..6))
  end

  test "equal?/2" do
    assert A.RBSet.equal?(A.RBSet.new(), A.RBSet.new())
    refute A.RBSet.equal?(A.RBSet.new(1..20), A.RBSet.new(2..21))
    assert A.RBSet.equal?(A.RBSet.new(1..120), A.RBSet.new(1..120))
  end

  test "delete/2" do
    result = A.RBSet.delete(A.RBSet.new(), 1)
    assert A.RBSet.equal?(result, A.RBSet.new())

    result = A.RBSet.delete(A.RBSet.new(1..4), 5)
    assert A.RBSet.equal?(result, A.RBSet.new(1..4))

    result = A.RBSet.delete(A.RBSet.new(1..4), 1)
    assert A.RBSet.equal?(result, A.RBSet.new(2..4))

    result = A.RBSet.delete(A.RBSet.new(1..4), 2)
    assert A.RBSet.equal?(result, A.RBSet.new([1, 3, 4]))
  end

  test "size/1" do
    assert A.RBSet.size(A.RBSet.new()) == 0
    assert A.RBSet.size(A.RBSet.new(5..15)) == 11
    assert A.RBSet.size(A.RBSet.new(2..100)) == 99
  end

  test "to_list/1" do
    assert A.RBSet.to_list(A.RBSet.new()) == []

    list = A.RBSet.to_list(A.RBSet.new(1..20))
    assert Enum.sort(list) == Enum.to_list(1..20)

    list = A.RBSet.to_list(A.RBSet.new(5..120))
    assert Enum.sort(list) == Enum.to_list(5..120)
  end

  test "inspect" do
    assert inspect(A.RBSet.new([?a])) == "#A.RBSet<[97]>"
  end
end
