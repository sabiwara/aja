defmodule A.RBTree.Set.PropTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  def elements do
    list_of(term())
  end

  @tag :property
  property "member?/2 always returns false for an existing element" do
    check all(
            initial <- elements(),
            element <- term()
          ) do
      tree = A.RBTree.Set.new([element | initial])

      assert true == A.RBTree.Set.member?(tree, element)
    end
  end

  @tag :property
  property "member?/2 always returns false for a non-existing element" do
    check all(
            initial <- elements(),
            element <- term()
          ) do
      # important: do NOT use strict equality here
      without_element = Enum.filter(initial, &(&1 != element))
      tree = A.RBTree.Set.new(without_element)

      assert false == A.RBTree.Set.member?(tree, element)
    end
  end

  @tag :property
  property "delete/2 respects the red black invariant when key present" do
    check all(
            initial <- elements(),
            element <- term()
          ) do
      tree = A.RBTree.Set.new([element | initial])

      new_tree = A.RBTree.Set.delete(tree, element)
      assert new_tree != :error

      assert new_tree !== tree

      assert true == A.RBTree.Set.member?(tree, element)
      assert false == A.RBTree.Set.member?(new_tree, element)

      assert {:ok, black_height} = A.RBTree.Set.check_invariant(new_tree)
      assert black_height >= 0
    end
  end
end
