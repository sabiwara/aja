defmodule A.Enum.PropTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

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

  defp with_seed(fun) when is_function(fun, 0) do
    Task.async(fn ->
      :rand.seed(:exrop, {101, 102, 103})
      fun.()
    end)
    |> Task.await()
  end

  @tag :property
  property "A.Enum functions should return the same as mirrored Enum functions" do
    check all(list <- list_of(value()), i1 <- integer(), i2 <- integer()) do
      vector = A.Vector.new(list)
      stream = Stream.map(list, & &1)
      map_set = MapSet.new(list)

      assert(^list = A.Enum.to_list(list))
      assert ^list = A.Enum.to_list(vector)
      assert ^list = A.Enum.to_list(stream)
      assert Enum.to_list(map_set) === A.Enum.to_list(map_set)

      list_length = length(list)

      assert list_length === A.Enum.count(vector)
      assert list_length === A.Enum.count(list)
      assert list_length === A.Enum.count(stream)
      assert MapSet.size(map_set) === A.Enum.count(map_set)

      min_result = Enum.min(list) |> capture_error()
      assert min_result === A.Enum.min(list) |> capture_error()
      assert min_result === A.Enum.min(vector) |> capture_error()
      assert min_result === A.Enum.min(stream) |> capture_error()
      assert min_result === A.Enum.min(map_set) |> capture_error()

      max_result = Enum.max(list) |> capture_error()
      assert max_result === A.Enum.max(vector) |> capture_error()
      assert max_result === A.Enum.max(list) |> capture_error()
      assert max_result === A.Enum.max(stream) |> capture_error()
      assert max_result === A.Enum.max(map_set) |> capture_error()

      assert max_result === A.Enum.min(list, &>=/2) |> capture_error()
      assert max_result === A.Enum.min(vector, &>=/2) |> capture_error()
      assert max_result === A.Enum.min(stream, &>=/2) |> capture_error()
      assert max_result === A.Enum.min(map_set, &>=/2) |> capture_error()

      assert min_result === A.Enum.max(list, &<=/2) |> capture_error()
      assert min_result === A.Enum.max(vector, &<=/2) |> capture_error()
      assert min_result === A.Enum.max(stream, &<=/2) |> capture_error()
      assert min_result === A.Enum.max(stream, &<=/2) |> capture_error()

      fun = &:erlang.phash2/1

      min_by_result = capture_error(A.Enum.min_by(list, fun))

      assert min_by_result === capture_error(A.Enum.min_by(vector, fun))
      assert min_by_result === capture_error(A.Enum.min_by(stream, fun))

      max_by_result = capture_error(A.Enum.max_by(list, fun))

      assert max_by_result === capture_error(A.Enum.max_by(vector, fun))
      assert max_by_result === capture_error(A.Enum.max_by(stream, fun))

      assert max_by_result === capture_error(A.Enum.min_by(list, fun, &>=/2))
      assert max_by_result === capture_error(A.Enum.min_by(vector, fun, &>=/2))
      assert max_by_result === capture_error(A.Enum.min_by(stream, fun, &>=/2))

      assert min_by_result === capture_error(A.Enum.max_by(list, fun, &<=/2))
      assert min_by_result === capture_error(A.Enum.max_by(vector, fun, &<=/2))
      assert min_by_result === capture_error(A.Enum.max_by(stream, fun, &<=/2))

      assert Enum.at(list, i1) === A.Enum.at(list, i1)
      assert Enum.at(list, i1) === A.Enum.at(vector, i1)
      assert Enum.at(list, i1) === A.Enum.at(stream, i1)
      assert Enum.at(map_set, i1) === A.Enum.at(map_set, i1)

      assert Enum.fetch(list, i1) === A.Enum.fetch(list, i1)
      assert Enum.fetch(list, i1) === A.Enum.fetch(vector, i1)
      assert Enum.fetch(list, i1) === A.Enum.fetch(stream, i1)
      assert Enum.fetch(map_set, i1) === A.Enum.fetch(map_set, i1)

      fetch_result = Enum.fetch!(list, i1) |> capture_error()
      assert fetch_result === A.Enum.fetch!(list, i1) |> capture_error()
      assert fetch_result === A.Enum.fetch!(vector, i1) |> capture_error()
      assert fetch_result === A.Enum.fetch!(stream, i1) |> capture_error()

      assert Enum.fetch!(map_set, i1) |> capture_error() ===
               A.Enum.fetch!(map_set, i1) |> capture_error()

      # amount must be >=0
      amount = abs(i2)
      slice_1 = Enum.slice(list, i1, amount)
      assert slice_1 === A.Enum.slice(list, i1, amount)
      assert slice_1 === A.Enum.slice(vector, i1, amount)
      assert slice_1 === A.Enum.slice(stream, i1, amount)
      assert Enum.slice(map_set, i1, amount) === A.Enum.slice(map_set, i1, amount)

      slice_2 = Enum.slice(list, i1..i2)
      assert slice_2 === A.Enum.slice(list, i1..i2)
      assert slice_2 === A.Enum.slice(vector, i1..i2)
      assert slice_2 === A.Enum.slice(stream, i1..i2)
      assert Enum.slice(map_set, i1..i2) === A.Enum.slice(map_set, i1..i2)

      reversed_list = Enum.reverse(list)
      assert ^reversed_list = A.Enum.reverse(list)
      assert ^reversed_list = A.Enum.reverse(vector)
      assert ^reversed_list = A.Enum.reverse(stream)
      assert Enum.reverse(map_set) === A.Enum.reverse(map_set)

      reduced_result = Enum.reduce(list, &[&1 | &2]) |> capture_error
      assert ^reduced_result = A.Enum.reduce(list, &[&1 | &2]) |> capture_error()
      assert ^reduced_result = A.Enum.reduce(vector, &[&1 | &2]) |> capture_error()
      assert ^reduced_result = A.Enum.reduce(stream, &[&1 | &2]) |> capture_error()

      reversed_list = Enum.reduce(list, [], &[&1 | &2])
      assert ^reversed_list = A.Enum.reduce(list, [], &[&1 | &2])
      assert ^reversed_list = A.Enum.reduce(vector, [], &[&1 | &2])
      assert ^reversed_list = A.Enum.reduce(stream, [], &[&1 | &2])
      assert Enum.reverse(map_set) === A.Enum.reduce(map_set, [], &[&1 | &2])

      inspected_list = Enum.map(list, &inspect/1)
      assert ^inspected_list = A.Enum.map(list, &inspect/1)
      assert ^inspected_list = A.Enum.map(vector, &inspect/1)
      assert ^inspected_list = A.Enum.map(stream, &inspect/1)
      assert Enum.map(map_set, &inspect/1) === A.Enum.map(map_set, &inspect/1)

      fun = fn x -> :erlang.phash2(x, 3) == 0 end
      filtered_list = Enum.filter(list, fun)
      assert ^filtered_list = A.Enum.filter(list, fun)
      assert ^filtered_list = A.Enum.filter(vector, fun)
      assert ^filtered_list = A.Enum.filter(stream, fun)
      assert Enum.filter(map_set, fun) === A.Enum.filter(map_set, fun)

      rejected_list = Enum.reject(list, fun)
      assert ^rejected_list = A.Enum.reject(list, fun)
      assert ^rejected_list = A.Enum.reject(vector, fun)
      assert ^rejected_list = A.Enum.reject(stream, fun)
      assert Enum.reject(map_set, fun) === A.Enum.reject(map_set, fun)

      any_result = Enum.any?(list)
      assert any_result === A.Enum.any?(list)
      assert any_result === A.Enum.any?(vector)
      assert any_result === A.Enum.any?(stream)
      assert any_result === A.Enum.any?(map_set)

      all_result = Enum.all?(list)
      assert all_result === A.Enum.all?(list)
      assert all_result === A.Enum.all?(vector)
      assert all_result === A.Enum.all?(stream)
      assert all_result === A.Enum.all?(map_set)

      fun = fn x -> :erlang.phash2(x, 2) == 0 end

      any_fun_result = Enum.any?(list, fun)
      assert any_fun_result === A.Enum.any?(list, fun)
      assert any_fun_result === A.Enum.any?(vector, fun)
      assert any_fun_result === A.Enum.any?(stream, fun)
      assert any_fun_result === A.Enum.any?(map_set, fun)

      all_fun_result = Enum.all?(list, fun)
      assert all_fun_result === A.Enum.all?(list, fun)
      assert all_fun_result === A.Enum.all?(vector, fun)
      assert all_fun_result === A.Enum.all?(stream, fun)
      assert all_fun_result === A.Enum.all?(map_set, fun)

      fun = fn x -> :erlang.phash2(x, 10) == 0 end

      found = Enum.find(list, fun)
      assert found === A.Enum.find(list, fun)
      assert found === A.Enum.find(vector, fun)
      assert found === A.Enum.find(stream, fun)

      found_index = Enum.find_index(list, fun)
      assert found_index === A.Enum.find_index(list, fun)
      assert found_index === A.Enum.find_index(vector, fun)
      assert found_index === A.Enum.find_index(stream, fun)

      fun = fn x -> if(:erlang.phash2(x, 10) == 0, do: inspect(x)) end

      found_value = Enum.find_value(list, fun)
      assert found_value === A.Enum.find_value(list, fun)
      assert found_value === A.Enum.find_value(vector, fun)
      assert found_value === A.Enum.find_value(stream, fun)

      sum_result = Enum.sum(list) |> capture_error()
      assert ^sum_result = A.Enum.sum(list) |> capture_error()
      assert ^sum_result = A.Enum.sum(vector) |> capture_error()
      assert ^sum_result = A.Enum.sum(stream) |> capture_error()
      assert capture_error(Enum.sum(map_set)) === capture_error(A.Enum.sum(map_set))

      product_result = Enum.reduce(list, 1, &(&2 * &1)) |> capture_error()
      assert ^product_result = A.Enum.product(list) |> capture_error()
      assert ^product_result = A.Enum.product(vector) |> capture_error()
      assert ^product_result = A.Enum.product(stream) |> capture_error()

      join_result = Enum.join(list, ",") |> capture_error()
      assert ^join_result = A.Enum.join(list, ",") |> capture_error()
      assert ^join_result = A.Enum.join(vector, ",") |> capture_error()
      assert ^join_result = A.Enum.join(stream, ",") |> capture_error()
      assert capture_error(Enum.join(map_set, ",")) === capture_error(A.Enum.join(map_set, ","))

      map_join_result = Enum.map_join(list, ",", &inspect/1)
      assert ^map_join_result = A.Enum.map_join(list, ",", &inspect/1)
      assert ^map_join_result = A.Enum.map_join(vector, ",", &inspect/1)
      assert ^map_join_result = A.Enum.map_join(stream, ",", &inspect/1)
      assert Enum.map_join(map_set, ",", &inspect/1) === A.Enum.map_join(map_set, ",", &inspect/1)

      intersperse_result = Enum.intersperse(list, :foo)
      assert ^intersperse_result = A.Enum.intersperse(list, :foo)
      assert ^intersperse_result = A.Enum.intersperse(vector, :foo)
      assert ^intersperse_result = A.Enum.intersperse(stream, :foo)
      assert Enum.intersperse(map_set, :foo) === A.Enum.intersperse(map_set, :foo)

      map_intersperse_result = Enum.map_intersperse(list, :bar, &inspect/1)
      assert ^map_intersperse_result = A.Enum.map_intersperse(list, :bar, &inspect/1)
      assert ^map_intersperse_result = A.Enum.map_intersperse(vector, :bar, &inspect/1)
      assert ^map_intersperse_result = A.Enum.map_intersperse(stream, :bar, &inspect/1)

      assert Enum.map_intersperse(map_set, :bar, &inspect/1) ===
               A.Enum.map_intersperse(map_set, :bar, &inspect/1)

      freqs = Enum.frequencies(list)
      assert ^freqs = A.Enum.frequencies(list)
      assert ^freqs = A.Enum.frequencies(vector)
      assert ^freqs = A.Enum.frequencies(stream)
      assert Map.new(freqs, fn {k, _v} -> {k, 1} end) === A.Enum.frequencies(map_set)

      fun = fn x -> :erlang.phash2(x, 10) end
      freqs_by_hash = Enum.frequencies_by(list, fun)
      assert ^freqs_by_hash = A.Enum.frequencies_by(list, fun)
      assert ^freqs_by_hash = A.Enum.frequencies_by(vector, fun)
      assert ^freqs_by_hash = A.Enum.frequencies_by(stream, fun)
      assert Enum.frequencies_by(map_set, fun) === A.Enum.frequencies_by(map_set, fun)

      groups_by_hash = Enum.group_by(list, fun)
      assert ^groups_by_hash = A.Enum.group_by(list, fun)
      assert ^groups_by_hash = A.Enum.group_by(vector, fun)
      assert ^groups_by_hash = A.Enum.group_by(stream, fun)
      assert Enum.group_by(map_set, fun) === A.Enum.group_by(map_set, fun)

      groups_by_hash2 = Enum.group_by(list, fun, &inspect/1)
      assert ^groups_by_hash2 = A.Enum.group_by(list, fun, &inspect/1)
      assert ^groups_by_hash2 = A.Enum.group_by(vector, fun, &inspect/1)
      assert ^groups_by_hash2 = A.Enum.group_by(stream, fun, &inspect/1)
      assert Enum.group_by(map_set, fun, &inspect/1) === A.Enum.group_by(map_set, fun, &inspect/1)

      assert Enum.uniq(list) === A.Enum.uniq(list)
      assert Enum.uniq(list) === A.Enum.uniq(vector)
      assert Enum.uniq(list) === A.Enum.uniq(stream)
      assert Enum.uniq(map_set) === A.Enum.uniq(map_set)

      assert Enum.dedup(list) === A.Enum.dedup(list)
      assert Enum.dedup(list) === A.Enum.dedup(vector)
      assert Enum.dedup(list) === A.Enum.dedup(stream)
      assert Enum.dedup(map_set) === A.Enum.dedup(map_set)

      fun = fn x -> :erlang.phash2(x, 10) end
      assert Enum.uniq_by(list, fun) === A.Enum.uniq_by(list, fun)
      assert Enum.uniq_by(list, fun) === A.Enum.uniq_by(vector, fun)
      assert Enum.uniq_by(list, fun) === A.Enum.uniq_by(stream, fun)
      assert Enum.uniq_by(map_set, fun) === A.Enum.uniq_by(map_set, fun)

      assert Enum.dedup_by(list, fun) === A.Enum.dedup_by(list, fun)
      assert Enum.dedup_by(list, fun) === A.Enum.dedup_by(vector, fun)
      assert Enum.dedup_by(list, fun) === A.Enum.dedup_by(stream, fun)
      assert Enum.dedup_by(map_set, fun) === A.Enum.dedup_by(map_set, fun)

      sorted = Enum.sort(list)
      assert ^sorted = A.Enum.sort(list)
      assert ^sorted = A.Enum.sort(vector)
      assert ^sorted = A.Enum.sort(stream)
      assert Enum.sort(map_set) === A.Enum.sort(map_set)

      fun = fn x -> :erlang.phash2(x) end
      sorted_by = Enum.sort_by(list, fun)
      assert ^sorted_by = A.Enum.sort_by(list, fun)
      assert ^sorted_by = A.Enum.sort_by(vector, fun)
      assert ^sorted_by = A.Enum.sort_by(stream, fun)
      assert Enum.sort_by(map_set, fun) === A.Enum.sort_by(map_set, fun)

      shuffled = with_seed(fn -> Enum.shuffle(list) end)
      assert ^shuffled = with_seed(fn -> A.Enum.shuffle(list) end)
      assert ^shuffled = with_seed(fn -> A.Enum.shuffle(vector) end)
      assert ^shuffled = with_seed(fn -> A.Enum.shuffle(stream) end)

      rand_result = with_seed(fn -> Enum.random(list) |> capture_error() end)
      assert ^rand_result = with_seed(fn -> A.Enum.random(list) |> capture_error() end)
      assert ^rand_result = with_seed(fn -> A.Enum.random(vector) |> capture_error() end)

      assert with_seed(fn -> Enum.random(stream) |> capture_error() end) ===
               with_seed(fn -> A.Enum.random(stream) |> capture_error() end)

      assert with_seed(fn -> Enum.random(map_set) |> capture_error() end) ===
               with_seed(fn -> A.Enum.random(map_set) |> capture_error() end)

      rand_taken = with_seed(fn -> Enum.take_random(list, amount) end)
      assert ^rand_taken = with_seed(fn -> A.Enum.take_random(list, amount) end)
      assert ^rand_taken = with_seed(fn -> A.Enum.take_random(vector, amount) end)
      assert ^rand_taken = with_seed(fn -> A.Enum.take_random(stream, amount) end)
    end
  end

  @tag :property
  property "A.Enum.sum/1 should return the same as Enum.sum/1 for numbers" do
    check all(list <- list_of(one_of([integer(), float()]))) do
      vector = A.Vector.new(list)
      map_set = MapSet.new(list)

      assert Enum.sum(list) === A.Enum.sum(list)
      assert Enum.sum(list) === A.Enum.sum(vector)
      assert Enum.sum(map_set) === A.Enum.sum(map_set)
    end
  end

  @tag :property
  property "A.Enum any?/all?/find always return the same as Enum equivalents" do
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

      assert !!value === A.Enum.any?(vector)
      assert !!value === A.Enum.any?(vector, id)
      assert !value === A.Enum.any?(vector, negate)
      assert !!value === A.Enum.all?(vector)
      assert !!value === A.Enum.all?(vector, id)
      assert !value === A.Enum.all?(vector, negate)

      assert true === A.Enum.any?(replaced_vector)
      assert true === A.Enum.any?(replaced_vector, id)
      assert true === A.Enum.any?(replaced_vector, negate)
      assert false === A.Enum.all?(replaced_vector)
      assert false === A.Enum.all?(replaced_vector, id)
      assert false === A.Enum.all?(replaced_vector, negate)
    end
  end
end
