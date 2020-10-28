defmodule A.RBTreeTest do
  use ExUnit.Case, async: true

  doctest A.RBTree

  test "keeps keys ordered and stays balanced (map API)" do
    :rand.seed(:exs1024, {123, 123_534, 345_345})

    key_value = 1..100_000 |> Enum.map(fn i -> {i, i + 1} end)

    tree = key_value |> Enum.shuffle() |> A.RBTree.map_new()

    assert ^key_value = A.RBTree.to_list(tree)
    assert 23 = A.RBTree.height(tree)
    assert 13 = A.RBTree.black_height(tree)
    assert {:ok, 13} = A.RBTree.check_invariant(tree)
    {:ok, 2} = A.RBTree.map_fetch(tree, 1)
    {:ok, 2} = A.RBTree.map_fetch(tree, 1.0)
    :error = A.RBTree.map_fetch(tree, 0)
  end

  test "keeps keys ordered and stays balanced (set API)" do
    :rand.seed(:exs1024, {123, 123_534, 345_345})

    sorted = Enum.to_list(1..100_000)

    tree = sorted |> Enum.shuffle() |> A.RBTree.set_new()

    assert ^sorted = A.RBTree.to_list(tree)
    assert 23 = A.RBTree.height(tree)
    assert 13 = A.RBTree.black_height(tree)
    assert {:ok, 13} = A.RBTree.check_invariant(tree)
    assert true == A.RBTree.set_member?(tree, 1)
    assert true == A.RBTree.set_member?(tree, 1.0)
    assert false == A.RBTree.set_member?(tree, 0)
  end

  test "map_fetch/2 only returns existing values" do
    key_value = Enum.map(1..10_000, fn i -> {i, i} end)
    tree = A.RBTree.map_new(key_value)

    for i <- 1..length(key_value) do
      assert {:ok, ^i} = A.RBTree.map_fetch(tree, i + 0.0)
      assert :error = A.RBTree.map_fetch(tree, i + 0.5)
    end
  end

  test "has_member?/2 only returns true for existing elements" do
    key_value = Enum.to_list(1..10_000)
    tree = A.RBTree.set_new(key_value)

    for i <- 1..length(key_value) do
      assert true == A.RBTree.set_member?(tree, i + 0.0)
      assert false == A.RBTree.set_member?(tree, i + 0.5)
    end
  end

  test "iterate/1" do
    map = A.RBTree.map_new([{3, "三"}, {1, "一"}, {2, "二"}])
    iterator = A.RBTree.iterator(map)

    assert {{1, "一"}, iterator} = A.RBTree.next(iterator)
    assert {{2, "二"}, iterator} = A.RBTree.next(iterator)
    assert {{3, "三"}, iterator} = A.RBTree.next(iterator)
    assert nil == A.RBTree.next(iterator)
  end
end
