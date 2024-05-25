defmodule Aja.Vector.PropTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Aja, only: [vec: 1, vec_size: 1]
  import Aja.TestHelpers
  import Aja.TestDataGenerators

  @moduletag timeout: :infinity
  @moduletag :property

  # Property-based testing:

  # Those tests are a bit complex, but they should cover a lot of ground and help building confidence
  # that most operations work as they should without any weird edge case

  def hash_multiple_of_2(value) do
    :erlang.phash2(value, 2) === 0
  end

  def value do
    # prefer simple values which will should be more representative of actual uses, but keep exploring
    frequency([
      {20, integer()},
      {4, simple_value()},
      {1, term()}
    ])
  end

  def operation do
    one_of([
      {:append, value()},
      {:concat, list_of(value())},
      :delete_last
    ])
  end

  def apply_operation(%Aja.Vector{} = vector, {:append, value}) do
    new_vector = Aja.Vector.append(vector, value)

    assert ^new_vector = Aja.Vector.concat(vector, [value])

    assert value === Aja.Vector.last(new_vector)
    assert value in new_vector

    assert Aja.Vector.size(vector) + 1 === Aja.Vector.size(new_vector)

    new_vector
  end

  def apply_operation(%Aja.Vector{} = vector, {:concat, values}) do
    new_vector = Aja.Vector.concat(vector, values)

    assert ^new_vector = Enum.into(values, vector)

    assert Aja.Vector.size(vector) + length(values) === Aja.Vector.size(new_vector)

    new_vector
  end

  def apply_operation(vec([]) = vector, :delete_last) do
    ^vector = Aja.Vector.delete_last(vector)
    assert 0 = Aja.Vector.size(vector)

    vector
  end

  def apply_operation(%Aja.Vector{} = vector, :delete_last) do
    new_vector = Aja.Vector.delete_last(vector)
    last = Aja.Vector.last(vector)

    assert {^last, ^new_vector} = Aja.Vector.pop_last!(vector)
    assert {^last, ^new_vector} = Aja.Vector.pop_last(vector)

    assert Aja.Vector.size(vector) - 1 === Aja.Vector.size(new_vector)

    assert vec(_ ||| ^last) = vector

    new_vector
  end

  def assert_properties(vec([]) = vector) do
    assert 0 = Aja.Vector.size(vector)
    assert [] = Aja.Vector.to_list(vector)
    assert [] = Aja.Enum.to_list(vector)
    assert [] = Enum.to_list(vector)
    assert vec([]) = vector
  end

  def assert_properties(%Aja.Vector{} = vector) do
    as_list = Aja.Vector.to_list(vector)
    assert ^as_list = Enum.to_list(vector)
    assert ^as_list = Aja.Enum.to_list(vector)

    assert Aja.Vector.size(vector) === length(as_list)
    assert Enum.count(vector) === length(as_list)
    assert Aja.Enum.count(vector) === length(as_list)

    first = List.first(as_list)
    last = List.last(as_list)
    assert Aja.Vector.first(vector) === first
    assert Aja.Vector.last(vector) === last

    assert vec(^first ||| ^last) = vector

    assert vector === Aja.Vector.new(vector)
    assert vector === Aja.Vector.concat(vector, [])
  end

  property "any series of transformation should yield a valid vector" do
    check all(
            initial <- list_of(value()),
            operations <- list_of(operation())
          ) do
      initial_vector = Aja.Vector.new(initial)

      vector =
        Enum.reduce(operations, initial_vector, fn operation, acc ->
          apply_operation(acc, operation)
        end)

      assert_properties(vector)
    end
  end

  property "concatenation should work as expected" do
    check all(
            x <- list_of(value()),
            y <- list_of(value())
          ) do
      z = x ++ y

      vx = Aja.Vector.new(x)
      vy = Aja.Vector.new(y)
      vz = Aja.Vector.new(z)

      assert vz === Aja.Vector.concat(vx, y)
      assert vz === Aja.Vector.concat(vx, vy)
      assert vz === Aja.Enum.into(y, vx)
      assert vz === Aja.Enum.into(vy, vx)
      assert vz === Enum.into(y, vx)
      assert vz === Enum.into(vy, vx)
      assert vz === Aja.Enum.into(y, vx, & &1)
      assert vz === Aja.Enum.into(vy, vx, & &1)
      assert vz === Enum.into(y, vx, & &1)
      assert vz === Enum.into(vy, vx, & &1)

      assert Aja.Vector.size(vz) === Aja.Vector.size(vx) + Aja.Vector.size(vy)
    end
  end

  property "duplicate/2 should work as expected" do
    check all(
            x <- value(),
            n <- big_positive_integer()
          ) do
      list = List.duplicate(x, n)
      vector = Aja.Vector.duplicate(x, n)

      assert n === Aja.Vector.size(vector)

      assert list === Aja.Vector.to_list(vector)
      assert vector === Aja.Vector.new(list)
    end
  end

  property "Aja.Vector functions should return the same as mirrored Enum functions" do
    check all(list <- list_of(value()), i1 <- integer(), i2 <- integer()) do
      vector = Aja.Vector.new(list)

      assert_properties(vector)

      list_length = length(list)
      assert list_length === Aja.Vector.size(vector)
      assert list_length === Enum.count(vector)
      assert match?(v when vec_size(v) == list_length, vector)
      assert match?(v when vec_size(v) >= list_length, vector)
      refute match?(v when vec_size(v) < list_length, vector)

      assert capture_error_without_type(Enum.min(list)) ===
               capture_error_without_type(Aja.Enum.min(vector))

      assert capture_error_without_type(Enum.max(list)) ===
               capture_error_without_type(Aja.Enum.max(vector))

      assert capture_error_without_type(Enum.min(list)) ===
               capture_error_without_type(Aja.Enum.max(vector, &<=/2))

      assert capture_error_without_type(Enum.max(list)) ===
               capture_error_without_type(Aja.Enum.min(vector, &>=/2))

      assert capture_error_without_type(Enum.min_by(list, &:erlang.phash2/1)) ===
               capture_error_without_type(Aja.Enum.min_by(vector, &:erlang.phash2/1))

      assert capture_error_without_type(Enum.max_by(list, &:erlang.phash2/1)) ===
               capture_error_without_type(Aja.Enum.max_by(vector, &:erlang.phash2/1))

      assert capture_error_without_type(Enum.min_by(list, &:erlang.phash2/1)) ===
               capture_error_without_type(Aja.Enum.max_by(vector, &:erlang.phash2/1, &<=/2))

      assert capture_error_without_type(Enum.max_by(list, &:erlang.phash2/1)) ===
               capture_error_without_type(Aja.Enum.min_by(vector, &:erlang.phash2/1, &>=/2))

      assert Enum.at(list, i1) === Aja.Vector.at(vector, i1)
      assert Enum.at(list, i1, :default) === Aja.Vector.at(vector, i1, :default)
      assert Enum.at(list, i1) === vector[i1]
      assert Enum.fetch(list, i1) === Aja.Vector.fetch(vector, i1)
      assert Enum.fetch(list, i1) === Aja.Enum.fetch(vector, i1)

      assert capture_error_without_type(Enum.fetch!(list, i1)) ===
               capture_error_without_type(Aja.Enum.fetch!(vector, i1))

      assert capture_error_without_type(Enum.fetch!(list, i1)) ===
               capture_error_without_type(Aja.Vector.fetch!(vector, i1))

      # amount must be >=0
      amount = abs(i2)
      slice_1 = Enum.slice(list, i1, amount)
      assert slice_1 === Enum.slice(vector, i1, amount)
      assert Aja.Vector.new(slice_1) === Aja.Vector.slice(vector, i1, amount)

      slice_2 = Enum.slice(list, i1..i2//1)
      assert slice_2 === Enum.slice(vector, i1..i2//1)
      assert Aja.Vector.new(slice_2) === Aja.Vector.slice(vector, i1..i2//1)

      assert Enum.take(list, i1) |> Aja.Vector.new() === Aja.Vector.take(vector, i1)
      assert Enum.drop(list, i1) |> Aja.Vector.new() === Aja.Vector.drop(vector, i1)

      {l1, l2} = Enum.split(list, i1)
      assert {Aja.Vector.new(l1), Aja.Vector.new(l2)} === Aja.Vector.split(vector, i1)

      replaced_list = List.replace_at(list, i1, :replaced)
      assert Aja.Vector.new(replaced_list) == Aja.Vector.replace_at(vector, i1, :replaced)

      assert Aja.Vector.new(replaced_list) ==
               Aja.Vector.update_at(vector, i1, fn _ -> :replaced end)

      assert Aja.Vector.new(replaced_list) == put_in(vector[i1], :replaced)
      assert Aja.Vector.new(replaced_list) == update_in(vector[i1], fn _ -> :replaced end)

      deleted_list = List.delete_at(list, i1)
      assert Aja.Vector.new(deleted_list) == Aja.Vector.delete_at(vector, i1)
      assert {vector[i1], Aja.Vector.new(deleted_list)} == Aja.Vector.pop_at(vector, i1)
      assert {vector[i1], Aja.Vector.new(deleted_list)} == pop_in(vector[i1])

      assert list === Aja.Vector.to_list(vector)
      assert Enum.reverse(list) |> Aja.Vector.new() === Aja.Vector.reverse(vector)

      assert Enum.reverse(list, ~c"abc") |> Aja.Vector.new() ===
               Aja.Vector.reverse(vector, ~c"abc")

      assert list === Aja.Vector.foldr(vector, [], &[&1 | &2])
      assert Enum.reverse(list) === Aja.Vector.foldl(vector, [], &[&1 | &2])

      assert capture_error_without_type(Enum.reduce(list, &[&1 | &2])) ===
               capture_error_without_type(Aja.Enum.reduce(vector, &[&1 | &2]))

      assert Enum.scan(list, &[&1 | &2]) |> Aja.Vector.new() ===
               Aja.Vector.scan(vector, &[&1 | &2])

      assert Enum.scan(list, [], &[&1 | &2]) |> Aja.Vector.new() ===
               Aja.Vector.scan(vector, [], &[&1 | &2])

      inspected_list = Enum.map(list, &inspect/1)
      assert Aja.Vector.new(inspected_list) === Aja.Vector.map(vector, &inspect/1)
      assert Aja.Vector.new(inspected_list) === Aja.Vector.new(list, &inspect/1)
      assert Aja.Vector.new(inspected_list) === Aja.Vector.new(vector, &inspect/1)

      filtered_list = Enum.filter(list, &hash_multiple_of_2/1)
      filtered_vector = Aja.Vector.filter(vector, &hash_multiple_of_2/1)
      assert Aja.Vector.new(filtered_list) === filtered_vector

      index_list = Enum.with_index(list, i1)
      index_vector = Aja.Vector.new(index_list)
      assert index_vector === Aja.Vector.with_index(vector, i1)
      assert index_vector === Aja.Vector.with_index(vector, fn x, i -> {x, i + i1} end)

      assert {index_vector, list_length + i1} ===
               Aja.Vector.map_reduce(vector, i1, fn x, i -> {{x, i}, i + 1} end)

      assert index_vector === Aja.Vector.zip(vector, Aja.Vector.new(i1..(list_length + i1)))

      assert index_vector ===
               Aja.Vector.zip_with(vector, Aja.Vector.new(0..list_length), &{&1, &2 + i1})

      assert {vector, i1..(list_length + i1) |> Enum.drop(-1) |> Aja.Vector.new()} ==
               Aja.Vector.unzip(index_vector)

      assert Enum.any?(list) === Aja.Enum.any?(vector)
      assert Enum.all?(list) === Aja.Enum.all?(vector)

      assert Enum.any?(list, &hash_multiple_of_2/1) ===
               Aja.Enum.any?(vector, &hash_multiple_of_2/1)

      assert Enum.all?(list, &hash_multiple_of_2/1) ===
               Aja.Enum.all?(vector, &hash_multiple_of_2/1)

      assert true === Aja.Enum.all?(Aja.Vector.new(filtered_list), &hash_multiple_of_2/1)

      assert false ===
               Aja.Enum.any?(Aja.Vector.new(filtered_list), fn x -> !hash_multiple_of_2(x) end)

      assert Enum.find(list, &hash_multiple_of_2/1) ===
               Aja.Enum.find(vector, &hash_multiple_of_2/1)

      assert Enum.find_value(list, &hash_multiple_of_2/1) ===
               Aja.Enum.find_value(vector, &hash_multiple_of_2/1)

      assert Enum.find_index(list, &hash_multiple_of_2/1) ===
               Aja.Enum.find_index(vector, &hash_multiple_of_2/1)

      assert Enum.take_while(list, &hash_multiple_of_2/1) |> Aja.Vector.new() ===
               Aja.Vector.take_while(vector, &hash_multiple_of_2/1)

      assert Enum.drop_while(list, &hash_multiple_of_2/1) |> Aja.Vector.new() ===
               Aja.Vector.drop_while(vector, &hash_multiple_of_2/1)

      {taken, dropped} = Enum.split_while(list, &hash_multiple_of_2/1)

      assert {Aja.Vector.new(taken), Aja.Vector.new(dropped)} ===
               Aja.Vector.split_while(vector, &hash_multiple_of_2/1)

      assert capture_error_without_type(Enum.sum(list)) ===
               capture_error_without_type(Aja.Enum.sum(vector))

      assert capture_error_without_type(Enum.reduce(list, 1, &(&2 * &1))) ===
               capture_error_without_type(Aja.Enum.product(vector))

      assert capture_error_without_type(Enum.join(list, ",")) ===
               capture_error_without_type(Aja.Enum.join(vector, ","))

      assert Enum.map_join(list, ",", &inspect/1) === Aja.Enum.map_join(vector, ",", &inspect/1)

      assert Enum.intersperse(list, nil) === Aja.Enum.intersperse(vector, nil)

      assert Enum.intersperse(list, nil) |> Aja.Vector.new() ===
               Aja.Vector.intersperse(vector, nil)

      assert Enum.map_intersperse(list, nil, &inspect/1) |> Aja.Vector.new() ===
               Aja.Vector.map_intersperse(vector, nil, &inspect/1)

      assert Enum.map_intersperse(list, nil, &inspect/1) ===
               Aja.Enum.map_intersperse(vector, nil, &inspect/1)

      assert Enum.flat_map(list, &[&1, &1]) |> Aja.Vector.new() ===
               Aja.Vector.flat_map(vector, &[&1, &1])

      assert Enum.frequencies(list) === Aja.Enum.frequencies(vector)

      assert Enum.frequencies_by(list, &hash_multiple_of_2/1) ===
               Aja.Enum.frequencies_by(vector, &hash_multiple_of_2/1)

      assert Enum.group_by(list, &hash_multiple_of_2/1) ===
               Aja.Enum.group_by(vector, &hash_multiple_of_2/1)

      assert Enum.group_by(list, &hash_multiple_of_2/1, &inspect/1) ===
               Aja.Enum.group_by(vector, &hash_multiple_of_2/1, &inspect/1)

      assert Enum.uniq(list) === Aja.Enum.uniq(vector)
      assert Enum.dedup(list) === Aja.Enum.dedup(vector)
      assert Enum.uniq(list) |> Aja.Vector.new() === Aja.Vector.uniq(vector)
      assert Enum.dedup(list) |> Aja.Vector.new() === Aja.Vector.dedup(vector)

      assert Enum.uniq_by(list, &hash_multiple_of_2/1) ===
               Aja.Enum.uniq_by(vector, &hash_multiple_of_2/1)

      assert Enum.dedup_by(list, &hash_multiple_of_2/1) ===
               Aja.Enum.dedup_by(vector, &hash_multiple_of_2/1)

      assert Enum.uniq_by(list, &hash_multiple_of_2/1) |> Aja.Vector.new() ===
               Aja.Vector.uniq_by(vector, &hash_multiple_of_2/1)

      assert Enum.dedup_by(list, &hash_multiple_of_2/1) |> Aja.Vector.new() ===
               Aja.Vector.dedup_by(vector, &hash_multiple_of_2/1)

      shuffled = Aja.Vector.shuffle(vector)
      assert ^list_length = Aja.Vector.size(shuffled)

      assert min(list_length, amount) ==
               Aja.Vector.take_random(vector, amount) |> Aja.Vector.size()

      assert Aja.Vector.new() == Aja.Vector.take_random(vector, 0)

      if list_length != 0 do
        rand = Aja.Enum.random(vector)
        assert rand in vector
        assert rand in shuffled

        assert vec([rand]) = Aja.Vector.take_random(vector, 1)
        assert rand in vector
        assert rand in shuffled
      end

      assert inspect(vector) =~ "vec(["
    end
  end

  property "Aja.Enum.sum/1 should return the same as Enum.sum/1 for numbers" do
    check all(list <- list_of(one_of([integer(), float()]))) do
      vector = Aja.Vector.new(list)

      assert Enum.sum(list) === Aja.Enum.sum(vector)
    end
  end

  property "Aja.Vector any?/all?/find always return the same as Enum equivalents" do
    # use 33 as an arbitrary truthy value
    check all(
            value <- one_of([true, false, nil, constant(33)]),
            i1 <- big_positive_integer(),
            i2 <- big_positive_integer()
          ) do
      count = i1 + i2

      vector = Aja.Vector.duplicate(value, count)
      id = fn x -> x end

      negate = fn
        true -> false
        false -> true
        nil -> 33
        33 -> nil
      end

      replaced_vector = Aja.Vector.update_at(vector, i1, negate)

      assert !!value === Aja.Enum.any?(vector)
      assert !!value === Aja.Enum.any?(vector, id)
      assert !value === Aja.Enum.any?(vector, negate)
      assert !!value === Aja.Enum.all?(vector)
      assert !!value === Aja.Enum.all?(vector, id)
      assert !value === Aja.Enum.all?(vector, negate)

      assert true === Aja.Enum.any?(replaced_vector)
      assert true === Aja.Enum.any?(replaced_vector, id)
      assert true === Aja.Enum.any?(replaced_vector, negate)
      assert false === Aja.Enum.all?(replaced_vector)
      assert false === Aja.Enum.all?(replaced_vector, id)
      assert false === Aja.Enum.all?(replaced_vector, negate)
    end
  end
end
