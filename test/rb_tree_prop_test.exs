defmodule A.RBTree.PropTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  def key, do: one_of([integer(), float(), string(:printable)])

  def key_value_pairs() do
    list_of(tuple({key(), term()}))
  end

  def values do
    list_of(term())
  end

  # Map API properties

  @tag :property
  property "map_fetch/2 always finds an existing key" do
    check all(
            initial <- key_value_pairs(),
            key <- key(),
            value <- term()
          ) do
      {_, tree} = A.RBTree.map_new(initial) |> A.RBTree.map_insert(key, value)

      {:ok, ^value} = A.RBTree.map_fetch(tree, key)
    end
  end

  @tag :property
  property "map_fetch/2 never finds a non-existing key" do
    check all(
            initial <- key_value_pairs(),
            key <- key()
          ) do
      without_key = for {k, v} <- initial, k != key, do: {k, v}
      tree = A.RBTree.map_new(without_key)

      :error = A.RBTree.map_fetch(tree, key)
    end
  end

  @tag :property
  property "map_pop/3 respects the red black invariant when key present" do
    check all(
            initial <- key_value_pairs(),
            key <- key(),
            value <- term()
          ) do
      {_, tree} = A.RBTree.map_new(initial) |> A.RBTree.map_insert(key, value)

      {:ok, ^value, new_tree} = A.RBTree.map_pop(tree, key)

      assert new_tree !== tree

      assert :error = A.RBTree.map_fetch(new_tree, key)

      assert {:ok, black_height} = A.RBTree.check_invariant(new_tree)
      assert black_height >= 0
    end
  end

  # Set API properties

  @tag :property
  property "set_member?/2 always returns false for an existing value" do
    check all(
            initial <- values(),
            value <- term()
          ) do
      tree = A.RBTree.set_new([value | initial])

      assert true == A.RBTree.set_member?(tree, value)
    end
  end

  @tag :property
  property "set_member?/2 always returns false for a non-existing value" do
    check all(
            initial <- values(),
            value <- term()
          ) do
      # important: do NOT use strict equality here
      without_value = Enum.filter(initial, &(&1 != value))
      tree = A.RBTree.set_new(without_value)

      assert false == A.RBTree.set_member?(tree, value)
    end
  end

  @tag :property
  property "set_delete/2 respects the red black invariant when key present" do
    check all(
            initial <- key_value_pairs(),
            value <- term()
          ) do
      tree = A.RBTree.set_new([value | initial])

      {:ok, new_tree} = A.RBTree.set_delete(tree, value)

      assert new_tree !== tree

      assert true == A.RBTree.set_member?(tree, value)
      assert false == A.RBTree.set_member?(new_tree, value)

      assert {:ok, black_height} = A.RBTree.check_invariant(new_tree)
      assert black_height >= 0
    end
  end
end
