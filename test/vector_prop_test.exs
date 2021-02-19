defmodule A.Vector.PropTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import A, only: [vec: 1, vec_size: 1]

  # Property-based testing:

  # Those tests are a bit complex, but they should cover a lot of ground and help building confidence
  # that most operations work as they should without any weird edge case

  defmacrop capture_error(expr) do
    # Check if we fail in the same case than the equivalent Enum
    quote do
      try do
        {:ok, unquote(expr)}
      rescue
        error ->
          :error
      end
    end
  end

  def hash_multiple_of_2(value) do
    :erlang.phash2(value, 2) === 0
  end

  def simple_value, do: one_of([float(), string(:printable), atom(:alphanumeric)])
  def big_positive_integer, do: positive_integer() |> resize(20_000)

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

  def apply_operation(%A.Vector{} = vector, {:append, value}) do
    new_vector = A.Vector.append(vector, value)

    assert ^new_vector = A.Vector.concat(vector, [value])

    assert value === A.Vector.last(new_vector)
    assert value in new_vector

    assert A.Vector.size(vector) + 1 === A.Vector.size(new_vector)

    new_vector
  end

  def apply_operation(%A.Vector{} = vector, {:concat, values}) do
    new_vector = A.Vector.concat(vector, values)

    assert ^new_vector = Enum.into(values, vector)

    assert A.Vector.size(vector) + length(values) === A.Vector.size(new_vector)

    new_vector
  end

  def apply_operation(vec([]) = vector, :delete_last) do
    ^vector = A.Vector.delete_last(vector)
    assert 0 = A.Vector.size(vector)

    vector
  end

  def apply_operation(%A.Vector{} = vector, :delete_last) do
    new_vector = A.Vector.delete_last(vector)
    last = A.Vector.last(vector)

    assert {^last, ^new_vector} = A.Vector.pop_last!(vector)
    assert {^last, ^new_vector} = A.Vector.pop_last(vector)

    assert A.Vector.size(vector) - 1 === A.Vector.size(new_vector)

    new_vector
  end

  def assert_properties(vec([]) = vector) do
    assert 0 = A.Vector.size(vector)
    assert [] = A.Vector.to_list(vector)
    assert [] = Enum.to_list(vector)
  end

  def assert_properties(%A.Vector{} = vector) do
    as_list = A.Vector.to_list(vector)

    assert ^as_list = Enum.to_list(vector)
    assert A.Vector.size(vector) === length(as_list)
    assert Enum.count(vector) === length(as_list)

    assert A.Vector.first(vector) === List.first(as_list)
    assert A.Vector.last(vector) === List.last(as_list)

    assert vector === A.Vector.new(vector)
    assert vector === A.Vector.concat(vector, [])
  end

  @tag :property
  property "any series of transformation should yield a valid vector" do
    check all(
            initial <- list_of(value()),
            operations <- list_of(operation())
          ) do
      initial_vector = A.Vector.new(initial)

      vector =
        Enum.reduce(operations, initial_vector, fn operation, acc ->
          apply_operation(acc, operation)
        end)

      assert_properties(vector)
    end
  end

  @tag :property
  property "concatenation should work as expected" do
    check all(
            x <- list_of(value()),
            y <- list_of(value())
          ) do
      z = x ++ y

      vx = A.Vector.new(x)
      vy = A.Vector.new(y)
      vz = A.Vector.new(z)

      assert vz === A.Vector.concat(vx, y)
      assert vz === A.Vector.concat(vx, vy)
      assert vz === Enum.into(y, vx)
      assert vz === Enum.into(vy, vx)

      assert A.Vector.size(vz) === A.Vector.size(vx) + A.Vector.size(vy)
    end
  end

  @tag :property
  property "duplicate/2 should work as expected" do
    check all(
            x <- value(),
            n <- big_positive_integer()
          ) do
      list = List.duplicate(x, n)
      vector = A.Vector.duplicate(x, n)

      assert n === A.Vector.size(vector)

      assert list === A.Vector.to_list(vector)
      assert vector === A.Vector.new(list)
    end
  end

  @tag :property
  property "A.Vector functions should return the same as mirrored Enum functions" do
    check all(list <- list_of(value()), i1 <- integer(), i2 <- integer()) do
      vector = A.Vector.new(list)

      assert_properties(vector)

      list_length = length(list)
      assert list_length === A.Vector.size(vector)
      assert list_length === Enum.count(vector)
      assert match?(v when vec_size(v) == list_length, vector)
      assert match?(v when vec_size(v) >= list_length, vector)
      refute match?(v when vec_size(v) < list_length, vector)

      assert capture_error(Enum.min(list)) === capture_error(A.Vector.min(vector))
      assert capture_error(Enum.max(list)) === capture_error(A.Vector.max(vector))

      assert capture_error(Enum.min(list)) === capture_error(A.Vector.max(vector, &<=/2))
      assert capture_error(Enum.max(list)) === capture_error(A.Vector.min(vector, &>=/2))

      assert capture_error(Enum.min_by(list, &:erlang.phash2/1)) ===
               capture_error(A.Vector.min_by(vector, &:erlang.phash2/1))

      assert capture_error(Enum.max_by(list, &:erlang.phash2/1)) ===
               capture_error(A.Vector.max_by(vector, &:erlang.phash2/1))

      assert capture_error(Enum.min_by(list, &:erlang.phash2/1)) ===
               capture_error(A.Vector.max_by(vector, &:erlang.phash2/1, &<=/2))

      assert capture_error(Enum.max_by(list, &:erlang.phash2/1)) ===
               capture_error(A.Vector.min_by(vector, &:erlang.phash2/1, &>=/2))

      assert Enum.at(list, i1) === A.Vector.at(vector, i1)
      assert Enum.at(list, i1) === vector[i1]

      # amount must be >=0
      amount = abs(i2)
      slice_1 = Enum.slice(list, i1, amount)
      assert slice_1 === Enum.slice(vector, i1, amount)
      assert A.Vector.new(slice_1) === A.Vector.slice(vector, i1, amount)

      slice_2 = Enum.slice(list, i1..i2)
      assert slice_2 === Enum.slice(vector, i1..i2)
      assert A.Vector.new(slice_2) === A.Vector.slice(vector, i1..i2)

      assert Enum.take(list, i1) |> A.Vector.new() === A.Vector.take(vector, i1)
      assert Enum.drop(list, i1) |> A.Vector.new() === A.Vector.drop(vector, i1)

      {l1, l2} = Enum.split(list, i1)
      assert {A.Vector.new(l1), A.Vector.new(l2)} === A.Vector.split(vector, i1)

      replaced_list = List.replace_at(list, i1, :replaced)
      assert A.Vector.new(replaced_list) == A.Vector.replace_at(vector, i1, :replaced)
      assert A.Vector.new(replaced_list) == A.Vector.update_at(vector, i1, fn _ -> :replaced end)
      assert A.Vector.new(replaced_list) == put_in(vector[i1], :replaced)
      assert A.Vector.new(replaced_list) == update_in(vector[i1], fn _ -> :replaced end)

      deleted_list = List.delete_at(list, i1)
      assert A.Vector.new(deleted_list) == A.Vector.delete_at(vector, i1)
      assert {vector[i1], A.Vector.new(deleted_list)} == A.Vector.pop_at(vector, i1)
      assert {vector[i1], A.Vector.new(deleted_list)} == pop_in(vector[i1])

      assert list === A.Vector.to_list(vector)
      assert Enum.reverse(list) === A.Vector.reverse(vector) |> A.Vector.to_list()
      assert list === A.Vector.foldr(vector, [], &[&1 | &2])
      assert Enum.reverse(list) === A.Vector.foldl(vector, [], &[&1 | &2])

      inspected_list = Enum.map(list, &inspect/1)
      assert A.Vector.new(inspected_list) === A.Vector.map(vector, &inspect/1)
      assert A.Vector.new(inspected_list) === A.Vector.new(list, &inspect/1)
      assert A.Vector.new(inspected_list) === A.Vector.new(vector, &inspect/1)

      filtered_list = Enum.filter(list, &hash_multiple_of_2/1)
      filtered_vector = A.Vector.filter(vector, &hash_multiple_of_2/1)
      assert A.Vector.new(filtered_list) === filtered_vector

      index_list = Enum.with_index(list, i1)
      assert A.Vector.new(index_list) === A.Vector.with_index(vector, i1)

      assert A.Vector.new(index_list) ===
               A.Vector.zip(vector, A.Vector.new(i1..(list_length + i1)))

      assert {vector, A.Vector.new(A.ExRange.new(i1, list_length + i1))} ==
               A.Vector.new(index_list) |> A.Vector.unzip()

      assert Enum.any?(list) === A.Vector.any?(vector)
      assert Enum.all?(list) === A.Vector.all?(vector)

      assert Enum.any?(list, &hash_multiple_of_2/1) ===
               A.Vector.any?(vector, &hash_multiple_of_2/1)

      assert Enum.all?(list, &hash_multiple_of_2/1) ===
               A.Vector.all?(vector, &hash_multiple_of_2/1)

      assert true === A.Vector.all?(A.Vector.new(filtered_list), &hash_multiple_of_2/1)

      assert false ===
               A.Vector.any?(A.Vector.new(filtered_list), fn x -> !hash_multiple_of_2(x) end)

      assert Enum.find(list, &hash_multiple_of_2/1) ===
               A.Vector.find(vector, &hash_multiple_of_2/1)

      assert Enum.find_value(list, &hash_multiple_of_2/1) ===
               A.Vector.find_value(vector, &hash_multiple_of_2/1)

      assert Enum.find_index(list, &hash_multiple_of_2/1) ===
               A.Vector.find_index(vector, &hash_multiple_of_2/1)

      assert Enum.take_while(list, &hash_multiple_of_2/1) |> A.Vector.new() ===
               A.Vector.take_while(vector, &hash_multiple_of_2/1)

      assert Enum.drop_while(list, &hash_multiple_of_2/1) |> A.Vector.new() ===
               A.Vector.drop_while(vector, &hash_multiple_of_2/1)

      {taken, dropped} = Enum.split_while(list, &hash_multiple_of_2/1)

      assert {A.Vector.new(taken), A.Vector.new(dropped)} ===
               A.Vector.split_while(vector, &hash_multiple_of_2/1)

      assert capture_error(Enum.sum(list)) === capture_error(A.Vector.sum(vector))

      assert capture_error(Enum.reduce(list, 1, &(&2 * &1))) ===
               capture_error(A.Vector.product(vector))

      assert capture_error(Enum.join(list, ",")) === capture_error(A.Vector.join(vector, ","))
      assert Enum.map_join(list, ",", &inspect/1) === A.Vector.map_join(vector, ",", &inspect/1)

      assert Enum.intersperse(list, nil) |> A.Vector.new() === A.Vector.intersperse(vector, nil)

      assert Enum.map_intersperse(list, nil, &inspect/1) |> A.Vector.new() ===
               A.Vector.map_intersperse(vector, nil, &inspect/1)

      assert Enum.frequencies(list) === A.Vector.frequencies(vector)

      assert Enum.frequencies_by(list, &hash_multiple_of_2/1) ===
               A.Vector.frequencies_by(vector, &hash_multiple_of_2/1)

      assert Enum.group_by(list, &hash_multiple_of_2/1) ===
               A.Vector.group_by(vector, &hash_multiple_of_2/1)

      assert Enum.group_by(list, &hash_multiple_of_2/1, &inspect/1) ===
               A.Vector.group_by(vector, &hash_multiple_of_2/1, &inspect/1)

      assert Enum.uniq(list) |> A.Vector.new() === A.Vector.uniq(vector)
      assert Enum.dedup(list) |> A.Vector.new() === A.Vector.dedup(vector)

      assert Enum.uniq_by(list, &hash_multiple_of_2/1) |> A.Vector.new() ===
               A.Vector.uniq_by(vector, &hash_multiple_of_2/1)

      assert Enum.dedup_by(list, &hash_multiple_of_2/1) |> A.Vector.new() ===
               A.Vector.dedup_by(vector, &hash_multiple_of_2/1)

      shuffled = A.Vector.shuffle(vector)
      assert ^list_length = A.Vector.size(shuffled)

      assert min(list_length, amount) == A.Vector.take_random(vector, amount) |> A.Vector.size()

      assert A.Vector.new() == A.Vector.take_random(vector, 0)

      if list_length != 0 do
        rand = A.Vector.random(vector)
        assert rand in vector
        assert rand in shuffled

        assert vec([rand]) = A.Vector.take_random(vector, 1)
        assert rand in vector
        assert rand in shuffled
      end
    end
  end

  @tag :property
  property "A.Vector.sum/1 should return the same as Enum.sum/1 for numbers" do
    check all(list <- list_of(one_of([integer(), float()]))) do
      vector = A.Vector.new(list)

      assert Enum.sum(list) === A.Vector.sum(vector)
    end
  end

  @tag :property
  property "A.Vector any?/all?/find always return the same as Enum equivalents" do
    # use 33 as an arbitrary truthy value
    check all(
            value <- one_of([true, false, nil, constant(33)]),
            i1 <- big_positive_integer(),
            i2 <- big_positive_integer()
          ) do
      count = i1 + i2

      vector = A.Vector.duplicate(value, count)
      id = fn x -> x end

      negate = fn
        true -> false
        false -> true
        nil -> 33
        33 -> nil
      end

      replaced_vector = A.Vector.update_at(vector, i1, negate)

      assert !!value === A.Vector.any?(vector)
      assert !!value === A.Vector.any?(vector, id)
      assert !value === A.Vector.any?(vector, negate)
      assert !!value === A.Vector.all?(vector)
      assert !!value === A.Vector.all?(vector, id)
      assert !value === A.Vector.all?(vector, negate)

      assert true === A.Vector.any?(replaced_vector)
      assert true === A.Vector.any?(replaced_vector, id)
      assert true === A.Vector.any?(replaced_vector, negate)
      assert false === A.Vector.all?(replaced_vector)
      assert false === A.Vector.all?(replaced_vector, id)
      assert false === A.Vector.all?(replaced_vector, negate)
    end
  end
end
