defmodule A.RBSetTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest A.RBSet

  # Property testing:

  # This test is a bit complex, but it should cover a lot of ground and helps building the confidence that
  # most operations work as they should without any weird edge case

  def simple_value, do: one_of([integer(), float(), string(:printable), atom(:alphanumeric)])

  def value do
    # prefer simple values which will should be more representative of actual uses, but keep exploring
    frequency([
      {4, simple_value()},
      {1, term()}
    ])
  end

  def operation do
    one_of([
      {:put, value()},
      :put_existing,
      {:delete_random, value()},
      :delete_existing
    ])
  end

  def apply_operation(%A.RBSet{} = rb_set, {:put, value}) do
    new_set = A.RBSet.put(rb_set, value)

    assert A.RBSet.member?(new_set, value)
    assert value in new_set

    new_set
  end

  def apply_operation(%A.RBSet{size: 0} = rb_set, :put_existing), do: rb_set

  def apply_operation(%A.RBSet{} = rb_set, :put_existing) do
    value = Enum.random(rb_set)

    # all of those must be equivalent
    new_set = A.RBSet.put(rb_set, value)
    assert ^new_set = A.RBSet.union(rb_set, A.RBSet.new([value]))
    assert ^new_set = Enum.into([value], A.RBSet.new(rb_set))

    assert A.RBSet.size(new_set) == A.RBSet.size(rb_set)
    assert A.RBSet.equal?(new_set, rb_set)
    assert Enum.to_list(new_set) == Enum.to_list(rb_set)

    new_set
  end

  def apply_operation(%A.RBSet{size: 0} = rb_set, :delete_existing), do: rb_set

  def apply_operation(%A.RBSet{} = rb_set, :delete_existing) do
    value = Enum.random(rb_set)

    # all of those must be equivalent
    assert new_set = A.RBSet.delete(rb_set, value)
    assert ^new_set = A.RBSet.difference(rb_set, A.RBSet.new([value]))

    assert A.RBSet.size(new_set) == A.RBSet.size(rb_set) - 1
    refute A.RBSet.equal?(new_set, rb_set)
    assert Enum.to_list(new_set) == Enum.to_list(rb_set) -- [value]

    assert A.RBSet.subset?(new_set, rb_set)
    refute A.RBSet.subset?(rb_set, new_set)

    new_set
  end

  def apply_operation(%A.RBSet{} = rb_set, {:delete_random, value}) do
    # all of those must be equivalent
    assert new_set = A.RBSet.delete(rb_set, value)
    assert ^new_set = A.RBSet.difference(rb_set, A.RBSet.new([value]))

    new_set
  end

  def assert_properties(%A.RBSet{} = rb_set) do
    as_list = Enum.to_list(rb_set)
    assert A.RBSet.size(rb_set) == length(as_list)
    assert as_list == Enum.sort(as_list)
    assert {:ok, _} = A.RBTree.check_invariant(rb_set.root)

    assert A.RBSet.equal?(A.RBSet.intersection(rb_set, rb_set), rb_set)
    assert A.RBSet.equal?(A.RBSet.union(rb_set, rb_set), rb_set)
    assert A.RBSet.difference(rb_set, rb_set) == A.RBSet.new()
    assert A.RBSet.subset?(rb_set, rb_set)

    assert A.RBSet.first(rb_set) == Enum.min(as_list, fn -> nil end)
    assert A.RBSet.last(rb_set) == Enum.max(as_list, fn -> nil end)
  end

  @tag :property
  property "any series of transformation should yield a valid set" do
    check all(
            initial <- list_of(value()),
            operations <- list_of(operation())
          ) do
      initial_set = A.RBSet.new(initial)

      rb_set =
        Enum.reduce(operations, initial_set, fn operation, acc ->
          apply_operation(acc, operation)
        end)

      assert_properties(rb_set)
    end
  end

  @tag :property
  property "operations on two sets produce consistent results" do
    check all(
            list1 <- list_of(value()),
            list2 <- list_of(value())
          ) do
      rb_set1 = A.RBSet.new(list1)
      rb_set2 = A.RBSet.new(list2)

      union = A.RBSet.union(rb_set1, rb_set2)
      intersection = A.RBSet.intersection(rb_set1, rb_set2)
      diff_1_2 = A.RBSet.difference(rb_set1, rb_set2)
      diff_2_1 = A.RBSet.difference(rb_set2, rb_set1)

      assert A.RBSet.size(union) ==
               A.RBSet.size(intersection) +
                 A.RBSet.size(diff_1_2) +
                 A.RBSet.size(diff_2_1)

      assert Enum.to_list(diff_1_2) == Enum.to_list(rb_set1) -- Enum.to_list(rb_set2)
      assert Enum.to_list(diff_2_1) == Enum.to_list(rb_set2) -- Enum.to_list(rb_set1)

      assert A.RBSet.subset?(diff_1_2, rb_set1)
      assert A.RBSet.subset?(diff_2_1, rb_set2)
      assert A.RBSet.subset?(rb_set1, union)
      assert A.RBSet.subset?(rb_set2, union)
      assert A.RBSet.subset?(intersection, rb_set1)
      assert A.RBSet.subset?(intersection, rb_set2)

      assert A.RBSet.equal?(union, Enum.into(rb_set1, rb_set2))
      assert A.RBSet.equal?(union, Enum.into(rb_set2, rb_set1))

      assert_properties(union)
      assert_properties(intersection)
      assert_properties(diff_1_2)
      assert_properties(diff_2_1)
    end
  end
end
