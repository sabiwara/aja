defmodule A.RBTree.Map.PropTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  defp key, do: one_of([integer(), float(), string(:printable)])

  defp key_value_pairs() do
    list_of(tuple({key(), term()}))
  end

  @tag :property
  property "fetch/2 always finds an existing key" do
    check all(
            initial <- key_value_pairs(),
            key <- key(),
            value <- term()
          ) do
      {_, tree} = A.RBTree.Map.new(initial) |> A.RBTree.Map.insert(key, value)

      {:ok, ^value} = A.RBTree.Map.fetch(tree, key)
    end
  end

  @tag :property
  property "fetch/2 never finds a non-existing key" do
    check all(
            initial <- key_value_pairs(),
            key <- key()
          ) do
      without_key = for {k, v} <- initial, k != key, do: {k, v}
      tree = A.RBTree.Map.new(without_key)

      :error = A.RBTree.Map.fetch(tree, key)
    end
  end

  @tag :property
  property "pop/3 respects the red black invariant when key present" do
    check all(
            initial <- key_value_pairs(),
            key <- key(),
            value <- term()
          ) do
      {_, tree} = A.RBTree.Map.new(initial) |> A.RBTree.Map.insert(key, value)

      {^value, new_tree} = A.RBTree.Map.pop(tree, key)

      assert new_tree !== tree

      # popping twice does nothing
      assert :error = A.RBTree.Map.pop(new_tree, key)

      assert :error = A.RBTree.Map.fetch(new_tree, key)

      assert {:ok, black_height} = A.RBTree.Map.check_invariant(new_tree)
      assert black_height >= 0
    end
  end
end
