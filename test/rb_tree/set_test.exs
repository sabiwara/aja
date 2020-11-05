defmodule A.RBTree.SetTest do
  use ExUnit.Case, async: true

  doctest A.RBTree.Set

  test "keeps keys ordered and stays balanced" do
    :rand.seed(:exs1024, {123, 123_534, 345_345})

    sorted = Enum.to_list(1..100_000)

    tree = sorted |> Enum.shuffle() |> A.RBTree.Set.new()

    assert ^sorted = A.RBTree.Set.to_list(tree)
    assert 23 = A.RBTree.Set.height(tree)
    assert 13 = A.RBTree.Set.black_height(tree)
    assert {:ok, 13} = A.RBTree.Set.check_invariant(tree)
    assert true == A.RBTree.Set.member?(tree, 1)
    assert true == A.RBTree.Set.member?(tree, 1.0)
    assert false == A.RBTree.Set.member?(tree, 0)
  end

  test "delete/2" do
    :rand.seed(:exs1024, {123, 123_534, 345_345})

    sorted = Enum.to_list(1..10_000)

    tree = sorted |> Enum.shuffle() |> A.RBTree.Set.new()

    new_tree =
      sorted
      |> Enum.shuffle()
      |> Enum.reduce(tree, fn element, acc ->
        A.RBTree.Set.delete(acc, element)
      end)

    assert new_tree == A.RBTree.Set.empty()
    assert [] = A.RBTree.Set.to_list(new_tree)
  end

  test "member?/2 only returns true for existing elements" do
    key_value = Enum.to_list(1..10_000)
    tree = A.RBTree.Set.new(key_value)

    for i <- 1..length(key_value) do
      assert true == A.RBTree.Set.member?(tree, i + 0.0)
      assert false == A.RBTree.Set.member?(tree, i + 0.5)
    end
  end

  test "iterate/1" do
    map = A.RBTree.Set.new([3, 2, 1])
    iterator = A.RBTree.Set.iterator(map)

    assert {1, iterator} = A.RBTree.Set.next(iterator)
    assert {2, iterator} = A.RBTree.Set.next(iterator)
    assert {3, iterator} = A.RBTree.Set.next(iterator)
    assert nil == A.RBTree.Set.next(iterator)
  end
end
