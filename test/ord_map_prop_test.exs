defmodule A.OrdMap.PropTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import A

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

  def apply_operation(%A.OrdMap{} = ord_map, {:put, key, value}) do
    new_map = A.OrdMap.put(ord_map, key, value)

    assert value == new_map[key]
    assert value == A.OrdMap.fetch!(new_map, key)
    assert A.OrdMap.has_key?(new_map, key)

    new_map
  end

  def apply_operation(ord_map, {:replace_existing, _value}) when ord_size(ord_map) == 0 do
    ord_map
  end

  def apply_operation(%A.OrdMap{} = ord_map, {:replace_existing, value}) do
    key = ord_map |> A.OrdMap.keys() |> Enum.random()

    # all of those are equivalent
    new_map = A.OrdMap.replace!(ord_map, key, value)
    assert ^new_map = A.OrdMap.replace(ord_map, key, value)
    assert ^new_map = A.OrdMap.put(ord_map, key, value)
    assert ^new_map = put_in(ord_map, [key], value)
    assert ^new_map = Enum.into([{key, value}], ord_map)
    assert ^new_map = A.OrdMap.merge(ord_map, A.OrdMap.new([{key, value}]))
    assert ^new_map = A.OrdMap.update(ord_map, key, nil, fn _ -> value end)
    assert {_, ^new_map} = A.OrdMap.get_and_update!(ord_map, key, fn _ -> {nil, value} end)
    assert ^new_map = ord(%{ord_map | key => value})

    assert A.OrdMap.size(new_map) == A.OrdMap.size(ord_map)

    new_map
  end

  def apply_operation(ord_map, :delete_existing) when ord_size(ord_map) == 0 do
    ord_map
  end

  def apply_operation(%A.OrdMap{} = ord_map, :delete_existing) do
    {key, value} = ord_map |> Enum.random()

    # all of those must be equivalent
    assert {^value, new_map} = A.OrdMap.pop!(ord_map, key)
    assert {^value, ^new_map} = A.OrdMap.pop(ord_map, key, nil)
    assert {^value, ^new_map} = pop_in(ord_map, [key])
    assert {^value, ^new_map} = A.OrdMap.get_and_update!(ord_map, key, fn _ -> :pop end)

    assert A.OrdMap.size(new_map) == A.OrdMap.size(ord_map) - 1
    new_map
  end

  def apply_operation(%A.OrdMap{} = ord_map, {:delete_random, key}) do
    # all of those must be equivalent
    assert {returned, new_map} = A.OrdMap.pop(ord_map, key, nil)
    assert ^new_map = A.OrdMap.delete(ord_map, key)
    assert {^returned, ^new_map} = pop_in(ord_map, [key])
    new_map = A.OrdMap.drop(ord_map, [key])

    new_map
  end

  def assert_properties(%A.OrdMap{} = ord_map) do
    as_list = Enum.to_list(ord_map)
    assert ^as_list = A.OrdMap.to_list(ord_map)

    assert A.OrdMap.size(ord_map) == length(as_list)

    assert A.OrdMap.first(ord_map) == List.first(as_list)
    assert A.OrdMap.last(ord_map) == List.last(as_list)
  end

  @tag :property
  property "any series of transformation should yield a valid ordered map" do
    check all(
            initial <- key_value_pairs(),
            operations <- list_of(operation())
          ) do
      initial_map = A.OrdMap.new(initial)

      ord_map =
        Enum.reduce(operations, initial_map, fn operation, acc ->
          apply_operation(acc, operation)
        end)

      assert_properties(ord_map)
    end
  end
end
