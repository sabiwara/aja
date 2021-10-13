defmodule Aja.OrdMap.PropTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Aja
  import Aja.TestDataGenerators

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

  def apply_operation(%Aja.OrdMap{} = ord_map, {:put, key, value}) do
    new_map = Aja.OrdMap.put(ord_map, key, value)

    assert value == new_map[key]
    assert value == Aja.OrdMap.fetch!(new_map, key)
    assert Aja.OrdMap.has_key?(new_map, key)
    assert {key, value} in new_map

    new_map
  end

  def apply_operation(ord_map, {:replace_existing, _value}) when ord_size(ord_map) == 0 do
    ord_map
  end

  def apply_operation(%Aja.OrdMap{} = ord_map, {:replace_existing, value}) do
    key = ord_map |> Aja.OrdMap.keys() |> Enum.random()

    # all of those are equivalent
    new_map = Aja.OrdMap.replace!(ord_map, key, value)
    assert ^new_map = Aja.OrdMap.replace(ord_map, key, value)
    assert ^new_map = Aja.OrdMap.put(ord_map, key, value)
    assert ^new_map = put_in(ord_map, [key], value)
    assert ^new_map = Enum.into([{key, value}], ord_map)
    assert ^new_map = Aja.Enum.into([{key, value}], ord_map)
    assert ^new_map = Aja.OrdMap.merge(ord_map, Aja.OrdMap.new([{key, value}]))
    assert ^new_map = Aja.OrdMap.update(ord_map, key, nil, fn _ -> value end)
    assert ^new_map = Aja.OrdMap.update!(ord_map, key, fn _ -> value end)
    assert {_, ^new_map} = Aja.OrdMap.get_and_update!(ord_map, key, fn _ -> {nil, value} end)
    assert ^new_map = ord(%{ord_map | key => value})

    assert ^ord_map = Aja.OrdMap.put_new(ord_map, key, make_ref())
    assert ^ord_map = Aja.OrdMap.put_new_lazy(ord_map, key, &make_ref/0)

    assert Aja.OrdMap.size(new_map) == Aja.OrdMap.size(ord_map)

    new_map
  end

  def apply_operation(ord_map, :delete_existing) when ord_size(ord_map) == 0 do
    ord_map
  end

  def apply_operation(%Aja.OrdMap{} = ord_map, :delete_existing) do
    {key, value} = ord_map |> Enum.random()

    # all of those must be equivalent
    assert {^value, new_map} = Aja.OrdMap.pop!(ord_map, key)
    assert {^value, ^new_map} = Aja.OrdMap.pop(ord_map, key, nil)
    assert {^value, ^new_map} = pop_in(ord_map, [key])
    assert {^value, ^new_map} = Aja.OrdMap.get_and_update!(ord_map, key, fn _ -> :pop end)

    assert ^new_map = Aja.OrdMap.drop(ord_map, [key])

    assert Aja.OrdMap.has_key?(ord_map, key)
    refute Aja.OrdMap.has_key?(new_map, key)
    assert nil === new_map[key]
    refute {key, value} in new_map

    assert Aja.OrdMap.size(new_map) == Aja.OrdMap.size(ord_map) - 1
    new_map
  end

  def apply_operation(%Aja.OrdMap{} = ord_map, {:delete_random, key}) do
    # all of those must be equivalent
    assert {returned, new_map} = Aja.OrdMap.pop(ord_map, key, nil)
    assert ^new_map = Aja.OrdMap.delete(ord_map, key)
    assert {^returned, ^new_map} = pop_in(ord_map, [key])
    assert ^new_map = Aja.OrdMap.drop(ord_map, [key])

    new_map
  end

  def apply_operation(%Aja.OrdMap{} = ord_map, {:drop_random, keys}) do
    new_map = Aja.OrdMap.drop(ord_map, keys)
    assert ^new_map = Aja.OrdMap.drop(new_map, keys)

    assert Map.new(new_map) == ord_map |> Map.new() |> Map.drop(keys)

    successive = Enum.reduce(keys, ord_map, fn key, acc -> Aja.OrdMap.delete(acc, key) end)
    assert Aja.OrdMap.equal?(successive, new_map)
    assert Aja.OrdMap.to_list(successive) === Aja.OrdMap.to_list(new_map)

    assert Aja.OrdMap.new() == Aja.OrdMap.take(new_map, keys)

    assert Aja.OrdMap.size(new_map) ==
             Aja.OrdMap.size(ord_map) - (Aja.OrdMap.take(ord_map, keys) |> Aja.OrdMap.size())

    new_map
  end

  def apply_operation(%Aja.OrdMap{} = ord_map, {:take_random, keys}) do
    new_map = Aja.OrdMap.take(ord_map, keys)
    assert ^new_map = Aja.OrdMap.take(new_map, keys)

    assert Map.new(new_map) == ord_map |> Map.new() |> Map.take(keys)

    successive =
      Enum.reduce(keys, Aja.OrdMap.new(), fn key, acc ->
        case ord_map do
          ord(%{^key => value}) -> Aja.OrdMap.put(acc, key, value)
          _ -> acc
        end
      end)

    assert successive == new_map

    assert Aja.OrdMap.new() == Aja.OrdMap.drop(new_map, keys)

    new_map
  end

  def assert_properties(%Aja.OrdMap{} = ord_map) do
    as_list = Enum.to_list(ord_map)
    assert ^as_list = Aja.OrdMap.to_list(ord_map)
    assert ^as_list = Aja.OrdMap.foldr(ord_map, [], &[&1 | &2])
    assert ^as_list = Aja.OrdMap.foldl(ord_map, [], &[&1 | &2]) |> Enum.reverse()

    as_vector = Aja.Vector.new(as_list)
    assert ^as_vector = Aja.Vector.new(ord_map)
    assert ^as_vector = Aja.Vector.new(ord_map, fn {k, v} -> {k, v} end)

    length_list = length(as_list)
    assert Aja.OrdMap.size(ord_map) == length_list
    assert Enum.count(ord_map) == length_list
    assert Aja.Enum.count(ord_map) == length_list
    assert ord_size(ord_map) == length_list
    assert match?(o when ord_size(o) == length_list, ord_map)

    for kv <- as_list do
      assert {key, value} = kv
      assert kv in ord_map
      assert value == ord_map[key]
      assert Aja.OrdMap.has_key?(ord_map, key)
      assert value == Aja.OrdMap.fetch!(ord_map, key)
      assert {:ok, ^value} = Aja.OrdMap.fetch(ord_map, key)
      assert ord(%{^key => ^value}) = ord_map
    end

    assert Enum.map(as_list, fn {k, _v} -> k end) === Aja.OrdMap.keys(ord_map)
    assert Enum.map(as_list, fn {_k, v} -> v end) === Aja.OrdMap.values(ord_map)

    refute Aja.OrdMap.has_key?(ord_map, make_ref())

    assert Aja.OrdMap.first(ord_map) == List.first(as_list)
    assert Aja.OrdMap.last(ord_map) == List.last(as_list)

    dense = Aja.OrdMap.new(as_list)
    assert ^dense = Aja.OrdMap.new(as_list, fn {k, v} -> {k, v} end)
    assert ^dense = Aja.OrdMap.new(ord_map)
    assert ^dense = Aja.OrdMap.new(ord_map, fn {k, v} -> {k, v} end)
    assert ^dense = Aja.OrdMap.new(as_vector)
    assert ^dense = Aja.OrdMap.new(as_vector, fn {k, v} -> {k, v} end)
    assert ^dense = Enum.into(as_list, Aja.OrdMap.new())
    assert ^dense = Aja.Enum.into(as_vector, Aja.OrdMap.new())
    assert Aja.OrdMap.size(dense) == Aja.OrdMap.size(ord_map)
    assert Aja.OrdMap.equal?(dense, ord_map)

    require Aja.Vector.Raw
    assert 2 * map_size(ord_map.__ord_map__) >= Aja.Vector.Raw.size(ord_map.__ord_vector__)

    if Aja.OrdMap.sparse?(ord_map) do
      assert inspect(ord_map) =~ "#Aja.OrdMap<%{"
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
      initial_map = Aja.OrdMap.new(initial)

      ord_map =
        Enum.reduce(operations, initial_map, fn operation, acc ->
          apply_operation(acc, operation)
        end)

      assert_properties(ord_map)
    end
  end
end
