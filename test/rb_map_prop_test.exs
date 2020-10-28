defmodule A.RBMap.PropTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  # Property-based testing:

  # Those tests are a bit complex, but they should cover a lot of ground and help building confidence
  # that most operations work as they should without any weird edge case

  def key, do: one_of([integer(), float(), string(:printable), atom(:alphanumeric)])

  def value do
    # values probably don't impact the algoithm that much
    # no need to intensively check for arbitrary/huge nested values
    frequency([
      {4, key()},
      {1, term()}
    ])
    |> resize(10)
  end

  def key_value_pairs() do
    list_of(tuple({key(), term()}))
  end

  def operation do
    one_of([
      {:put, key(), value()},
      {:replace_existing, value()},
      {:delete_random, key()},
      :delete_existing
    ])
  end

  def apply_operation(%A.RBMap{} = rb_map, {:put, key, value}) do
    new_map = A.RBMap.put(rb_map, key, value)

    assert value == new_map[key]
    assert value == A.RBMap.fetch!(new_map, key)
    assert A.RBMap.has_key?(new_map, key)

    new_map
  end

  def apply_operation(%A.RBMap{size: 0} = rb_map, {:replace_existing, _value}), do: rb_map

  def apply_operation(%A.RBMap{} = rb_map, {:replace_existing, value}) do
    key = rb_map |> A.RBMap.keys() |> Enum.random()

    # all of those must be equivalent
    new_map = A.RBMap.replace!(rb_map, key, value)
    assert ^new_map = A.RBMap.replace(rb_map, key, value)
    assert ^new_map = A.RBMap.put(rb_map, key, value)
    assert ^new_map = put_in(rb_map, [key], value)
    assert ^new_map = Enum.into([{key, value}], rb_map)
    assert ^new_map = A.RBMap.merge(rb_map, A.RBMap.new([{key, value}]))
    assert ^new_map = A.RBMap.update(rb_map, key, nil, fn _ -> value end)
    assert {_, ^new_map} = A.RBMap.get_and_update!(rb_map, key, fn _ -> {nil, value} end)

    assert A.RBMap.size(new_map) == A.RBMap.size(rb_map)

    new_map
  end

  def apply_operation(%A.RBMap{size: 0} = rb_map, :delete_existing), do: rb_map

  def apply_operation(%A.RBMap{} = rb_map, :delete_existing) do
    {key, value} = rb_map |> Enum.random()

    # all of those must be equivalent
    assert {^value, new_map} = A.RBMap.pop!(rb_map, key)
    assert {^value, ^new_map} = A.RBMap.pop(rb_map, key, nil)
    assert {^value, ^new_map} = pop_in(rb_map, [key])
    assert {^value, ^new_map} = A.RBMap.get_and_update!(rb_map, key, fn _ -> :pop end)

    assert A.RBMap.size(new_map) == A.RBMap.size(rb_map) - 1

    new_map
  end

  def apply_operation(%A.RBMap{} = rb_map, {:delete_random, key}) do
    # all of those must be equivalent
    assert {returned, new_map} = A.RBMap.pop(rb_map, key, nil)
    assert ^new_map = A.RBMap.delete(rb_map, key)
    assert {^returned, ^new_map} = pop_in(rb_map, [key])
    new_map = A.RBMap.drop(rb_map, [key])

    new_map
  end

  def assert_properties(%A.RBMap{} = rb_map) do
    as_list = Enum.to_list(rb_map)

    assert A.RBMap.size(rb_map) == length(as_list)
    assert as_list == Enum.sort(as_list)
    assert {:ok, _} = A.RBTree.check_invariant(rb_map.root)

    assert A.RBMap.first(rb_map) == Enum.min(as_list, fn -> nil end)
    assert A.RBMap.last(rb_map) == Enum.max(as_list, fn -> nil end)
  end

  @tag :property
  property "any series of transformation should yield a valid map" do
    check all(
            initial <- key_value_pairs(),
            operations <- list_of(operation())
          ) do
      initial_map = A.RBMap.new(initial)

      rb_map =
        Enum.reduce(operations, initial_map, fn operation, acc ->
          apply_operation(acc, operation)
        end)

      assert_properties(rb_map)
    end
  end
end
