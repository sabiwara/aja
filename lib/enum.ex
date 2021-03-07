defmodule A.Enum do
  @moduledoc ~S"""
  Drop-in replacement for the `Enum` module, optimized to work with Aja's data structures such as `A.Vector`.

  It currently only covers a subset of `Enum`, but `A.Enum` aims to completely mirror the API of `Enum`,
  and should behave exactly the same for any type of `Enumerable`.
  The only expected difference should be a significant increase in performance for Aja structures.

  ## Rationale

  Structures such as `A.Vector` or `A.OrdMap` are implementing the `Enumerable` protocol, which means they can be
  used directly with the `Enum` module. The `Enumerable` protocol however comes with its overhead and is strongly
  limited in terms of performance.

  On the other hand, `A.Enum` provides hand-crafted highly-optimized functions that fully take advantage of
  immutable vectors. The speedup can easily reach more than a factor 10 compared to the `Enum` used for non-list
  structures, and sometimes even be noticeably faster than `Enum` used over lists.

  One of the main reasons to adopt a specific data structure is the performance.
  Using vectors with `Enum` would defeat the purpose.
  The `A.Enum` module has been introduced for this.

      vector = A.Vector.new(1..10000)

      Enum.sum(vector)
      # warning: Enum has sub-optimal performance for A.Vector, use A.Enum (see https://hexdocs.pm/aja/A.Enum.html)
      50005000

      A.Enum.sum(vector)  # same result, much faster
      50005000

  """

  alias A.Vector.Raw, as: RawVector
  alias A.EnumHelper, as: H

  require RawVector

  @dialyzer :no_opaque

  @type index :: integer
  @type value :: any
  @type t(value) :: A.Vector.t(value) | [value] | Enumerable.t()

  @empty_vector RawVector.empty()

  copy_doc_for = fn fun_name, arity ->
    Code.fetch_docs(Enum)
    |> elem(6)
    |> Enum.find_value(fn
      {{:function, ^fun_name, ^arity}, _, _, %{"en" => text}, _} -> text
      _ -> nil
    end)
    |> String.replace("Enum.", "A.Enum.")
  end

  # defmacrop def_mirror(call, header) do
  # end

  @doc copy_doc_for.(:to_list, 1)
  @spec to_list(t(val)) :: [val] when val: value
  defdelegate to_list(enumerable), to: H

  @doc copy_doc_for.(:count, 1)
  @spec count(t(any)) :: non_neg_integer
  defdelegate count(enumerable), to: Enum

  @doc copy_doc_for.(:member?, 2)
  @spec member?(t(val), val) :: boolean when val: value
  defdelegate member?(enumerable, value), to: Enum

  @doc copy_doc_for.(:slice, 2)
  @spec slice(t(val), Range.t()) :: [val] when val: value
  defdelegate slice(enumerable, index_range), to: Enum

  @doc copy_doc_for.(:slice, 3)
  @spec slice(t(val), index, non_neg_integer) :: [val] when val: value
  defdelegate slice(enumerable, start_index, amount), to: Enum

  @doc copy_doc_for.(:into, 2)
  @spec into(t(val), Collectable.t()) :: Collectable.t() when val: value
  def into(enumerable, %A.Vector{} = vector) do
    A.Vector.concat(vector, enumerable)
  end

  def into(enumerable, %A.OrdMap{} = ord_map) do
    A.OrdMap.merge_list(ord_map, H.to_list(enumerable))
  end

  def into(enumerable, collectable) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.into(enumerable, collectable)
      list when is_list(list) -> Enum.into(list, collectable)
      vector -> RawVector.to_list(vector) |> Enum.into(collectable)
    end
  end

  @doc copy_doc_for.(:at, 3)
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

  @doc copy_doc_for.(:reverse, 1)
  @spec reverse(t(val)) :: [val] when val: value
  def reverse(enumerable) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.reverse(enumerable)
      list when is_list(list) -> :lists.reverse(list)
      vector -> RawVector.reverse_to_list(vector)
    end
  end

  @doc copy_doc_for.(:map, 2)
  @spec map(t(v1), (v1 -> v2)) :: [v2] when v1: value, v2: value
  defdelegate map(enumerable, fun), to: H

  @doc copy_doc_for.(:filter, 2)
  @spec filter(t(val), (val -> boolean)) :: [val] when val: value
  def filter(enumerable, fun) when is_function(fun, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.filter(enumerable, fun)
      list when is_list(list) -> Enum.filter(list, fun)
      vector -> RawVector.filter_to_list(vector, fun)
    end
  end

  @doc copy_doc_for.(:reject, 2)
  @spec reject(t(val), (val -> boolean)) :: [val] when val: value
  def reject(enumerable, fun) when is_function(fun, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.reject(enumerable, fun)
      list when is_list(list) -> Enum.reject(list, fun)
      vector -> RawVector.reject_to_list(vector, fun)
    end
  end

  @doc copy_doc_for.(:reduce, 2)
  @spec reduce(t(val), (val, val -> val)) :: val when val: value
  def reduce(enumerable, fun) when is_function(fun, 2) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.reduce(enumerable, fun)
      list when is_list(list) -> Enum.reduce(list, fun)
      vector -> RawVector.reduce(vector, fun)
    end
  end

  @doc copy_doc_for.(:reduce, 3)
  @spec reduce(t(val), acc, (val, acc -> acc)) :: acc when val: value, acc: term
  def reduce(enumerable, acc, fun) when is_function(fun, 2) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.reduce(enumerable, acc, fun)
      list when is_list(list) -> Enum.reduce(list, acc, fun)
      vector -> RawVector.foldl(vector, acc, fun)
    end
  end

  # FINDS

  @doc """
  Returns `true` if at least one element in `enumerable` is truthy.

  When an element has a truthy value (neither `false` nor `nil`) iteration stops
  immediately and `true` is returned. In all other cases `false` is returned.

  ## Examples

      iex> A.Enum.any?([false, false, false])
      false

      iex> A.Enum.any?([false, true, false])
      true

      iex> A.Enum.any?([])
      false

  """
  @spec any?(t(as_boolean(val))) :: boolean when val: value
  def any?(enumerable) do
    case enumerable do
      %A.Vector{__vector__: vector} -> RawVector.any?(vector)
      _ -> Enum.any?(enumerable)
    end
  end

  @doc """
  Returns `true` if `fun.(element)` is truthy for at least one element in `enumerable`.

  Iterates over the `enumerable` and invokes `fun` on each element. When an invocation
  of `fun` returns a truthy value (neither `false` nor `nil`) iteration stops
  immediately and `true` is returned. In all other cases `false` is returned.

  ## Examples

      iex> A.Enum.any?([2, 4, 6], fn x -> rem(x, 2) == 1 end)
      false

      iex> A.Enum.any?([2, 3, 4], fn x -> rem(x, 2) == 1 end)
      true

      iex> A.Enum.any?([], fn x -> x > 0 end)
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

      iex> A.Enum.all?([1, 2, 3])
      true

      iex> A.Enum.all?([1, nil, 3])
      false

      iex> A.Enum.all?([])
      true

  """
  @spec all?(t(as_boolean(val))) :: boolean when val: value
  def all?(enumerable) do
    case enumerable do
      %A.Vector{__vector__: vector} -> RawVector.all?(vector)
      _ -> Enum.all?(enumerable)
    end
  end

  @doc """
  Returns `true` if `fun.(element)` is truthy for all elements in `enumerable`.

  Iterates over `enumerable` and invokes `fun` on each element. If `fun` ever
  returns a falsy value (`false` or `nil`), iteration stops immediately and
  `false` is returned. Otherwise, `true` is returned.

  ## Examples

      iex> A.Enum.all?([2, 4, 6], fn x -> rem(x, 2) == 0 end)
      true

      iex> A.Enum.all?([2, 3, 4], fn x -> rem(x, 2) == 0 end)
      false

      iex> A.Enum.all?([], fn _ -> nil end)
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

  @doc copy_doc_for.(:find, 3)
  @spec find(t(val), default, (val -> as_boolean(term))) :: val | default
        when val: value, default: value
  def find(enumerable, default \\ nil, fun) when is_function(fun, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.find(enumerable, default, fun)
      list when is_list(list) -> Enum.find(list, default, fun)
      vector -> RawVector.find(vector, default, fun)
    end
  end

  @doc copy_doc_for.(:find_value, 3)
  @spec find_value(t(val), default, (val -> new_val)) :: new_val | default
        when val: value, new_val: value, default: value
  def find_value(enumerable, default \\ nil, fun) when is_function(fun, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.find_value(enumerable, default, fun)
      list when is_list(list) -> Enum.find_value(list, default, fun)
      vector -> RawVector.find_value(vector, fun) || default
    end
  end

  @doc copy_doc_for.(:find_index, 2)
  @spec find_index(t(val), (val -> as_boolean(term))) :: non_neg_integer | nil when val: value
  def find_index(enumerable, fun) when is_function(fun, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.find_index(enumerable, fun)
      list when is_list(list) -> Enum.find_index(list, fun)
      vector -> RawVector.find_index(vector, fun)
    end
  end

  ## FOLDS

  @doc copy_doc_for.(:sum, 1)
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

  Raises `ArithmeticError` if `enumerable` contains a non-numeric value.

  ## Examples

      iex> 1..5 |> A.Enum.product()
      120
      iex> [] |> A.Enum.product()
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

  @doc copy_doc_for.(:join, 2)
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

  @doc copy_doc_for.(:map_join, 3)
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

  @doc copy_doc_for.(:intersperse, 2)
  @spec intersperse(t(val), separator) :: [val | separator] when val: value, separator: value
  def intersperse(enumerable, separator) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.intersperse(enumerable, separator)
      list when is_list(list) -> Enum.intersperse(list, separator)
      vector -> RawVector.intersperse_to_list(vector, separator)
    end
  end

  @doc copy_doc_for.(:map_intersperse, 3)
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

  @doc copy_doc_for.(:frequencies, 1)
  @spec frequencies(t(val)) :: %{optional(val) => non_neg_integer} when val: value
  def frequencies(enumerable) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.frequencies(enumerable)
      list when is_list(list) -> Enum.frequencies(list)
      vector -> RawVector.frequencies(vector)
    end
  end

  @doc copy_doc_for.(:frequencies_by, 2)
  @spec frequencies_by(t(val), (val -> key)) :: %{optional(key) => non_neg_integer}
        when val: value, key: any
  def frequencies_by(enumerable, key_fun) when is_function(key_fun, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.frequencies_by(enumerable, key_fun)
      list when is_list(list) -> Enum.frequencies_by(list, key_fun)
      vector -> RawVector.frequencies_by(vector, key_fun)
    end
  end

  @doc copy_doc_for.(:group_by, 3)
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

  @doc copy_doc_for.(:each, 2)
  @spec each(t(val), (val -> term)) :: :ok when val: value
  def each(enumerable, fun) when is_function(fun, 1) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.each(enumerable, fun)
      list when is_list(list) -> Enum.each(list, fun)
      vector -> RawVector.each(vector, fun)
    end
  end

  ## RANDOM

  @doc copy_doc_for.(:random, 1)
  @spec random(t(val)) :: val when val: value
  def random(enumerable) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.random(enumerable)
      list when is_list(list) -> Enum.random(list)
      vector -> RawVector.random(vector)
    end
  end

  @doc copy_doc_for.(:take_random, 2)
  @spec take_random(t(val), non_neg_integer) :: [val] when val: value
  def take_random(enumerable, count)
  def take_random(_enumerable, 0), do: []

  # TODO: optimize 1 for non-empty vectors

  def take_random(enumerable, count) do
    enumerable
    |> H.to_list()
    |> Enum.take_random(count)
  end

  @doc copy_doc_for.(:shuffle, 1)
  @spec shuffle(t(val)) :: [val] when val: value
  def shuffle(enumerable) do
    enumerable
    |> H.to_list()
    |> Enum.shuffle()
  end

  # UNIQ

  @doc copy_doc_for.(:dedup, 1)
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

  @doc copy_doc_for.(:dedup_by, 2)
  @spec dedup_by(t(val), (val -> term)) :: [val] when val: value
  def dedup_by(enumerable, fun) when is_function(fun, 1) do
    enumerable
    |> H.to_list()
    |> Enum.dedup_by(fun)
  end

  @doc copy_doc_for.(:uniq, 1)
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

  @doc copy_doc_for.(:uniq_by, 2)
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
  def max(enumerable) when is_list_or_struct(enumerable) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.max(enumerable)
      empty when is_empty_list_or_vec(empty) -> raise Enum.EmptyError
      list when is_list(list) -> :lists.max(list)
      vector -> RawVector.max(vector)
    end
  end

  @doc false
  def max(enumerable, empty_fallback)
      when is_list_or_struct(enumerable) and is_function(empty_fallback, 0) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.max(enumerable, empty_fallback)
      empty when is_empty_list_or_vec(empty) -> empty_fallback.()
      list when is_list(list) -> :lists.max(list)
      vector -> RawVector.max(vector)
    end
  end

  @doc false
  @spec max(t(val), (() -> empty_result)) :: val | empty_result when val: value, empty_result: any
  def max(enumerable, empty_fallback) when is_function(empty_fallback, 0) do
    max(enumerable, &>=/2, empty_fallback)
  end

  @doc copy_doc_for.(:max, 3)
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
  def min(enumerable) when is_list_or_struct(enumerable) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.min(enumerable)
      empty when is_empty_list_or_vec(empty) -> raise Enum.EmptyError
      list when is_list(list) -> :lists.min(list)
      vector -> RawVector.min(vector)
    end
  end

  @doc false
  def min(enumerable, empty_fallback)
      when is_list_or_struct(enumerable) and is_function(empty_fallback, 0) do
    case H.try_get_raw_vec_or_list(enumerable) do
      nil -> Enum.min(enumerable, empty_fallback)
      empty when is_empty_list_or_vec(empty) -> empty_fallback.()
      list when is_list(list) -> :lists.min(list)
      vector -> RawVector.min(vector)
    end
  end

  @doc false
  @spec min(t(val), (() -> empty_result)) :: val | empty_result when val: value, empty_result: any
  def min(enumerable, empty_fallback) when is_function(empty_fallback, 0) do
    min(enumerable, &>=/2, empty_fallback)
  end

  @doc copy_doc_for.(:min, 3)
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
  def min_by(enumerable, fun, empty_fallback)
      when is_function(fun, 1) and is_function(empty_fallback, 0) do
    min_by(enumerable, fun, &<=/2, empty_fallback)
  end

  @doc copy_doc_for.(:min_by, 4)
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

  @doc copy_doc_for.(:max_by, 4)
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

  ## SORT

  @doc copy_doc_for.(:sort, 1)
  @spec sort(t(val)) :: [val] when val: value
  def sort(enumerable) do
    enumerable
    |> H.to_list()
    |> Enum.sort()
  end

  @doc copy_doc_for.(:sort, 2)
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

  @doc copy_doc_for.(:sort_by, 3)
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

  ## Extra functions

  @doc """
  Sorts the `enumerable` and removes duplicates.

  It is more efficient than calling `Enum.sort/1` followed by `Enum.uniq/1`,
  and slightly faster than `Enum.sort/1` followed by `Enum.dedup/1`.

  ## Examples

      iex> A.Enum.sort_uniq([1, 4, 2, 2, 3, 1, 4, 3])
      [1, 2, 3, 4]

  """
  def sort_uniq(enumerable) do
    enumerable
    |> sort()
    |> dedup_list()
  end

  @doc """
  Sorts the `enumerable` by the given function and removes duplicates.

  See `Enum.sort/2` for more details about how the second parameter works.

  ## Examples

      iex> A.Enum.sort_uniq([1, 4, 2, 2, 3, 1, 4, 3], &(&1 >= &2))
      [4, 3, 2, 1]
      iex> A.Enum.sort_uniq([1, 4, 2, 2, 3, 1, 4, 3], :asc)
      [1, 2, 3, 4]
      iex> A.Enum.sort_uniq([1, 4, 2, 2, 3, 1, 4, 3], :desc)
      [4, 3, 2, 1]
      iex> dates = [~D[2019-01-01], ~D[2020-03-02], ~D[2019-01-01], ~D[2020-03-02]]
      iex> A.Enum.sort_uniq(dates, {:desc, Date})
      [~D[2020-03-02], ~D[2019-01-01]]

  """
  def sort_uniq(enumerable, fun) do
    enumerable
    |> sort(fun)
    |> dedup_list()
  end

  # Private functions

  defp dedup_list([]), do: []
  defp dedup_list([elem, elem | rest]), do: dedup_list([elem | rest])
  defp dedup_list([elem | rest]), do: [elem | dedup_list(rest)]
end
