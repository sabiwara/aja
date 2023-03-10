defmodule Aja.Enum do
  @moduledoc """
  Drop-in replacement for the `Enum` module, optimized to work with Aja's data structures such as `Aja.Vector`.

  It currently only covers a subset of `Enum`, but `Aja.Enum` aims to completely mirror the API of `Enum`,
  and should behave exactly the same for any type of `Enumerable`.
  The only expected difference should be a significant increase in performance for Aja structures.

  ## Rationale

  Structures such as `Aja.Vector` or `Aja.OrdMap` are implementing the `Enumerable` protocol, which means they can be
  used directly with the `Enum` module. The `Enumerable` protocol however comes with its overhead and is strongly
  limited in terms of performance.

  On the other hand, `Aja.Enum` provides hand-crafted highly-optimized functions that fully take advantage of
  immutable vectors. The speedup can easily reach more than a factor 10 compared to `Enum` used on non-list
  structures, and sometimes even be noticeably faster than `Enum` used over lists.

  One of the main reasons to adopt a specific data structure is the performance.
  Using vectors with `Enum` would defeat the purpose, hence the introduction of `Aja.Enum`.

      iex> vector = Aja.Vector.new(1..10000)
      iex> Enum.sum(vector)    # slow
      50005000
      iex> Aja.Enum.sum(vector)  # same result, much faster
      50005000

  """

  require Aja.Vector.Raw, as: RawVector
  alias Aja.EnumHelper, as: H

  @compile :inline_list_funcs

  @dialyzer :no_opaque

  @type index :: integer
  @type value :: any
  @type t(value) :: Aja.Vector.t(value) | [value] | Enumerable.t()

  @empty_vector RawVector.empty()

  # TODO optimize ranges (sum, random...)

  @doc """
  Converts `enumerable` to a list.

  Mirrors `Enum.to_list/1` with higher performance for Aja structures.
  """
  @spec to_list(t(val)) :: [val] when val: value
  defdelegate to_list(enumerable), to: H

  @doc """
  Returns the size of the `enumerable`.

  Mirrors `Enum.count/1` with higher performance for Aja structures.
  """
  @spec count(t(any)) :: non_neg_integer
  def count(enumerable) do
    case enumerable do
      list when is_list(list) -> length(list)
      %Aja.Vector{__vector__: vector} -> RawVector.size(vector)
      %Aja.OrdMap{__ord_map__: map} -> map_size(map)
      %MapSet{} -> MapSet.size(enumerable)
      start..stop -> abs(start - stop) + 1
      _ -> Enum.count(enumerable)
    end
  end

  @doc """
  Returns the count of elements in the `enumerable` for which `fun` returns
  a truthy value.

  Mirrors `Enum.count/2` with higher performance for Aja structures.
  """
  @spec count(t(val), (val -> as_boolean(term))) :: non_neg_integer when val: value
  def count(enumerable, fun) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil ->
        Enum.count(enumerable, fun)

      list when is_list(list) ->
        count_list(list, fun, 0)

      vector ->
        RawVector.count(vector, fun)
    end
  end

  defp count_list([], _fun, acc), do: acc

  defp count_list([head | tail], fun, acc) do
    new_acc =
      if fun.(head) do
        acc + 1
      else
        acc
      end

    count_list(tail, fun, new_acc)
  end

  @doc """
  Returns `true` if `enumerable` is empty, otherwise `false`.

  Mirrors `Enum.empty?/1` with higher performance for Aja structures.
  """
  @spec empty?(t(any)) :: boolean
  def empty?(enumerable) do
    case enumerable do
      list when is_list(list) -> list == []
      %Aja.Vector{__vector__: vector} -> vector === @empty_vector
      %Aja.OrdMap{__ord_map__: map} -> map == %{}
      %MapSet{} -> MapSet.size(enumerable) == 0
      %Range{} -> false
      _ -> Enum.empty?(enumerable)
    end
  end

  # Note: Could not optimize it noticeably for vectors
  @doc """
  Checks if `element` exists within the `enumerable`.

  Just an alias for `Enum.member?/2`, does not improve performance.
  """
  @spec member?(t(val), val) :: boolean when val: value
  defdelegate member?(enumerable, value), to: Enum

  # TODO optimize for vector
  @doc """
  Returns a subset list of the given `enumerable` by `index_range`.

  Mirrors `Enum.slice/2` with higher performance for Aja structures.
  """
  @spec slice(t(val), Range.t()) :: [val] when val: value
  defdelegate slice(enumerable, index_range), to: Enum

  @doc """
  Returns a subset list of the given `enumerable`, from `start_index` (zero-based)
  with `amount` number of elements if available.

  Mirrors `Enum.slice/3`.
  """
  @spec slice(t(val), index, non_neg_integer) :: [val] when val: value
  defdelegate slice(enumerable, start_index, amount), to: Enum

  @doc """
  Inserts the given `enumerable` into a `collectable`.

  Mirrors `Enum.into/2` with higher performance for Aja structures.
  """
  @spec into(t(val), Collectable.t()) :: Collectable.t() when val: value
  def into(enumerable, collectable)

  def into(enumerable, %Aja.Vector{} = vector) do
    # TODO improve when this is the empty vector/ord_map
    Aja.Vector.concat(vector, enumerable)
  end

  def into(enumerable, %Aja.OrdMap{} = ord_map) do
    Aja.OrdMap.merge_list(ord_map, H.to_list(enumerable))
  end

  def into(enumerable, collectable) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> enumerable
      list when is_list(list) -> list
      vector -> RawVector.to_list(vector)
    end
    |> Enum.into(collectable)
  end

  @doc """
  Inserts the given `enumerable` into a `collectable` according to the `transform` function.

  Mirrors `Enum.into/3` with higher performance for Aja structures.
  """
  def into(enumerable, collectable, transform)

  def into(enumerable, %Aja.Vector{} = vector, transform) do
    # TODO we can probably improve this with the builder
    Aja.Vector.concat(vector, H.map(enumerable, transform))
  end

  def into(enumerable, %Aja.OrdMap{} = ord_map, transform) do
    Aja.OrdMap.merge_list(ord_map, H.map(enumerable, transform))
  end

  def into(enumerable, collectable, transform) when is_function(transform, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> enumerable
      list when is_list(list) -> list
      vector -> RawVector.to_list(vector)
    end
    |> Enum.into(collectable, transform)
  end

  @doc """
  Given an enumerable of enumerables, concatenates the `enumerables` into
  a single list.

  Mirrors `Enum.concat/1` with higher performance for Aja structures.
  """
  @spec concat(t(t(val))) :: t(val) when val: value
  def concat(enumerables) do
    case H.try_get_raw_vec_or_list(enumerables) do
      nil -> Enum.reverse(enumerables) |> concat_wrap([])
      list when is_list(list) -> :lists.reverse(list) |> concat_wrap([])
      vector -> RawVector.foldr(vector, [], &concat/2)
    end
  end

  defp concat_wrap(_reversed = [], acc), do: acc

  defp concat_wrap([head | tail], acc) do
    concat_wrap(tail, concat(head, acc))
  end

  @doc """
  Concatenates the enumerable on the `right` with the enumerable on the `left`.

  Mirrors `Enum.concat/2` with higher performance for Aja structures.
  """
  @spec concat(t(val), t(val)) :: t(val) when val: value
  def concat(left, right)

  def concat(left, right) when is_list(left) and is_list(right) do
    left ++ right
  end

  def concat(left, right) do
    case H.try_get_raw_vec_or_list(left) do
      nil -> Enum.concat(left, right)
      list when is_list(list) -> list ++ to_list(right)
      vector -> RawVector.to_list(vector, to_list(right))
    end
  end

  @doc """
  Finds the element at the given `index` (zero-based).

  Mirrors `Enum.at/3` with higher performance for Aja structures.
  """
  @spec at(t(val), integer, default) :: val | default when val: value, default: any
  def at(enumerable, index, default \\ nil) when is_integer(index) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil ->
        Enum.at(enumerable, index, default)

      list when is_list(list) ->
        Enum.at(list, index, default)

      vector ->
        size = RawVector.size(vector)

        case RawVector.actual_index(index, size) do
          nil -> default
          actual_index -> RawVector.fetch_positive!(vector, actual_index)
        end
    end
  end

  @doc """
  Finds the element at the given `index` (zero-based).

  Mirrors `Enum.fetch/2` with higher performance for Aja structures.
  """
  @spec fetch(t(val), integer) :: {:ok, val} | :error when val: value
  def fetch(enumerable, index) when is_integer(index) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil ->
        Enum.fetch(enumerable, index)

      list when is_list(list) ->
        Enum.fetch(list, index)

      vector ->
        size = RawVector.size(vector)

        case RawVector.actual_index(index, size) do
          nil -> :error
          actual_index -> {:ok, RawVector.fetch_positive!(vector, actual_index)}
        end
    end
  end

  @doc """
  Finds the element at the given `index` (zero-based).

  Mirrors `Enum.fetch!/2` with higher performance for Aja structures.
  """
  @spec fetch!(t(val), integer) :: val when val: value
  def fetch!(enumerable, index) when is_integer(index) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil ->
        Enum.fetch!(enumerable, index)

      list when is_list(list) ->
        Enum.fetch!(list, index)

      vector ->
        size = RawVector.size(vector)

        case RawVector.actual_index(index, size) do
          nil -> raise Enum.OutOfBoundsError
          actual_index -> RawVector.fetch_positive!(vector, actual_index)
        end
    end
  end

  @doc """
  Returns a list of elements in `enumerable` in reverse order.

  Mirrors `Enum.reverse/1` with higher performance for Aja structures.
  """
  @spec reverse(t(val)) :: [val] when val: value
  def reverse(enumerable) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.reverse(enumerable)
      list when is_list(list) -> :lists.reverse(list)
      vector -> RawVector.reverse_to_list(vector, [])
    end
  end

  @doc """
  Reverses the elements in `enumerable`, concatenates the `tail`,
  and returns it as a list.

  Mirrors `Enum.reverse/2` with higher performance for Aja structures.
  """
  @spec reverse(t(val), t(val)) :: [val] when val: value
  def reverse(enumerable, tail) do
    tail = H.to_list(tail)

    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.reverse(enumerable, tail)
      list when is_list(list) -> :lists.reverse(list, tail)
      vector -> RawVector.reverse_to_list(vector, tail)
    end
  end

  @doc """
  Returns a list where each element is the result of invoking
  `fun` on each corresponding element of `enumerable`.

  Mirrors `Enum.map/2` with higher performance for Aja structures.
  """
  @spec map(t(v1), (v1 -> v2)) :: [v2] when v1: value, v2: value
  defdelegate map(enumerable, fun), to: H

  @doc """
  Filters the `enumerable`, i.e. returns only those elements
  for which `fun` returns a truthy value.

  Mirrors `Enum.filter/2` with higher performance for Aja structures.
  """
  @spec filter(t(val), (val -> as_boolean(term))) :: [val] when val: value
  def filter(enumerable, fun) when is_function(fun, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.filter(enumerable, fun)
      list when is_list(list) -> filter_list(list, fun, [])
      vector -> RawVector.filter_to_list(vector, fun)
    end
  end

  defp filter_list([], _fun, acc), do: :lists.reverse(acc)

  defp filter_list([head | tail], fun, acc) do
    acc =
      if fun.(head) do
        [head | acc]
      else
        acc
      end

    filter_list(tail, fun, acc)
  end

  @doc """
  Returns a list of elements in `enumerable` excluding those for which the function `fun` returns
  a truthy value.

  Mirrors `Enum.reject/2` with higher performance for Aja structures.
  """
  @spec reject(t(val), (val -> as_boolean(term))) :: [val] when val: value
  def reject(enumerable, fun) when is_function(fun, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.reject(enumerable, fun)
      list when is_list(list) -> Enum.reject(list, fun)
      vector -> RawVector.reject_to_list(vector, fun)
    end
  end

  @doc """
  Splits the `enumerable` in two lists according to the given function `fun`.

  Mirrors `Enum.split_with/2` with higher performance for Aja structures.
  """
  @spec split_with(t(val), (val -> as_boolean(term))) :: {[val], [val]} when val: value
  def split_with(enumerable, fun) when is_function(fun, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.split_with(enumerable, fun)
      list when is_list(list) -> Enum.split_with(list, fun)
      vector -> vector |> RawVector.to_list() |> Enum.split_with(fun)
    end
  end

  @doc """
  Invokes `fun` for each element in the `enumerable` with the
  accumulator.

  Mirrors `Enum.reduce/2` with higher performance for Aja structures.
  """
  @spec reduce(t(val), (val, val -> val)) :: val when val: value
  def reduce(enumerable, fun) when is_function(fun, 2) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.reduce(enumerable, fun)
      list when is_list(list) -> Enum.reduce(list, fun)
      vector -> RawVector.reduce(vector, fun)
    end
  end

  @doc """
  Invokes `fun` for each element in the `enumerable` with the accumulator.

  Mirrors `Enum.reduce/3` with higher performance for Aja structures.
  """
  @spec reduce(t(val), acc, (val, acc -> acc)) :: acc when val: value, acc: term
  def reduce(enumerable, acc, fun) when is_function(fun, 2) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.reduce(enumerable, acc, fun)
      list when is_list(list) -> :lists.foldl(fun, acc, list)
      vector -> RawVector.foldl(vector, acc, fun)
    end
  end

  # FINDS

  @doc """
  Returns `true` if at least one element in `enumerable` is truthy.

  When an element has a truthy value (neither `false` nor `nil`) iteration stops
  immediately and `true` is returned. In all other cases `false` is returned.

  ## Examples

      iex> Aja.Enum.any?([false, false, false])
      false

      iex> Aja.Enum.any?([false, true, false])
      true

      iex> Aja.Enum.any?([])
      false

  """
  @spec any?(t(as_boolean(val))) :: boolean when val: value
  def any?(enumerable) do
    case enumerable do
      %Aja.Vector{__vector__: vector} -> RawVector.any?(vector)
      _ -> Enum.any?(enumerable)
    end
  end

  @doc """
  Returns `true` if `fun.(element)` is truthy for at least one element in `enumerable`.

  Iterates over the `enumerable` and invokes `fun` on each element. When an invocation
  of `fun` returns a truthy value (neither `false` nor `nil`) iteration stops
  immediately and `true` is returned. In all other cases `false` is returned.

  ## Examples

      iex> Aja.Enum.any?([2, 4, 6], fn x -> rem(x, 2) == 1 end)
      false

      iex> Aja.Enum.any?([2, 3, 4], fn x -> rem(x, 2) == 1 end)
      true

      iex> Aja.Enum.any?([], fn x -> x > 0 end)
      false

  """
  # TODO When only support Elixir 1.12
  # @doc copy_doc_for.(:any?, 2)
  @spec any?(t(val), (val -> as_boolean(term))) :: boolean when val: value
  def any?(enumerable, fun) when is_function(fun, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.any?(enumerable, fun)
      list when is_list(list) -> Enum.any?(list, fun)
      vector -> RawVector.any?(vector, fun)
    end
  end

  @doc """
  Returns `true` if  all elements in `enumerable` are truthy.

  When an element has a falsy value (`false` or `nil`) iteration stops immediately
  and `false` is returned. In all other cases `true` is returned.

  ## Examples

      iex> Aja.Enum.all?([1, 2, 3])
      true

      iex> Aja.Enum.all?([1, nil, 3])
      false

      iex> Aja.Enum.all?([])
      true

  """
  @spec all?(t(as_boolean(val))) :: boolean when val: value
  def all?(enumerable) do
    case enumerable do
      %Aja.Vector{__vector__: vector} -> RawVector.all?(vector)
      _ -> Enum.all?(enumerable)
    end
  end

  @doc """
  Returns `true` if `fun.(element)` is truthy for all elements in `enumerable`.

  Iterates over `enumerable` and invokes `fun` on each element. If `fun` ever
  returns a falsy value (`false` or `nil`), iteration stops immediately and
  `false` is returned. Otherwise, `true` is returned.

  ## Examples

      iex> Aja.Enum.all?([2, 4, 6], fn x -> rem(x, 2) == 0 end)
      true

      iex> Aja.Enum.all?([2, 3, 4], fn x -> rem(x, 2) == 0 end)
      false

      iex> Aja.Enum.all?([], fn _ -> nil end)
      true

  """
  # TODO When only support Elixir 1.12
  # @doc copy_doc_for.(:all?, 2)
  @spec all?(t(val), (val -> as_boolean(term))) :: boolean when val: value
  def all?(enumerable, fun) when is_function(fun, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.all?(enumerable, fun)
      list when is_list(list) -> Enum.all?(list, fun)
      vector -> RawVector.all?(vector, fun)
    end
  end

  @doc """
  Returns the first element for which `fun` returns a truthy value.
  If no such element is found, returns `default`.

  Mirrors `Enum.find/3` with higher performance for Aja structures.
  """
  @spec find(t(val), default, (val -> as_boolean(term))) :: val | default
        when val: value, default: value
  def find(enumerable, default \\ nil, fun) when is_function(fun, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.find(enumerable, default, fun)
      list when is_list(list) -> Enum.find(list, default, fun)
      vector -> RawVector.find(vector, default, fun)
    end
  end

  @doc """
  Similar to `find/3`, but returns the value of the function
  invocation instead of the element itself.

  Mirrors `Enum.find_value/3` with higher performance for Aja structures.
  """
  @spec find_value(t(val), default, (val -> new_val)) :: new_val | default
        when val: value, new_val: value, default: value
  def find_value(enumerable, default \\ nil, fun) when is_function(fun, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.find_value(enumerable, default, fun)
      list when is_list(list) -> Enum.find_value(list, default, fun)
      vector -> RawVector.find_value(vector, fun) || default
    end
  end

  @doc """
  Similar to `find/3`, but returns the index (zero-based)
  of the element instead of the element itself.

  Mirrors `Enum.find_index/2` with higher performance for Aja structures.
  """
  @spec find_index(t(val), (val -> as_boolean(term))) :: non_neg_integer | nil when val: value
  def find_index(enumerable, fun) when is_function(fun, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.find_index(enumerable, fun)
      list when is_list(list) -> Enum.find_index(list, fun)
      vector -> RawVector.find_index(vector, fun)
    end
  end

  ## FOLDS

  @doc """
  Returns the sum of all elements.

  Mirrors `Enum.sum/1` with higher performance for Aja structures.
  """
  @spec sum(t(num)) :: num when num: number
  def sum(enumerable) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil ->
        Enum.sum(enumerable)

      list when is_list(list) ->
        :lists.sum(list)

      vector ->
        RawVector.sum(vector)
    end
  end

  @doc """
  Returns the product of all elements in the `enumerable`.

  Mirrors `Enum.product/1`.

  Raises `ArithmeticError` if `enumerable` contains a non-numeric value.

  ## Examples

      iex> 1..5 |> Aja.Enum.product()
      120
      iex> [] |> Aja.Enum.product()
      1

  """
  @spec product(t(num)) :: num when num: number
  def product(enumerable) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil ->
        # TODO use Enum.product/1 for Elixir 1.11
        reduce(enumerable, 1, &*/2)

      list when is_list(list) ->
        product_list(list, 1)

      vector ->
        RawVector.product(vector)
    end
  end

  defp product_list([], acc), do: acc

  defp product_list([head | rest], acc) do
    product_list(rest, head * acc)
  end

  @doc """
  Joins the given `enumerable` into a string using `joiner` as a
  separator.

  Mirrors `Enum.join/2` with higher performance for Aja structures.
  """
  @spec join(t(val), String.t()) :: String.t() when val: String.Chars.t()
  def join(enumerable, joiner \\ "") when is_binary(joiner) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil ->
        Enum.join(enumerable, joiner)

      list when is_list(list) ->
        Enum.join(list, joiner)

      vector ->
        # TODO add join_as_iodata
        RawVector.join_as_iodata(vector, joiner) |> IO.iodata_to_binary()
    end
  end

  @doc """
  Maps and joins the given `enumerable` in one pass.

  Mirrors `Enum.map_join/3` with higher performance for Aja structures.
  """
  @spec map_join(t(val), String.t(), (val -> String.Chars.t())) :: String.t()
        when val: value
  def map_join(enumerable, joiner \\ "", mapper)
      when is_binary(joiner) and is_function(mapper, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil ->
        Enum.map_join(enumerable, joiner, mapper)

      list when is_list(list) ->
        Enum.map_join(list, joiner, mapper)

      # TODO do this in one pass
      vector ->
        vector
        |> RawVector.map(mapper)
        |> RawVector.join_as_iodata(joiner)
        |> IO.iodata_to_binary()
    end
  end

  @doc """
  Intersperses `separator` between each element of the given `enumerable`.

  Mirrors `Enum.intersperse/2` with higher performance for Aja structures.
  """
  @spec intersperse(t(val), separator) :: [val | separator] when val: value, separator: value
  def intersperse(enumerable, separator) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.intersperse(enumerable, separator)
      list when is_list(list) -> Enum.intersperse(list, separator)
      vector -> RawVector.intersperse_to_list(vector, separator)
    end
  end

  @doc """
  Maps and intersperses the given `enumerable` in one pass.

  Mirrors `Enum.map_intersperse/3` with higher performance for Aja structures.
  """
  @spec map_intersperse(t(val), separator, (val -> mapped_val)) :: [mapped_val | separator]
        when val: value, separator: value, mapped_val: value
  def map_intersperse(enumerable, separator, mapper)
      when is_function(mapper, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.map_intersperse(enumerable, separator, mapper)
      list when is_list(list) -> Enum.map_intersperse(list, separator, mapper)
      vector -> RawVector.map_intersperse_to_list(vector, separator, mapper)
    end
  end

  @doc """
  Maps the given `fun` over `enumerable` and flattens the result.

  Mirrors `Enum.flat_map/2` with higher performance for Aja structures.
  """
  @spec flat_map(t(val), (val -> t(mapped_val))) :: [mapped_val]
        when val: value, mapped_val: value
  defdelegate flat_map(enumerable, fun), to: H

  @doc """
  Returns a map with keys as unique elements of `enumerable` and values
  as the count of every element.

  Mirrors `Enum.frequencies/1` with higher performance for Aja structures.
  """
  @spec frequencies(t(val)) :: %{optional(val) => non_neg_integer} when val: value
  def frequencies(enumerable) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.frequencies(enumerable)
      list when is_list(list) -> Enum.frequencies(list)
      vector -> RawVector.frequencies(vector)
    end
  end

  @doc """
  Returns a map with keys as unique elements given by `key_fun` and values
  as the count of every element.

  Mirrors `Enum.frequencies_by/2` with higher performance for Aja structures.
  """
  @spec frequencies_by(t(val), (val -> key)) :: %{optional(key) => non_neg_integer}
        when val: value, key: any
  def frequencies_by(enumerable, key_fun) when is_function(key_fun, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.frequencies_by(enumerable, key_fun)
      list when is_list(list) -> Enum.frequencies_by(list, key_fun)
      vector -> RawVector.frequencies_by(vector, key_fun)
    end
  end

  @doc """
  Splits the `enumerable` into groups based on `key_fun`.

  Mirrors `Enum.group_by/3` with higher performance for Aja structures.
  """
  @spec group_by(t(val), (val -> key), (val -> mapped_val)) :: %{optional(key) => [mapped_val]}
        when val: value, key: any, mapped_val: any
  def group_by(enumerable, key_fun, value_fun \\ fn x -> x end)
      when is_function(key_fun, 1) and is_function(value_fun, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.group_by(enumerable, key_fun, value_fun)
      list when is_list(list) -> Enum.group_by(list, key_fun, value_fun)
      vector -> RawVector.group_by(vector, key_fun, value_fun)
    end
  end

  @doc """
  Invokes the given `fun` for each element in the `enumerable`.

  Mirrors `Enum.each/2` with higher performance for Aja structures.
  """
  @spec each(t(val), (val -> term)) :: :ok when val: value
  def each(enumerable, fun) when is_function(fun, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.each(enumerable, fun)
      list when is_list(list) -> :lists.foreach(fun, list)
      vector -> RawVector.each(vector, fun)
    end
  end

  ## RANDOM

  @doc """
  Returns a random element of an `enumerable`.

  Mirrors `Enum.random/1` with higher performance for Aja structures.
  """
  @spec random(t(val)) :: val when val: value
  def random(enumerable) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.random(enumerable)
      list when is_list(list) -> Enum.random(list)
      vector -> RawVector.random(vector)
    end
  end

  @doc """
  Takes `count` random elements from `enumerable`.

  Mirrors `Enum.take_random/2` with higher performance for Aja structures.
  """
  @spec take_random(t(val), non_neg_integer) :: [val] when val: value
  def take_random(enumerable, count)
  def take_random(_enumerable, 0), do: []

  # TODO: optimize 1 for non-empty vectors

  def take_random(enumerable, count) do
    enumerable
    |> H.to_list()
    |> Enum.take_random(count)
  end

  @doc """
  Returns a list with the elements of `enumerable` shuffled.

  Mirrors `Enum.shuffle/1` with higher performance for Aja structures.
  """
  @spec shuffle(t(val)) :: [val] when val: value
  def shuffle(enumerable) do
    enumerable
    |> H.to_list()
    |> Enum.shuffle()
  end

  # UNIQ

  @doc """
  Enumerates the `enumerable`, returning a list where all consecutive
  duplicated elements are collapsed to a single element.

  Mirrors `Enum.dedup/1` with higher performance for Aja structures.
  """
  @spec dedup(t(val)) :: [val] when val: value
  def dedup(enumerable)

  def dedup(%MapSet{} = set) do
    MapSet.to_list(set)
  end

  def dedup(enumerable) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.dedup(enumerable)
      list when is_list(list) -> dedup_list(list)
      vector -> RawVector.dedup_list(vector)
    end
  end

  @doc """
  Enumerates the `enumerable`, returning a list where all consecutive
  duplicated elements are collapsed to a single element.

  Mirrors `Enum.dedup_by/2` with higher performance for Aja structures.
  """
  @spec dedup_by(t(val), (val -> term)) :: [val] when val: value
  def dedup_by(enumerable, fun) when is_function(fun, 1) do
    enumerable
    |> H.to_list()
    |> Enum.dedup_by(fun)
  end

  @doc """
  Enumerates the `enumerable`, removing all duplicated elements.

  Mirrors `Enum.uniq/1` with higher performance for Aja structures.
  """
  @spec uniq(t(val)) :: [val] when val: value
  def uniq(enumerable)

  def uniq(%MapSet{} = set) do
    MapSet.to_list(set)
  end

  def uniq(enumerable) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.uniq(enumerable)
      list when is_list(list) -> Enum.uniq(list)
      vector -> RawVector.uniq_list(vector)
    end
  end

  @doc """
  Enumerates the `enumerable`, by removing the elements for which
  function `fun` returned duplicate elements.

  Mirrors `Enum.uniq_by/2` with higher performance for Aja structures.
  """
  @spec uniq_by(t(val), (val -> term)) :: [val] when val: value
  def uniq_by(enumerable, fun) when is_function(fun, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.uniq_by(enumerable, fun)
      list when is_list(list) -> Enum.uniq_by(list, fun)
      vector -> RawVector.uniq_by_list(vector, fun)
    end
  end

  # ## MIN-MAX

  defguardp is_list_or_struct(enumerable)
            when is_list(enumerable) or :erlang.map_get(:__struct__, enumerable) |> is_atom()

  defguardp is_empty_list_or_vec(list_or_vec)
            when list_or_vec === [] or list_or_vec === @empty_vector

  @doc false
  def min(enumerable) when is_list_or_struct(enumerable) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.min(enumerable)
      empty when is_empty_list_or_vec(empty) -> raise Enum.EmptyError
      list when is_list(list) -> :lists.min(list)
      vector -> RawVector.min(vector)
    end
  end

  @doc false
  @spec min(t(val), (() -> empty_result)) :: val | empty_result when val: value, empty_result: any
  def min(enumerable, empty_fallback) when is_function(empty_fallback, 0) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.min(enumerable, empty_fallback)
      empty when is_empty_list_or_vec(empty) -> empty_fallback.()
      list when is_list(list) -> :lists.min(list)
      vector -> RawVector.min(vector)
    end
  end

  @doc """
  Returns the minimal element in the `enumerable` according
  to Erlang's term ordering.

  Mirrors `Enum.min/3` with higher performance for Aja structures.
  """
  @spec min(t(val), (val, val -> boolean) | module, (() -> empty_result)) :: val | empty_result
        when val: value, empty_result: any
  def min(enumerable, sorter \\ &<=/2, empty_fallback \\ fn -> raise Enum.EmptyError end)
      when is_function(empty_fallback, 0) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.min(enumerable, sorter, empty_fallback)
      @empty_vector -> empty_fallback.()
      list when is_list(list) -> Enum.min(list, sorter, empty_fallback)
      vector -> RawVector.custom_min_max(vector, min_sort_fun(sorter))
    end
  end

  @doc false
  def max(enumerable) when is_list_or_struct(enumerable) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.max(enumerable)
      empty when is_empty_list_or_vec(empty) -> raise Enum.EmptyError
      list when is_list(list) -> :lists.max(list)
      vector -> RawVector.max(vector)
    end
  end

  @doc false
  @spec max(t(val), (() -> empty_result)) :: val | empty_result when val: value, empty_result: any
  def max(enumerable, empty_fallback) when is_function(empty_fallback, 0) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.max(enumerable, empty_fallback)
      empty when is_empty_list_or_vec(empty) -> empty_fallback.()
      list when is_list(list) -> :lists.max(list)
      vector -> RawVector.max(vector)
    end
  end

  @doc """
  Returns the maximal element in the `enumerable` according
  to Erlang's term ordering.

  Mirrors `Enum.max/3` with higher performance for Aja structures.
  """
  @spec max(t(val), (val, val -> boolean) | module, (() -> empty_result)) :: val | empty_result
        when val: value, empty_result: any
  def max(enumerable, sorter \\ &>=/2, empty_fallback \\ fn -> raise Enum.EmptyError end)
      when is_function(empty_fallback, 0) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.max(enumerable, sorter, empty_fallback)
      @empty_vector -> empty_fallback.()
      list when is_list(list) -> Enum.max(list, sorter, empty_fallback)
      vector -> RawVector.custom_min_max(vector, max_sort_fun(sorter))
    end
  end

  @doc false
  def min_by(enumerable, fun, empty_fallback)
      when is_function(fun, 1) and is_function(empty_fallback, 0) do
    min_by(enumerable, fun, &<=/2, empty_fallback)
  end

  @doc """
  Returns the minimal element in the `enumerable` as calculated
  by the given `fun`.

  Mirrors `Enum.min_by/4` with higher performance for Aja structures.
  """
  @spec min_by(t(val), (val -> key), (key, key -> boolean) | module, (() -> empty_result)) ::
          val | empty_result
        when val: value, key: term, empty_result: any
  def min_by(enumerable, fun, sorter \\ &<=/2, empty_fallback \\ fn -> raise Enum.EmptyError end)
      when is_function(fun, 1) and is_function(empty_fallback, 0) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.min_by(enumerable, fun, sorter, empty_fallback)
      list when is_list(list) -> Enum.min_by(list, fun, sorter, empty_fallback)
      @empty_vector -> empty_fallback.()
      vector -> RawVector.custom_min_max_by(vector, fun, min_sort_fun(sorter))
    end
  end

  @doc false
  def max_by(enumerable, fun, empty_fallback)
      when is_function(fun, 1) and is_function(empty_fallback, 0) do
    max_by(enumerable, fun, &>=/2, empty_fallback)
  end

  @doc """
  Returns the maximal element in the `enumerable` as calculated
  by the given `fun`.

  Mirrors `Enum.max_by/4` with higher performance for Aja structures.
  """
  @spec max_by(t(val), (val -> key), (key, key -> boolean) | module, (() -> empty_result)) ::
          val | empty_result
        when val: value, key: term, empty_result: any
  def max_by(enumerable, fun, sorter \\ &>=/2, empty_fallback \\ fn -> raise Enum.EmptyError end)
      when is_function(fun, 1) and is_function(empty_fallback, 0) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.max_by(enumerable, fun, sorter, empty_fallback)
      list when is_list(list) -> Enum.max_by(list, fun, sorter, empty_fallback)
      @empty_vector -> empty_fallback.()
      vector -> RawVector.custom_min_max_by(vector, fun, max_sort_fun(sorter))
    end
  end

  defp max_sort_fun(sorter) when is_function(sorter, 2), do: sorter
  defp max_sort_fun(module) when is_atom(module), do: &(module.compare(&1, &2) != :lt)

  defp min_sort_fun(sorter) when is_function(sorter, 2), do: sorter
  defp min_sort_fun(module) when is_atom(module), do: &(module.compare(&1, &2) != :gt)

  ## MAP-REDUCE

  @doc ~S"""
  Returns a list with with each element of `enumerable` wrapped in a tuple alongside its index.

  Mirrors `Enum.with_index/2`: may receive a function or an integer offset.

  If an integer `offset` is given, it will index from the given `offset` instead of from zero.

  If a `function` is given, it will index by invoking the function for each
  element and index (zero-based) of the `enumerable`.

  ## Examples

      iex> Aja.Enum.with_index([:a, :b, :c])
      [a: 0, b: 1, c: 2]

      iex> Aja.Enum.with_index([:a, :b, :c], 3)
      [a: 3, b: 4, c: 5]

      iex> Aja.Enum.with_index([:a, :b, :c], fn element, index -> {index, element} end)
      [{0, :a}, {1, :b}, {2, :c}]

  """
  @spec with_index(t(val), index) :: [{val, index}] when val: value
  @spec with_index(t(val), (val, index -> mapped_val)) :: [mapped_val]
        when val: value, mapped_val: value
  def with_index(enumerable, offset_or_fun \\ 0)

  def with_index(enumerable, offset) when is_integer(offset) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.with_index(enumerable, offset)
      list when is_list(list) -> with_index_list_offset(list, offset, [])
      vector -> RawVector.with_index(vector, offset) |> RawVector.to_list()
    end
  end

  def with_index(enumerable, fun) when is_function(fun, 2) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil ->
        enumerable
        |> Enum.map_reduce(0, fn x, i -> {fun.(x, i), i + 1} end)
        |> elem(0)

      list when is_list(list) ->
        with_index_list_fun(list, 0, fun, [])

      vector ->
        RawVector.with_index(vector, 0, fun) |> RawVector.to_list()
    end
  end

  defp with_index_list_offset([], _offset, acc), do: :lists.reverse(acc)

  defp with_index_list_offset([head | tail], offset, acc) do
    with_index_list_offset(tail, offset + 1, [{head, offset} | acc])
  end

  defp with_index_list_fun([], _offset, _fun, acc), do: :lists.reverse(acc)

  defp with_index_list_fun([head | tail], offset, fun, acc) do
    with_index_list_fun(tail, offset + 1, fun, [fun.(head, offset) | acc])
  end

  @doc """
  Invokes the given function to each element in the `enumerable` to reduce
  it to a single element, while keeping an accumulator.

  Mirrors `Enum.map_reduce/3` with higher performance for Aja structures.
  """
  @spec map_reduce(t(val), acc, (val, acc -> {mapped_val, acc})) :: {t(mapped_val), acc}
        when val: value, mapped_val: value, acc: any
  def map_reduce(enumerable, acc, fun) when is_function(fun, 2) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil ->
        Enum.map_reduce(enumerable, acc, fun)

      list when is_list(list) ->
        :lists.mapfoldl(fun, acc, list)

      vector ->
        {new_vector, new_acc} = RawVector.map_reduce(vector, acc, fun)
        {RawVector.to_list(new_vector), new_acc}
    end
  end

  @doc """
  Applies the given function to each element in the `enumerable`,
  storing the result in a list and passing it as the accumulator
  for the next computation. Uses the first element in the `enumerable`
  as the starting value.

  Mirrors `Enum.scan/2` with higher performance for Aja structures.
  """
  @spec scan(t(val), (val, val -> val)) :: val when val: value
  def scan(enumerable, fun) when is_function(fun, 2) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.scan(enumerable, fun)
      list when is_list(list) -> Enum.scan(list, fun)
      vector -> RawVector.scan(vector, fun) |> RawVector.to_list()
    end
  end

  @doc """
  Applies the given function to each element in the `enumerable`,
  storing the result in a list and passing it as the accumulator
  for the next computation. Uses the given `acc` as the starting value.

  Mirrors `Enum.scan/3` with higher performance for Aja structures.
  """
  @spec scan(t(val), acc, (val, acc -> acc)) :: acc when val: value, acc: term
  def scan(enumerable, acc, fun) when is_function(fun, 2) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.scan(enumerable, acc, fun)
      list when is_list(list) -> Enum.scan(list, acc, fun)
      vector -> RawVector.scan(vector, acc, fun) |> RawVector.to_list()
    end
  end

  ## SLICING

  @doc """
  Takes an `amount` of elements from the beginning or the end of the `enumerable`.

  Mirrors `Enum.take/2` with higher performance for Aja structures.
  """
  @spec take(t(val), integer) :: [val] when val: value
  def take(enumerable, amount) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.take(enumerable, amount)
      list when is_list(list) -> Enum.take(list, amount)
      vector -> do_take_vector(vector, amount)
    end
  end

  defp do_take_vector(_vector, 0), do: []

  defp do_take_vector(vector, amount) when amount > 0 do
    size = RawVector.size(vector)

    if amount < size do
      RawVector.slice(vector, 0, amount - 1)
    else
      RawVector.to_list(vector)
    end
  end

  defp do_take_vector(vector, amount) do
    size = RawVector.size(vector)
    start = amount + size

    if start > 0 do
      RawVector.slice(vector, start, size - 1)
    else
      RawVector.to_list(vector)
    end
  end

  @doc """
  Drops the `amount` of elements from the `enumerable`.

  Mirrors `Enum.drop/2` with higher performance for Aja structures.
  """
  @spec drop(t(val), integer) :: [val] when val: value
  def drop(enumerable, amount) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.drop(enumerable, amount)
      list when is_list(list) -> Enum.drop(list, amount)
      vector -> do_drop_vector(vector, amount)
    end
  end

  defp do_drop_vector(vector, 0), do: RawVector.to_list(vector)

  defp do_drop_vector(vector, amount) when amount > 0 do
    size = RawVector.size(vector)

    if amount < size do
      RawVector.slice(vector, amount, size - 1)
    else
      []
    end
  end

  defp do_drop_vector(vector, amount) do
    size = RawVector.size(vector)
    last = amount + size

    if last > 0 do
      RawVector.slice(vector, 0, last - 1)
    else
      []
    end
  end

  @doc """
  Splits the `enumerable` into two enumerables, leaving `count` elements in the first one.

  Mirrors `Enum.split/2` with higher performance for Aja structures.
  """
  @spec split(t(val), integer) :: {[val], [val]} when val: value
  def split(enumerable, amount) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil ->
        Enum.split(enumerable, amount)

      list when is_list(list) ->
        Enum.split(list, amount)

      vector ->
        if amount >= 0 do
          {do_take_vector(vector, amount), do_drop_vector(vector, amount)}
        else
          {do_drop_vector(vector, amount), do_take_vector(vector, amount)}
        end
    end
  end

  @doc """
  Takes the elements from the beginning of the `enumerable` while `fun` returns a truthy value.

  Mirrors `Enum.take_while/2` with higher performance for Aja structures.
  """
  @spec take_while(t(val), (val -> as_boolean(term()))) :: [val] when val: value
  def take_while(enumerable, fun) when is_function(fun, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil ->
        Enum.take_while(enumerable, fun)

      list when is_list(list) ->
        Enum.take_while(list, fun)

      vector ->
        case RawVector.find_falsy_index(vector, fun) do
          nil -> RawVector.to_list(vector)
          index -> do_take_vector(vector, index)
        end
    end
  end

  @doc """
  Drops elements at the beginning of the `enumerable` while `fun` returns a truthy value.

  Mirrors `Enum.drop_while/2` with higher performance for Aja structures.
  """
  @spec drop_while(t(val), (val -> as_boolean(term()))) :: [val] when val: value
  def drop_while(enumerable, fun) when is_function(fun, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil ->
        Enum.drop_while(enumerable, fun)

      list when is_list(list) ->
        Enum.drop_while(list, fun)

      vector ->
        case RawVector.find_falsy_index(vector, fun) do
          nil -> []
          index -> do_drop_vector(vector, index)
        end
    end
  end

  @doc """
  Splits `enumerable` in two at the position of the element for which `fun` returns a falsy value
  (`false` or `nil`) for the first time.

  Mirrors `Enum.split_while/2` with higher performance for Aja structures.
  """
  @spec split_while(t(val), (val -> as_boolean(term()))) :: {[val], [val]} when val: value
  def split_while(enumerable, fun) when is_function(fun, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil ->
        Enum.split_while(enumerable, fun)

      list when is_list(list) ->
        Enum.split_while(list, fun)

      vector ->
        case RawVector.find_falsy_index(vector, fun) do
          nil -> {RawVector.to_list(vector), []}
          index -> {do_take_vector(vector, index), do_drop_vector(vector, index)}
        end
    end
  end

  ## SORT

  @doc """
  Sorts the `enumerable` according to Erlang's term ordering.

  Mirrors `Enum.sort/1` with higher performance for Aja structures.
  """
  @spec sort(t(val)) :: [val] when val: value
  def sort(enumerable) do
    enumerable
    |> H.to_list()
    |> Enum.sort()
  end

  @doc """
  Sorts the `enumerable` by the given function.

  Mirrors `Enum.sort/2` with higher performance for Aja structures.
  """
  @spec sort(
          t(val),
          (val, val -> boolean)
          | :asc
          | :desc
          | module
          | {:asc | :desc, module}
        ) :: [val]
        when val: value
  def sort(enumerable, fun) do
    enumerable
    |> H.to_list()
    |> Enum.sort(fun)
  end

  @doc """
  Sorts the mapped results of the `enumerable` according to the provided `sorter`
  function.

  Mirrors `Enum.sort_by/3` with higher performance for Aja structures.
  """
  @spec sort_by(
          t(val),
          (val -> mapped_val),
          (val, val -> boolean)
          | :asc
          | :desc
          | module
          | {:asc | :desc, module}
        ) :: [val]
        when val: value, mapped_val: value
  def sort_by(enumerable, mapper, sorter \\ &<=/2) do
    enumerable
    |> H.to_list()
    |> Enum.sort_by(mapper, sorter)
  end

  @doc """
  Zips corresponding elements from two enumerables into one list of tuples.

  Mirrors `Enum.zip/2` with higher performance for Aja structures.
  """
  @spec zip(t(val1), t(val2)) :: list({val1, val2}) when val1: value, val2: value
  def zip(enumerable1, enumerable2) do
    case {H.try_get_raw_vec_or_list(enumerable1), H.try_get_raw_vec_or_list(enumerable2)} do
      {vector1, vector2} when is_tuple(vector1) and is_tuple(vector2) ->
        RawVector.zip(vector1, vector2) |> RawVector.to_list()

      {list1, list2} when is_list(list1) and is_list(list2) ->
        zip_lists(list1, list2, [])

      {result1, result2} ->
        list_or_enum1 = zip_try_get_list(result1, enumerable1)
        list_or_enum2 = zip_try_get_list(result2, enumerable2)
        Enum.zip(list_or_enum1, list_or_enum2)
    end
  end

  defp zip_try_get_list(list, _enumerable) when is_list(list), do: list
  defp zip_try_get_list(nil, enumerable), do: enumerable
  defp zip_try_get_list(vector, _enumerable), do: RawVector.to_list(vector)

  defp zip_lists(list1, list2, acc) when list1 == [] or list2 == [] do
    :lists.reverse(acc)
  end

  defp zip_lists([head1 | tail1], [head2 | tail2], acc) do
    zip_lists(tail1, tail2, [{head1, head2} | acc])
  end

  @doc """
  Opposite of `zip/2`. Extracts two-element tuples from the given `enumerable`
  and groups them together.

  Mirrors `Enum.unzip/1` with higher performance for Aja structures.
  """
  @spec unzip(t({val1, val2})) :: {list(val1), list(val2)} when val1: value, val2: value
  def unzip(enumerable) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil ->
        Enum.unzip(enumerable)

      list when is_list(list) ->
        Enum.unzip(list)

      vector ->
        {vector1, vector2} = RawVector.unzip(vector)
        {RawVector.to_list(vector1), RawVector.to_list(vector2)}
    end
  end

  # Private functions

  defp dedup_list([]), do: []
  defp dedup_list([elem, elem | rest]), do: dedup_list([elem | rest])
  defp dedup_list([elem | rest]), do: [elem | dedup_list(rest)]
end
