defmodule A.OrdMap.PropTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import A
  import A.TestDataGenerators

  @moduletag timeout: :infinity
  @moduletag :property

  # Property-based testing:

  # Those tests are a bit complex, but they should cover a lot of ground and help building confidence
  # that most operations work as they should without any weird edge case

  def key do
    simple_value()
  end

  def value do
    # values probably don't impact the algoithm that much
    # no need to intensively check for arbitrary/huge nested values
    frequency([
      {4, key()},
      {1, term() |> log_rescale()}
    ])
  end

  def key_value_pairs() do
    list_of(tuple({key(), value()}))
  end

  def operation do
    one_of([
      {:put, key(), value()},
      {:replace_existing, value()},
      {:delete_random, key()},
      {:drop_random, key() |> list_of()},
      {:take_random, key() |> list_of()},
      :delete_existing
    ])
  end

  def apply_operation(%A.OrdMap{} = ord_map, {:put, key, value}) do
    new_map = A.OrdMap.put(ord_map, key, value)

    assert value == new_map[key]
    assert value == A.OrdMap.fetch!(new_map, key)
    assert A.OrdMap.has_key?(new_map, key)
    assert {key, value} in new_map

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
    assert ^new_map = A.Enum.into([{key, value}], ord_map)
    assert ^new_map = A.OrdMap.merge(ord_map, A.OrdMap.new([{key, value}]))
    assert ^new_map = A.OrdMap.update(ord_map, key, nil, fn _ -> value end)
    assert ^new_map = A.OrdMap.update!(ord_map, key, fn _ -> value end)
    assert {_, ^new_map} = A.OrdMap.get_and_update!(ord_map, key, fn _ -> {nil, value} end)
    assert ^new_map = ord(%{ord_map | key => value})

    assert ^ord_map = A.OrdMap.put_new(ord_map, key, make_ref())
    assert ^ord_map = A.OrdMap.put_new_lazy(ord_map, key, &make_ref/0)

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

    assert ^new_map = A.OrdMap.drop(ord_map, [key])

    assert A.OrdMap.has_key?(ord_map, key)
    refute A.OrdMap.has_key?(new_map, key)
    assert nil === new_map[key]
    refute {key, value} in new_map

    assert A.OrdMap.size(new_map) == A.OrdMap.size(ord_map) - 1
    new_map
  end

  def apply_operation(%A.OrdMap{} = ord_map, {:delete_random, key}) do
    # all of those must be equivalent
    assert {returned, new_map} = A.OrdMap.pop(ord_map, key, nil)
    assert ^new_map = A.OrdMap.delete(ord_map, key)
    assert {^returned, ^new_map} = pop_in(ord_map, [key])
    assert ^new_map = A.OrdMap.drop(ord_map, [key])

    new_map
  end

  def apply_operation(%A.OrdMap{} = ord_map, {:drop_random, keys}) do
    new_map = A.OrdMap.drop(ord_map, keys)
    assert ^new_map = A.OrdMap.drop(new_map, keys)

    assert Map.new(new_map) == ord_map |> Map.new() |> Map.drop(keys)

    successive = Enum.reduce(keys, ord_map, fn key, acc -> A.OrdMap.delete(acc, key) end)
    assert A.OrdMap.equal?(successive, new_map)
    assert A.OrdMap.to_list(successive) === A.OrdMap.to_list(new_map)

    assert A.OrdMap.new() == A.OrdMap.take(new_map, keys)

    assert A.OrdMap.size(new_map) ==
             A.OrdMap.size(ord_map) - (A.OrdMap.take(ord_map, keys) |> A.OrdMap.size())

    new_map
  end

  def apply_operation(%A.OrdMap{} = ord_map, {:take_random, keys}) do
    new_map = A.OrdMap.take(ord_map, keys)
    assert ^new_map = A.OrdMap.take(new_map, keys)

    assert Map.new(new_map) == ord_map |> Map.new() |> Map.take(keys)

    successive =
      Enum.reduce(keys, A.OrdMap.new(), fn key, acc ->
        case ord_map do
          ord(%{^key => value}) -> A.OrdMap.put(acc, key, value)
          _ -> acc
        end
      end)

    assert successive == new_map

    assert A.OrdMap.new() == A.OrdMap.drop(new_map, keys)

    new_map
  end

  def assert_properties(%A.OrdMap{} = ord_map) do
    as_list = Enum.to_list(ord_map)
    assert ^as_list = A.OrdMap.to_list(ord_map)
    assert ^as_list = A.OrdMap.foldr(ord_map, [], &[&1 | &2])
    assert ^as_list = A.OrdMap.foldl(ord_map, [], &[&1 | &2]) |> Enum.reverse()

    as_vector = A.Vector.new(as_list)
    assert ^as_vector = A.Vector.new(ord_map)
    assert ^as_vector = A.Vector.new(ord_map, fn {k, v} -> {k, v} end)

    length_list = length(as_list)
    assert A.OrdMap.size(ord_map) == length_list
    assert Enum.count(ord_map) == length_list
    assert A.Enum.count(ord_map) == length_list
    assert ord_size(ord_map) == length_list
    assert match?(o when ord_size(o) == length_list, ord_map)

    for kv <- as_list do
      assert {key, value} = kv
      assert kv in ord_map
      assert value == ord_map[key]
      assert A.OrdMap.has_key?(ord_map, key)
      assert value == A.OrdMap.fetch!(ord_map, key)
      assert {:ok, ^value} = A.OrdMap.fetch(ord_map, key)
      assert ord(%{^key => ^value}) = ord_map
    end

    assert Enum.map(as_list, fn {k, _v} -> k end) === A.OrdMap.keys(ord_map)
    assert Enum.map(as_list, fn {_k, v} -> v end) === A.OrdMap.values(ord_map)

    refute A.OrdMap.has_key?(ord_map, make_ref())

    assert A.OrdMap.first(ord_map) == List.first(as_list)
    assert A.OrdMap.last(ord_map) == List.last(as_list)

    dense = A.OrdMap.new(as_list)
    assert ^dense = A.OrdMap.new(as_list, fn {k, v} -> {k, v} end)
    assert ^dense = A.OrdMap.new(ord_map)
    assert ^dense = A.OrdMap.new(ord_map, fn {k, v} -> {k, v} end)
    assert ^dense = A.OrdMap.new(as_vector)
    assert ^dense = A.OrdMap.new(as_vector, fn {k, v} -> {k, v} end)
    assert ^dense = Enum.into(as_list, A.OrdMap.new())
    assert ^dense = A.Enum.into(as_vector, A.OrdMap.new())
    assert A.OrdMap.size(dense) == A.OrdMap.size(ord_map)
    assert A.OrdMap.equal?(dense, ord_map)

    require A.Vector.Raw
    assert 2 * map_size(ord_map.__ord_map__) >= A.Vector.Raw.size(ord_map.__ord_vector__)

    if A.OrdMap.sparse?(ord_map) do
      assert inspect(ord_map) =~ "#A.OrdMap<%{"
      assert inspect(ord_map) =~ ", sparse?: true>"
    else
      assert inspect(ord_map) =~ "ord(%{"
    end
  end

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
