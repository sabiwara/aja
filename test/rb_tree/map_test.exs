defmodule A.RBTree.MapTest do
  use ExUnit.Case, async: true

  doctest A.RBTree.Map

  test "keeps keys ordered and stays balanced" do
    :rand.seed(:exs1024, {123, 123_534, 345_345})

    key_value = 1..100_000 |> Enum.map(fn i -> {i, i + 1} end)

    tree = key_value |> Enum.shuffle() |> A.RBTree.Map.new()

    assert ^key_value = A.RBTree.Map.to_list(tree)
    assert 23 = A.RBTree.Map.height(tree)
    assert 13 = A.RBTree.Map.black_height(tree)
    assert {:ok, 13} = A.RBTree.Map.check_invariant(tree)
    {:ok, 2} = A.RBTree.Map.fetch(tree, 1)
    {:ok, 2} = A.RBTree.Map.fetch(tree, 1.0)
    :error = A.RBTree.Map.fetch(tree, 0)
  end

  test "pop/2" do
    :rand.seed(:exs1024, {123, 123_534, 345_345})

    key_value = 1..10_000 |> Enum.map(fn i -> {i, i + 1} end)

    tree = key_value |> Enum.shuffle() |> A.RBTree.Map.new()

    new_tree =
      key_value
      |> Enum.shuffle()
      |> Enum.reduce(tree, fn {key, value}, acc ->
        assert {^value, new_acc} = A.RBTree.Map.pop(acc, key)
        new_acc
      end)

    assert new_tree == A.RBTree.Map.empty()
    assert [] = A.RBTree.Map.to_list(new_tree)
  end

  test "map_fetch/2 only returns existing values" do
    key_value = Enum.map(1..10_000, fn i -> {i, i} end)
    tree = A.RBTree.Map.new(key_value)

    for i <- 1..length(key_value) do
      assert {:ok, ^i} = A.RBTree.Map.fetch(tree, i + 0.0)
      assert :error = A.RBTree.Map.fetch(tree, i + 0.5)
    end
  end

  test "iterate/1" do
    map = A.RBTree.Map.new([{3, "三"}, {1, "一"}, {2, "二"}])
    iterator = A.RBTree.Map.iterator(map)

    assert {1, "一", iterator} = A.RBTree.Map.next(iterator)
    assert {2, "二", iterator} = A.RBTree.Map.next(iterator)
    assert {3, "三", iterator} = A.RBTree.Map.next(iterator)
    assert nil == A.RBTree.Map.next(iterator)
  end
end
