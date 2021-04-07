defmodule A.Enum.PropTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import A.TestHelpers
  import A.TestDataGenerators

  @moduletag timeout: :infinity
  @moduletag :property

  def value do
    frequency([
      {20, integer()},
      {4, simple_value()},
      {1, term()}
    ])
  end

  property "A.Enum functions should return the same as mirrored Enum functions" do
    check all(list <- list_of(value()), i1 <- integer(), i2 <- integer()) do
      vector = A.Vector.new(list)
      stream = Stream.map(list, & &1)
      ord_map = A.OrdMap.new(list, &{&1, &1})
      map_set = MapSet.new(list)

      assert(^list = A.Enum.to_list(list))
      assert ^list = A.Enum.to_list(vector)
      assert ^list = A.Enum.to_list(stream)
      assert Enum.to_list(ord_map) === A.Enum.to_list(ord_map)
      assert Enum.to_list(map_set) === A.Enum.to_list(map_set)

      list_length = length(list)
      unique_length = MapSet.size(map_set)

      assert list_length === A.Enum.count(list)
      assert list_length === A.Enum.count(vector)
      assert list_length === A.Enum.count(stream)
      assert unique_length === A.Enum.count(ord_map)
      assert unique_length === A.Enum.count(map_set)

      assert Enum.count(i1..i2) == A.Enum.count(i1..i2)

      fun = fn x -> :erlang.phash2(x, 7) == 0 end
      count_result = Enum.count(list, fun)
      assert ^count_result = A.Enum.count(list, fun)
      assert ^count_result = A.Enum.count(vector, fun)
      assert ^count_result = A.Enum.count(stream, fun)
      assert Enum.count(ord_map, fun) === A.Enum.count(ord_map, fun)
      assert Enum.count(map_set, fun) === A.Enum.count(map_set, fun)

      expected_empty = Enum.empty?(list)
      assert expected_empty == A.Enum.empty?(list)
      assert expected_empty == A.Enum.empty?(vector)
      assert expected_empty == A.Enum.empty?(stream)
      assert expected_empty == A.Enum.empty?(ord_map)
      assert expected_empty == A.Enum.empty?(map_set)

      assert Enum.empty?(i1..i2) == A.Enum.empty?(i1..i2)

      min_result = Enum.min(list) |> capture_error()
      assert min_result === A.Enum.min(list) |> capture_error()
      assert min_result === A.Enum.min(vector) |> capture_error()
      assert min_result === A.Enum.min(stream) |> capture_error()
      assert Enum.min(map_set) |> capture_error() === A.Enum.min(map_set) |> capture_error()

      max_result = Enum.max(list) |> capture_error()
      assert max_result === A.Enum.max(vector) |> capture_error()
      assert max_result === A.Enum.max(list) |> capture_error()
      assert max_result === A.Enum.max(stream) |> capture_error()
      assert Enum.max(map_set) |> capture_error() === A.Enum.max(map_set) |> capture_error()

      assert max_result === A.Enum.min(list, &>=/2) |> capture_error()
      assert max_result === A.Enum.min(vector, &>=/2) |> capture_error()
      assert max_result === A.Enum.min(stream, &>=/2) |> capture_error()

      assert Enum.min(map_set, &>=/2) |> capture_error() ===
               A.Enum.min(map_set, &>=/2) |> capture_error()

      assert min_result === A.Enum.max(list, &<=/2) |> capture_error()
      assert min_result === A.Enum.max(vector, &<=/2) |> capture_error()
      assert min_result === A.Enum.max(stream, &<=/2) |> capture_error()

      assert Enum.max(map_set, &>=/2) |> capture_error() ===
               A.Enum.max(map_set, &>=/2) |> capture_error()

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

      taken = Enum.take(list, i1)
      assert taken === A.Enum.take(list, i1)
      assert taken === A.Enum.take(vector, i1)
      assert taken === A.Enum.take(stream, i1)
      assert Enum.take(map_set, i1) === A.Enum.take(map_set, i1)

      dropped = Enum.drop(list, i1)
      assert dropped === A.Enum.drop(list, i1)
      assert dropped === A.Enum.drop(vector, i1)
      assert dropped === A.Enum.drop(stream, i1)
      assert Enum.drop(map_set, i1) === A.Enum.drop(map_set, i1)

      split_result = Enum.split(list, i1)
      assert split_result === A.Enum.split(list, i1)
      assert split_result === A.Enum.split(vector, i1)
      assert split_result === A.Enum.split(stream, i1)
      assert Enum.split(map_set, i1) === A.Enum.split(map_set, i1)

      fun = fn x -> :erlang.phash2(x, 7) != 0 end

      take_while_result = Enum.take_while(list, fun)
      assert take_while_result === A.Enum.take_while(list, fun)
      assert take_while_result === A.Enum.take_while(vector, fun)
      assert take_while_result === A.Enum.take_while(stream, fun)
      assert Enum.take_while(map_set, fun) === A.Enum.take_while(map_set, fun)

      drop_while_result = Enum.drop_while(list, fun)
      assert drop_while_result === A.Enum.drop_while(list, fun)
      assert drop_while_result === A.Enum.drop_while(vector, fun)
      assert drop_while_result === A.Enum.drop_while(stream, fun)
      assert Enum.drop_while(map_set, fun) === A.Enum.drop_while(map_set, fun)

      split_while_result = Enum.split_while(list, fun)
      assert split_while_result === A.Enum.split_while(list, fun)
      assert split_while_result === A.Enum.split_while(vector, fun)
      assert split_while_result === A.Enum.split_while(stream, fun)
      assert Enum.split_while(map_set, fun) === A.Enum.split_while(map_set, fun)

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

      assert {^filtered_list, ^rejected_list} = A.Enum.split_with(list, fun)
      assert {^filtered_list, ^rejected_list} = A.Enum.split_with(vector, fun)
      assert {^filtered_list, ^rejected_list} = A.Enum.split_with(stream, fun)
      assert Enum.split_with(map_set, fun) === A.Enum.split_with(map_set, fun)

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
      assert ^join_result = A.Enum.join(stream, ",") |> capture_error()
      assert capture_error(Enum.join(map_set, ",")) === capture_error(A.Enum.join(map_set, ","))

      # foldr VS foldl, the first argument to fail won't be the same
      case join_result do
        {:ok, ok_result} ->
          assert ^ok_result = A.Enum.join(vector, ",")

        _error ->
          reverse_error = list |> Enum.reverse() |> Enum.join(", ") |> capture_error()
          assert ^reverse_error = A.Enum.join(vector, ",") |> capture_error()
      end

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

      fun = fn x -> [x, inspect(x)] end
      flat_map_result = Enum.flat_map(list, fun)
      assert ^flat_map_result = A.Enum.flat_map(list, fun)
      assert ^flat_map_result = A.Enum.flat_map(vector, fun)
      assert ^flat_map_result = A.Enum.flat_map(stream, fun)

      assert Enum.flat_map(map_set, fun) === A.Enum.flat_map(map_set, fun)

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

      index_list = Enum.with_index(list, i1)
      assert ^index_list = A.Enum.with_index(list, i1)
      assert ^index_list = A.Enum.with_index(vector, i1)
      assert ^index_list = A.Enum.with_index(stream, i1)
      assert Enum.with_index(map_set, i1) === A.Enum.with_index(map_set, i1)

      fun = fn x, i -> {x, i + i1} end
      assert ^index_list = A.Enum.with_index(list, fun)
      assert ^index_list = A.Enum.with_index(vector, fun)
      assert ^index_list = A.Enum.with_index(stream, fun)
      assert Enum.with_index(map_set, i1) === A.Enum.with_index(map_set, fun)

      fun = fn x, i -> {{x, i}, i + 1} end
      assert {index_list, list_length + i1} === A.Enum.map_reduce(list, i1, fun)
      assert {index_list, list_length + i1} === A.Enum.map_reduce(vector, i1, fun)
      assert {index_list, list_length + i1} === A.Enum.map_reduce(stream, i1, fun)
      assert Enum.map_reduce(map_set, i1, fun) === A.Enum.map_reduce(map_set, i1, fun)

      scanned_result = Enum.scan(list, &max/2)
      assert ^scanned_result = A.Enum.scan(list, &max/2)
      assert ^scanned_result = A.Enum.scan(vector, &max/2)
      assert ^scanned_result = A.Enum.scan(stream, &max/2)
      assert Enum.scan(map_set, &max/2) === A.Enum.scan(map_set, &max/2)

      scanned_result = Enum.scan(list, 42, &max/2)
      assert ^scanned_result = A.Enum.scan(list, 42, &max/2)
      assert ^scanned_result = A.Enum.scan(vector, 42, &max/2)
      assert ^scanned_result = A.Enum.scan(stream, 42, &max/2)
      assert Enum.scan(map_set, 42, &max/2) === A.Enum.scan(map_set, 42, &max/2)

      sorted = Enum.sort(list)
      assert ^sorted = A.Enum.sort(list)
      assert ^sorted = A.Enum.sort(vector)
      assert ^sorted = A.Enum.sort(stream)
      # floats / ints might not come in the same order
      assert Enum.sort(map_set) == A.Enum.sort(map_set)

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

  property "A.Enum.sum/1 should return the same as Enum.sum/1 for numbers" do
    check all(list <- list_of(one_of([integer(), float()]))) do
      vector = A.Vector.new(list)
      map_set = MapSet.new(list)

      assert Enum.sum(list) === A.Enum.sum(list)
      assert Enum.sum(list) === A.Enum.sum(vector)
      assert Enum.sum(map_set) === A.Enum.sum(map_set)
    end
  end

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

  property "A.Enum functions taking 2 enumerables should work the same as Enum" do
    check all(list1 <- list_of(value()), list2 <- list_of(value())) do
      vector1 = A.Vector.new(list1)
      stream1 = Stream.map(list1, & &1)

      vector2 = A.Vector.new(list2)
      stream2 = Stream.map(list2, & &1)

      concat = Enum.concat(list1, list2)
      reversed = Enum.reverse(list1, list2)
      zipped = Enum.zip(list1, list2)

      for x1 <- [list1, vector1, stream1], x2 <- [list2, vector2, stream2] do
        assert ^concat = A.Enum.concat(x1, x2)
        assert ^reversed = A.Enum.reverse(x1, x2)
        assert ^zipped = A.Enum.zip(x1, x2)
      end

      zipped_vector = A.Vector.zip(vector1, vector2)
      zipped_stream = Stream.map(zipped, & &1)
      unzipped = Enum.unzip(zipped)

      assert ^unzipped = A.Enum.unzip(zipped)
      assert ^unzipped = A.Enum.unzip(zipped_vector)
      assert ^unzipped = A.Enum.unzip(zipped_stream)
    end
  end
end
