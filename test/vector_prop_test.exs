defmodule A.Vector.PropTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import A, only: [vec: 1]

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
      {:append_many, list_of(value())},
      :delete_last
    ])
  end

  def apply_operation(%A.Vector{} = vector, {:append, value}) do
    new_vector = A.Vector.append(vector, value)

    assert ^new_vector = A.Vector.append_many(vector, [value])

    assert value === A.Vector.last(new_vector)
    assert value in new_vector

    assert A.Vector.size(vector) + 1 === A.Vector.size(new_vector)

    new_vector
  end

  def apply_operation(%A.Vector{} = vector, {:append_many, values}) do
    new_vector = A.Vector.append_many(vector, values)

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
    assert vector === A.Vector.append_many(vector, [])
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

      assert vz === A.Vector.append_many(vx, y)
      assert vz === A.Vector.append_many(vx, vy)
      assert vz === Enum.into(y, vx)
      assert vz === Enum.into(vy, vx)

      assert A.Vector.size(vz) === A.Vector.size(vx) + A.Vector.size(vy)
    end
  end

  @tag :property
  property "duplicate/2 should work as expected" do
    check all(
            x <- value(),
            n <- positive_integer()
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
    check all(list <- list_of(value()), i1 <- integer(), i2 <- positive_integer()) do
      vector = A.Vector.new(list)

      assert_properties(vector)

      assert Enum.count(list) === A.Vector.size(vector)
      assert Enum.count(list) === Enum.count(vector)
      assert capture_error(Enum.min(list)) === capture_error(A.Vector.min(vector))
      assert capture_error(Enum.max(list)) === capture_error(A.Vector.max(vector))

      assert Enum.at(list, i1) === A.Vector.at(vector, i1)
      assert Enum.at(list, i1) === vector[i1]
      assert Enum.slice(list, i1, i2) === Enum.slice(vector, i1, i2)
      assert Enum.slice(list, i1..i2) === Enum.slice(vector, i1..i2)

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

      assert Enum.any?(list) === A.Vector.any?(vector)
      assert Enum.all?(list) === A.Vector.all?(vector)

      assert Enum.any?(list, &hash_multiple_of_2/1) ===
               A.Vector.any?(vector, &hash_multiple_of_2/1)

      assert Enum.all?(list, &hash_multiple_of_2/1) ===
               A.Vector.all?(vector, &hash_multiple_of_2/1)

      assert true === A.Vector.all?(A.Vector.new(filtered_list), &hash_multiple_of_2/1)

      assert false ===
               A.Vector.any?(A.Vector.new(filtered_list), fn x -> !hash_multiple_of_2(x) end)

      assert capture_error(Enum.sum(list)) === capture_error(A.Vector.sum(vector))

      assert capture_error(Enum.join(list, ",")) === capture_error(A.Vector.join(vector, ","))
      assert Enum.map_join(list, ",", &inspect/1) === A.Vector.map_join(vector, ",", &inspect/1)

      assert Enum.intersperse(list, nil) |> A.Vector.new() === A.Vector.intersperse(vector, nil)

      assert Enum.map_intersperse(list, nil, &inspect/1) |> A.Vector.new() ===
               A.Vector.map_intersperse(vector, nil, &inspect/1)
    end
  end

  @tag :property
  property "A.Vector.sum/1 should return the same as Enum.sum/1 for numbers" do
    check all(list <- list_of(one_of([integer(), float()]))) do
      vector = A.Vector.new(list)

      assert Enum.sum(list) === A.Vector.sum(vector)
    end
  end
end
