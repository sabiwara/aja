defmodule Aja.Vector.Raw do
  @moduledoc false

  import Kernel, except: [min: 2, max: 2]

  require Aja.Vector.CodeGen, as: C

  alias Aja.Vector.{Builder, Node, Tail, Trie}

  @empty {0}

  defmacrop small(size, tail, first) do
    # TODO distinguish match
    quote do
      {unquote(size), 0, nil, nil, unquote(tail), unquote(first)}
    end
  end

  defmacrop large(size, tail_offset, shift, trie, tail, first) do
    quote do
      {unquote(size), unquote(tail_offset), unquote(shift), unquote(trie), unquote(tail),
       unquote(first)}
    end
  end

  defmacro first_pattern(first) do
    quote do
      {_, _, _, _, _, unquote(first)}
    end
  end

  defmacro last_pattern(last) do
    tail_ast = [last] |> C.left_fill_with(C.var(_)) |> C.array()

    quote do
      {_, _, _, _, unquote(tail_ast), _}
    end
  end

  defmacrop empty_pattern() do
    quote do: {_}
  end

  defmacrop tuple_ast(list) when is_list(list) do
    quote do
      {:{}, [], unquote(list)}
    end
  end

  @spec empty :: t()
  def empty, do: @empty

  @type value :: term
  @type size :: non_neg_integer
  @type tail_offset :: non_neg_integer
  @type shift :: non_neg_integer
  @type t(value) ::
          {0} | {size, tail_offset, shift | nil, Trie.t(value) | nil, Tail.t(value), value}
  @type t() :: t(value)

  defmacro size(vector) do
    quote do
      :erlang.element(1, unquote(vector))
    end
  end

  defmacro actual_index(raw_index, size) do
    # implemented using a macro because benches showed a significant improvement
    quote do
      size = unquote(size)

      case unquote(raw_index) do
        index when index >= size ->
          nil

        index when index >= 0 ->
          index

        index ->
          case size + index do
            negative when negative < 0 -> nil
            positive -> positive
          end
      end
    end
  end

  @spec from_list([val]) :: t(val) when val: value
  def from_list([]), do: @empty

  def from_list(list = [first | _]) do
    list |> Builder.from_list() |> from_builder(first)
  end

  defp from_builder({[], size, tail}, first) do
    small(size, tail, first)
  end

  defp from_builder({tries, tail_size, tail}, first) do
    {level, trie} = Builder.to_trie(tries, 0)
    tail_offset = Builder.tail_offset(tries, C.bits(), 0)
    large(tail_offset + tail_size, tail_offset, level, trie, tail, first)
  end

  @spec from_mapped_list([v1], (v1 -> v2)) :: t(v2) when v1: value, v2: value
  def from_mapped_list([], _fun), do: @empty

  def from_mapped_list(list, fun) when is_list(list) do
    list |> Builder.map_from_list(fun) |> from_builder()
  end

  defp from_builder({[], size, tail}) do
    first = :erlang.element(unquote(1 + C.branch_factor()) - size, tail)
    small(size, tail, first)
  end

  defp from_builder({tries, tail_size, tail}) do
    {level, trie} = Builder.to_trie(tries, 0)
    tail_offset = Builder.tail_offset(tries, C.bits(), 0)
    first = Trie.first(trie, level)
    large(tail_offset + tail_size, tail_offset, level, trie, tail, first)
  end

  def from_list_ast([]), do: unquote(Macro.escape(@empty) |> Macro.escape())

  def from_list_ast(list = [first | _]) do
    {size, tail_offset, leaves, tail} = Trie.group_leaves_ast(list)

    case Trie.from_ast_leaves(leaves) do
      nil -> tuple_ast([size, 0, nil, nil, tail, first])
      {shift, trie} -> tuple_ast([size, tail_offset, shift, trie, tail, first])
    end
  end

  def from_first_last_ast(first, last) do
    tail = [last] |> C.left_fill_with(C.var(_)) |> C.array()
    tuple_ast([C.var(_), C.var(_), C.var(_), C.var(_), tail, first])
  end

  @spec append(t(val), val) :: t(val) when val: value
  def append(vector, value)

  def append(small(size, tail, first), value) do
    if size == C.branch_factor() do
      large(
        size + 1,
        size,
        0,
        tail,
        unquote([C.var(value)] |> C.left_fill_with(nil) |> C.array()),
        first
      )
    else
      new_tail = Tail.append(tail, value)
      small(size + 1, new_tail, first)
    end
  end

  def append(large(size, tail_offset, level, trie, tail, first), value) do
    case C.radix_rem(size) do
      0 ->
        {new_trie, new_level} = Trie.append_leaf(trie, level, tail_offset, tail)
        new_tail = unquote([C.var(value)] |> C.left_fill_with(nil) |> C.array())
        large(size + 1, tail_offset + C.branch_factor(), new_level, new_trie, new_tail, first)

      _ ->
        new_tail = Tail.append(tail, value)
        large(size + 1, tail_offset, level, trie, new_tail, first)
    end
  end

  def append(empty_pattern(), value) do
    tail = unquote(C.value_with_nils(C.var(value)) |> Enum.reverse() |> C.array())
    small(1, tail, value)
  end

  def concat_list(vector, []), do: vector
  def concat_list(vector, [value]), do: append(vector, value)

  def concat_list(small(size, tail, first), list) do
    case Tail.complete_tail(tail, size, list) do
      {new_tail, added, []} ->
        small(size + added, new_tail, first)

      {first_leaf, _added, list} ->
        [[first_leaf]] |> Builder.concat_list(list) |> from_builder(first)
    end
  end

  def concat_list(large(size, tail_offset, level, trie, tail, first), list) do
    case Tail.complete_tail(tail, size - tail_offset, list) do
      {new_tail, added, []} ->
        large(size + added, tail_offset, level, trie, new_tail, first)

      {first_leaf, _added, list} ->
        Builder.from_trie(trie, level, tail_offset)
        |> Builder.append_node(first_leaf)
        |> Builder.concat_list(list)
        |> from_builder(first)
    end
  end

  def concat_list(empty_pattern(), list) do
    from_list(list)
  end

  def concat_vector(empty_pattern(), right), do: right
  def concat_vector(left, empty_pattern()), do: left

  def concat_vector(left, right = small(_, _, _)) do
    concat_list(left, to_list(right))
  end

  def concat_vector(left = small(_, _, _), right) do
    # can probably fo better
    left |> to_list(to_list(right)) |> from_list()
  end

  def concat_vector(
        large(size1, tail_offset1, level1, trie1, tail1, first1),
        large(size2, tail_offset2, level2, trie2, tail2, _first2)
      ) do
    leaves2 = Trie.list_leaves(trie2, level2, [], tail_offset2 - 1)

    Builder.from_trie(trie1, level1, tail_offset1)
    |> do_concat_vector(tail1, size1 - tail_offset1, leaves2, tail2, size2 - tail_offset2)
    |> from_builder(first1)
  end

  defp do_concat_vector(
         builder,
         tail1,
         _tail_size1 = C.branch_factor(),
         leaves2,
         tail2,
         tail_size2
       ) do
    builder
    |> Builder.append_node(tail1)
    |> Builder.append_nodes(leaves2)
    |> Builder.append_tail(tail2, tail_size2)
  end

  defp do_concat_vector(builder, tail1, tail_size1, leaves2, tail2, tail_size2) do
    [first_right_leaf | _] = leaves2

    {completed_tail, added, _list} =
      Tail.complete_tail(tail1, tail_size1, Node.to_list(first_right_leaf))

    builder
    |> Builder.append_node(completed_tail)
    |> Builder.append_nodes_with_offset(
      leaves2,
      added,
      tail2,
      tail_size2
    )
  end

  def prepend(vector, value) do
    # TODO make this a bit more efficient by pattern matching on leaves
    [value | to_list(vector)]
    |> from_list()
  end

  @spec duplicate(val, non_neg_integer) :: t(val) when val: value
  def duplicate(_, 0), do: @empty

  def duplicate(value, n) when n <= C.branch_factor() do
    tail = Tail.partial_duplicate(value, n)
    small(n, tail, value)
  end

  def duplicate(value, n) do
    tail_size = C.radix_rem(n - 1) + 1
    tail = Tail.partial_duplicate(value, tail_size)

    tail_offset = n - tail_size
    {level, trie} = Trie.duplicate(value, tail_offset)

    large(n, tail_offset, level, trie, tail, value)
  end

  @compile {:inline, fetch_positive!: 2}
  @spec fetch_positive!(t(val), non_neg_integer) :: val when val: value
  def fetch_positive!(small(size, tail, _first), index) do
    elem(tail, C.branch_factor() - size + index)
  end

  def fetch_positive!(large(size, tail_offset, shift, trie, tail, _first), index) do
    if index < tail_offset do
      Trie.lookup(trie, index, shift)
    else
      elem(tail, C.branch_factor() - size + index)
    end
  end

  @spec replace_positive!(t(val), non_neg_integer, val) :: t(val) when val: value
  def replace_positive!(vector, index, value)

  def replace_positive!(small(size, tail, first), index, value) do
    new_tail = put_elem(tail, C.branch_factor() - size + index, value)

    new_first =
      case index do
        0 -> value
        _ -> first
      end

    small(size, new_tail, new_first)
  end

  def replace_positive!(large(size, tail_offset, level, trie, tail, first), index, value) do
    new_first =
      case index do
        0 -> value
        _ -> first
      end

    if index < tail_offset do
      new_trie = Trie.replace(trie, index, level, value)
      large(size, tail_offset, level, new_trie, tail, new_first)
    else
      new_tail = put_elem(tail, C.branch_factor() - size + index, value)
      large(size, tail_offset, level, trie, new_tail, new_first)
    end
  end

  @spec update_positive!(t(val), non_neg_integer, (val -> val)) :: val when val: value
  def update_positive!(vector, index, fun)

  def update_positive!(small(size, tail, first), index, fun) do
    new_tail = Node.update_at(tail, C.branch_factor() - size + index, fun)

    new_first =
      case index do
        0 -> elem(new_tail, C.branch_factor() - size)
        _ -> first
      end

    small(size, new_tail, new_first)
  end

  def update_positive!(large(size, tail_offset, level, trie, tail, first), index, fun) do
    if index < tail_offset do
      new_trie = Trie.update(trie, index, level, fun)

      new_first =
        case index do
          0 -> Trie.first(new_trie, level)
          _ -> first
        end

      large(size, tail_offset, level, new_trie, tail, new_first)
    else
      new_tail = Node.update_at(tail, C.branch_factor() - size + index, fun)

      new_first =
        case index do
          0 -> elem(new_tail, C.branch_factor() - size)
          _ -> first
        end

      large(size, tail_offset, level, trie, new_tail, new_first)
    end
  end

  def get_and_update(vector, raw_index, fun) do
    case actual_index(raw_index, size(vector)) do
      nil ->
        get_and_update_missing_index(vector, fun)

      index ->
        value = fetch_positive!(vector, index)

        case fun.(value) do
          {returned, new_value} ->
            new_vector = replace_positive!(vector, index, new_value)
            {returned, new_vector}

          :pop ->
            {value, delete_positive!(vector, index, size(vector))}

          other ->
            get_and_update_error(other)
        end
    end
  end

  defp get_and_update_missing_index(vector, fun) do
    case fun.(nil) do
      {returned, _} -> {returned, vector}
      :pop -> {nil, vector}
      other -> get_and_update_error(other)
    end
  end

  defp get_and_update_error(other) do
    raise "the given function must return a two-element tuple or :pop, got: #{inspect(other)}"
  end

  @spec pop_last(t(val)) :: {val, t(val)} | :error when val: value
  def pop_last(vector = last_pattern(last)) do
    {last, delete_last(vector)}
  end

  def pop_last(empty_pattern()) do
    :error
  end

  @spec delete_last(t(val)) :: t(val) when val: value
  def delete_last(small(1, _tail, _first)), do: @empty

  def delete_last(small(size, tail, first)) do
    new_tail = Tail.delete_last(tail)
    small(size - 1, new_tail, first)
  end

  def delete_last(large(unquote(C.branch_factor() + 1), _, _, trie, _tail, first)) do
    small(C.branch_factor(), trie, first)
  end

  def delete_last(large(size, tail_offset, level, trie, tail, first)) do
    case tail_offset + 1 do
      ^size ->
        {new_tail, new_trie, new_level} = Trie.pop_leaf(trie, level, tail_offset - 1)
        large(size - 1, tail_offset - C.branch_factor(), new_level, new_trie, new_tail, first)

      _ ->
        new_tail = Tail.delete_last(tail)
        large(size - 1, tail_offset, level, trie, new_tail, first)
    end
  end

  def pop_positive!(vector, index, size) do
    case index + 1 do
      ^size ->
        pop_last(vector)

      _ ->
        left = take(vector, index)
        [popped | right] = slice(vector, index, size - 1)
        new_vector = concat_list(left, right)
        {popped, new_vector}
    end
  end

  def delete_positive!(vector, index, size) do
    case index + 1 do
      ^size ->
        delete_last(vector)

      amount ->
        left = take(vector, index)
        right = slice(vector, amount, size - 1)
        concat_list(left, right)
    end
  end

  # LOOPS

  @spec to_list(t(val)) :: [val] when val: value
  def to_list(small(size, tail, _first)) do
    Tail.partial_to_list(tail, size)
  end

  def to_list(large(size, tail_offset, shift, trie, tail, _first)) do
    acc = Tail.partial_to_list(tail, size - tail_offset)
    Trie.to_list(trie, shift, acc)
  end

  def to_list(empty_pattern()) do
    []
  end

  @spec to_list(t(val), [val]) :: [val] when val: value
  def to_list(small(size, tail, _first), list) do
    Tail.partial_to_list(tail, size) ++ list
  end

  def to_list(large(size, tail_offset, shift, trie, tail, _first), list) do
    acc = Tail.partial_to_list(tail, size - tail_offset) ++ list
    Trie.to_list(trie, shift, acc)
  end

  def to_list(empty_pattern(), list) do
    list
  end

  @spec reverse_to_list(t(val), [val]) :: [val] when val: value
  C.def_foldl reverse_to_list(arg, acc) do
    [arg | acc]
  end

  @spec sparse_to_list(t(val)) :: [val] when val: value
  C.def_foldr sparse_to_list(arg, acc \\ []) do
    case arg do
      nil -> acc
      value -> [value | acc]
    end
  end

  @spec foldl(t(val), acc, (val, acc -> acc)) :: acc when val: value, acc: term
  C.def_foldl foldl(arg, acc, fun) do
    fun.(arg, acc)
  end

  @spec reduce(t(val), (val, val -> val)) :: val when val: value
  C.def_foldl reduce(arg, acc \\ first(), fun) do
    fun.(arg, acc)
  end

  @spec foldr(t(val), acc, (val, acc -> acc)) :: acc when val: value, acc: term
  C.def_foldr foldr(arg, acc, fun) do
    fun.(arg, acc)
  end

  @spec each(t(val), (val -> term)) :: :ok when val: value
  def each(vector, fun) do
    do_each(vector, fun)
    :ok
  end

  C.def_foldl do_each(arg, fun) do
    fun.(arg)
    fun
  end

  @spec sum(t(number)) :: number
  C.def_foldl sum(arg, acc \\ 0) do
    acc + arg
  end

  @spec product(t(number)) :: number
  C.def_foldl product(arg, acc \\ 1) do
    acc * arg
  end

  @spec count(t(val), (val -> as_boolean(term))) :: non_neg_integer when val: value
  C.def_foldl count(arg, acc \\ 0, fun) do
    if fun.(arg) do
      acc + 1
    else
      acc
    end
  end

  @spec intersperse_to_list(t(val), sep) :: [val | sep] when val: value, sep: value
  def intersperse_to_list(vector, separator) do
    case do_intersperse_to_list(vector, separator) do
      [] -> []
      [_ | rest] -> rest
    end
  end

  C.def_foldr do_intersperse_to_list(arg, acc \\ [], separator) do
    [separator, arg | acc]
  end

  def map_to_list(vector, fun) do
    map_reverse_list(vector, fun) |> :lists.reverse()
  end

  C.def_foldl map_reverse_list(arg, acc \\ [], fun) do
    [fun.(arg) | acc]
  end

  def map_intersperse_to_list(vector, separator, mapper) do
    case do_map_intersperse_to_list(vector, separator, mapper) do
      [] -> []
      [_ | rest] -> :lists.reverse(rest)
    end
  end

  C.def_foldl do_map_intersperse_to_list(arg, acc \\ [], separator, mapper) do
    [separator, mapper.(arg) | acc]
  end

  @spec join_as_iodata(t(val), String.t()) :: iodata when val: String.Chars.t()
  def join_as_iodata(vector, joiner) do
    case joiner do
      "" ->
        do_join(vector)

      _ ->
        case do_join(vector, joiner) do
          [] -> []
          [_ | rest] -> rest
        end
    end
  end

  C.def_foldr do_join(arg, acc \\ []) do
    [entry_to_string(arg) | acc]
  end

  C.def_foldr do_join(arg, acc \\ [], joiner) do
    [joiner, entry_to_string(arg) | acc]
  end

  defp entry_to_string(entry) when is_binary(entry), do: entry
  defp entry_to_string(entry), do: String.Chars.to_string(entry)

  @spec max(t(val)) :: val when val: value
  C.def_foldl max(arg, acc \\ first()) do
    if acc >= arg do
      acc
    else
      arg
    end
  end

  C.def_foldl min(arg, acc \\ first()) do
    if acc <= arg do
      acc
    else
      arg
    end
  end

  @spec custom_min_max(t(val), (val, val -> boolean)) :: val when val: value
  C.def_foldl custom_min_max(arg, acc \\ first(), sorter) do
    if sorter.(acc, arg) do
      acc
    else
      arg
    end
  end

  @spec custom_min_max_by(t(val), (val -> mapped_val), (mapped_val, mapped_val -> boolean)) :: val
        when val: value, mapped_val: value
  def custom_min_max_by(vector, fun, sorter) do
    foldl(vector, nil, fn arg, acc ->
      case acc do
        nil ->
          {arg, fun.(arg)}

        {_, prev_value} ->
          arg_value = fun.(arg)

          if sorter.(prev_value, arg_value) do
            acc
          else
            {arg, arg_value}
          end
      end
    end)
    |> elem(0)
  end

  @spec frequencies(t(val)) :: %{optional(val) => non_neg_integer} when val: value
  C.def_foldl frequencies(arg, acc \\ %{}) do
    increase_frequency(acc, arg)
  end

  @spec frequencies_by(t(val), (val -> key)) :: %{optional(key) => non_neg_integer}
        when val: value, key: any
  C.def_foldl frequencies_by(arg, acc \\ %{}, key_fun) do
    key = key_fun.(arg)
    increase_frequency(acc, key)
  end

  defp increase_frequency(acc, key) do
    case acc do
      %{^key => value} -> %{acc | key => value + 1}
      _ -> Map.put(acc, key, 1)
    end
  end

  @spec group_by(t(val), (val -> key), (val -> mapped_val)) :: %{optional(key) => [mapped_val]}
        when val: value, key: any, mapped_val: any
  C.def_foldr group_by(arg, acc \\ %{}, key_fun, value_fun) do
    key = key_fun.(arg)
    value = value_fun.(arg)

    add_to_group(acc, key, value)
  end

  defp add_to_group(acc, key, value) do
    case acc do
      %{^key => list} -> %{acc | key => [value | list]}
      _ -> Map.put(acc, key, [value])
    end
  end

  def uniq_list(vector) do
    vector |> do_uniq() |> elem(0) |> :lists.reverse()
  end

  C.def_foldl do_uniq(arg, acc \\ {[], %{}}) do
    add_to_set(acc, arg, arg)
  end

  def uniq_by_list(vector, fun) do
    vector |> do_uniq_by(fun) |> elem(0) |> :lists.reverse()
  end

  C.def_foldl do_uniq_by(arg, acc \\ {[], %{}}, fun) do
    key = fun.(arg)
    add_to_set(acc, key, arg)
  end

  defp add_to_set({list, set} = acc, key, value) do
    case set do
      %{^key => _} -> acc
      _ -> {[value | list], Map.put(set, key, true)}
    end
  end

  C.def_foldr dedup_list(arg, acc \\ []) do
    case acc do
      [^arg | _] -> acc
      _ -> [arg | acc]
    end
  end

  @spec filter_to_list(t(val), (val -> as_boolean(term))) :: [val] when val: value
  def filter_to_list(vector, fun) do
    vector
    |> do_filter(fun)
    |> :lists.reverse()
  end

  C.def_foldl do_filter(arg, acc \\ [], fun) do
    if fun.(arg) do
      [arg | acc]
    else
      acc
    end
  end

  @spec reject_to_list(t(val), (val -> as_boolean(term))) :: [val] when val: value
  def reject_to_list(vector, fun) do
    vector
    |> do_reject(fun)
    |> :lists.reverse()
  end

  C.def_foldl do_reject(arg, acc \\ [], fun) do
    if fun.(arg) do
      acc
    else
      [arg | acc]
    end
  end

  # FIND

  def member?(small(size, tail, _first), value) do
    Tail.partial_member?(tail, size, value)
  end

  def member?(large(size, tail_offset, level, trie, tail, _first), value) do
    Trie.member?(trie, level, value) or Tail.partial_member?(tail, size - tail_offset, value)
  end

  def member?(empty_pattern(), _value), do: false
  @spec any?(t()) :: boolean()

  def any?(small(size, tail, _first)) do
    Tail.partial_any?(tail, size)
  end

  def any?(large(size, tail_offset, level, trie, tail, _first)) do
    Trie.any?(trie, level) or Tail.partial_any?(tail, size - tail_offset)
  end

  def any?(empty_pattern()), do: false

  @spec any?(t(val), (val -> as_boolean(term))) :: boolean() when val: value

  def any?(small(size, tail, _first), fun) do
    Tail.partial_any?(tail, C.branch_factor() - size, fun)
  end

  def any?(large(size, tail_offset, level, trie, tail, _first), fun) do
    Trie.any?(trie, level, fun) or
      Tail.partial_any?(tail, C.branch_factor() + tail_offset - size, fun)
  end

  def any?(empty_pattern(), _fun), do: false

  @spec all?(t()) :: boolean()

  def all?(small(size, tail, _first)) do
    Tail.partial_all?(tail, size)
  end

  def all?(large(size, tail_offset, level, trie, tail, _first)) do
    Trie.all?(trie, level) and Tail.partial_all?(tail, size - tail_offset)
  end

  def all?(empty_pattern()), do: true

  @spec all?(t(val), (val -> as_boolean(term))) :: boolean() when val: value

  def all?(small(size, tail, _first), fun) do
    Tail.partial_all?(tail, C.branch_factor() - size, fun)
  end

  def all?(large(size, tail_offset, level, trie, tail, _first), fun) do
    Trie.all?(trie, level, fun) and
      Tail.partial_all?(tail, C.branch_factor() + tail_offset - size, fun)
  end

  def all?(empty_pattern(), _fun), do: true

  @spec find(t(val), default, (val -> as_boolean(term))) :: val | default
        when val: value, default: any
  def find(vector, default, fun) do
    case do_find(vector, fun) do
      {:ok, value} -> value
      nil -> default
    end
  end

  defp do_find(small(size, tail, _first), fun) do
    Tail.partial_find(tail, C.branch_factor() - size, fun)
  end

  defp do_find(large(size, tail_offset, level, trie, tail, _first), fun) do
    Trie.find(trie, level, fun) ||
      Tail.partial_find(tail, C.branch_factor() + tail_offset - size, fun)
  end

  defp do_find(empty_pattern(), _fun), do: nil

  @spec find_value(t(val), (val -> new_val)) :: new_val | nil when val: value, new_val: value

  def find_value(small(size, tail, _first), fun) do
    Tail.partial_find_value(tail, C.branch_factor() - size, fun)
  end

  def find_value(large(size, tail_offset, level, trie, tail, _first), fun) do
    Trie.find_value(trie, level, fun) ||
      Tail.partial_find_value(tail, C.branch_factor() + tail_offset - size, fun)
  end

  def find_value(empty_pattern(), _fun), do: nil

  @spec find_index(t(val), (val -> as_boolean(term))) :: non_neg_integer | nil when val: value

  def find_index(small(size, tail, _first), fun) do
    case Tail.partial_find_index(tail, C.branch_factor() - size, fun) do
      nil -> nil
      index -> index + size - C.branch_factor()
    end
  end

  def find_index(large(size, tail_offset, level, trie, tail, _first), fun) do
    cond do
      index = Trie.find_index(trie, level, fun) ->
        index

      index = Tail.partial_find_index(tail, C.branch_factor() + tail_offset - size, fun) ->
        index + size - C.branch_factor()

      true ->
        nil
    end
  end

  def find_index(empty_pattern(), _fun), do: nil

  @spec find_falsy_index(t(val), (val -> as_boolean(term))) :: non_neg_integer | nil
        when val: value

  def find_falsy_index(small(size, tail, _first), fun) do
    case Tail.partial_find_falsy_index(tail, C.branch_factor() - size, fun) do
      nil -> nil
      index -> index + size - C.branch_factor()
    end
  end

  def find_falsy_index(large(size, tail_offset, level, trie, tail, _first), fun) do
    cond do
      index = Trie.find_falsy_index(trie, level, fun) ->
        index

      index = Tail.partial_find_falsy_index(tail, C.branch_factor() + tail_offset - size, fun) ->
        index + size - C.branch_factor()

      true ->
        nil
    end
  end

  def find_falsy_index(empty_pattern(), _fun), do: nil

  @compile {:inline, map: 2}
  @spec map(t(v1), (v1 -> v2)) :: t(v2) when v1: value, v2: value
  def map(vector, fun)

  def map(small(size, tail, _first), fun) do
    new_tail = Tail.partial_map(tail, fun, size)
    new_first = elem(new_tail, C.branch_factor() - size)
    small(size, new_tail, new_first)
  end

  def map(large(size, tail_offset, level, trie, tail, _first), fun) do
    new_trie = Trie.map(trie, level, fun)
    new_tail = Tail.partial_map(tail, fun, size - tail_offset)

    large(size, tail_offset, level, new_trie, new_tail, Trie.first(new_trie, level))
  end

  def map(empty_pattern(), _fun), do: @empty

  @compile {:inline, slice: 3}
  @spec slice(t(val), non_neg_integer, non_neg_integer) :: [val] when val: value
  def slice(vector, start, last)

  def slice(small(size, tail, _first), start, last) do
    Tail.slice(tail, start, last, size)
  end

  def slice(large(size, tail_offset, level, trie, tail, _first), start, last) do
    acc =
      if last < tail_offset do
        []
      else
        Tail.slice(
          tail,
          Kernel.max(0, start - tail_offset),
          last - tail_offset,
          size - tail_offset
        )
      end

    if start < tail_offset do
      Trie.slice(trie, start, Kernel.min(last, tail_offset - 1), level, acc)
    else
      acc
    end
  end

  def slice(empty_pattern(), _start, _last), do: []

  @compile {:inline, take: 2}
  @spec take(t(val), non_neg_integer) :: t(val) when val: value
  def take(vector, amount)

  def take(small(size, tail, first) = vector, amount) do
    case amount do
      0 ->
        @empty

      too_big when too_big >= size ->
        vector

      new_size ->
        new_tail = Tail.partial_take(tail, size - new_size)
        small(new_size, new_tail, first)
    end
  end

  def take(large(size, tail_offset, level, trie, tail, first) = vector, amount) do
    case amount do
      0 ->
        @empty

      too_big when too_big >= size ->
        vector

      new_size ->
        case new_size > tail_offset do
          true ->
            new_tail = Tail.partial_take(tail, size - new_size)
            large(new_size, tail_offset, level, trie, new_tail, first)

          _ ->
            case Trie.take(trie, level, new_size) do
              {:small, new_tail} ->
                small(new_size, new_tail, first)

              {:large, new_trie, new_level, new_tail} ->
                large(new_size, get_tail_offset(new_size), new_level, new_trie, new_tail, first)
            end
        end
    end
  end

  def take(empty_pattern(), _amount), do: @empty

  defp get_tail_offset(size) do
    size - C.radix_rem(size - 1) - 1
  end

  @spec with_index(t(val), integer) :: t({val, integer}) when val: value
  def with_index(vector, offset)

  def with_index(small(size, tail, _first), offset) do
    new_tail = Tail.partial_with_index(tail, C.branch_factor() - size, offset)
    new_first = elem(new_tail, C.branch_factor() - size)
    small(size, new_tail, new_first)
  end

  def with_index(large(size, tail_offset, level, trie, tail, _first), offset) do
    new_trie = Trie.with_index(trie, level, offset)

    new_tail =
      Tail.partial_with_index(tail, C.branch_factor() + tail_offset - size, offset + tail_offset)

    large(size, tail_offset, level, new_trie, new_tail, Trie.first(new_trie, level))
  end

  def with_index(empty_pattern(), _offset), do: @empty

  def with_index(vector, offset, fun)

  def with_index(small(size, tail, _first), offset, fun) do
    new_tail = Tail.partial_with_index(tail, C.branch_factor() - size, offset, fun)
    new_first = elem(new_tail, C.branch_factor() - size)
    small(size, new_tail, new_first)
  end

  def with_index(large(size, tail_offset, level, trie, tail, _first), offset, fun) do
    new_trie = Trie.with_index(trie, level, offset, fun)

    new_tail =
      Tail.partial_with_index(
        tail,
        C.branch_factor() + tail_offset - size,
        offset + tail_offset,
        fun
      )

    large(size, tail_offset, level, new_trie, new_tail, Trie.first(new_trie, level))
  end

  def with_index(empty_pattern(), _offset, _fun), do: @empty

  @compile {:inline, random: 1}
  def random(empty_pattern()) do
    raise Enum.EmptyError
  end

  def random(vector) do
    index = :rand.uniform(size(vector)) - 1
    fetch_positive!(vector, index)
  end

  def take_random(empty_pattern(), _amount), do: @empty
  def take_random(_vector, 0), do: @empty

  def take_random(vector, 1) do
    picked = random(vector)
    tail = unquote([C.var(picked)] |> C.left_fill_with(nil) |> C.array())
    small(1, tail, picked)
  end

  def take_random(vector, amount) when amount >= size(vector) do
    vector |> to_list() |> Enum.shuffle() |> from_list()
  end

  def take_random(vector, amount) do
    vector |> to_list() |> Enum.take_random(amount) |> from_list()
  end

  def scan(vector, fun) do
    ref = make_ref()

    scan(vector, ref, fn
      value, ^ref -> value
      value, acc -> fun.(value, acc)
    end)
  end

  def scan(small(size, tail, _first), acc, fun) do
    new_tail = Tail.partial_scan(tail, C.branch_factor() - size, acc, fun)
    new_first = elem(new_tail, C.branch_factor() - size)
    small(size, new_tail, new_first)
  end

  def scan(
        large(size, tail_offset, level, trie, tail, _first),
        acc,
        fun
      ) do
    {new_trie, acc} = Trie.scan(trie, level, acc, fun)
    new_tail = Tail.partial_scan(tail, C.branch_factor() + tail_offset - size, acc, fun)
    large(size, tail_offset, level, new_trie, new_tail, Trie.first(new_trie, level))
  end

  def scan(empty_pattern(), _acc, _fun), do: @empty

  def map_reduce(small(size, tail, _first), acc, fun) do
    {new_tail, acc} = Tail.partial_map_reduce(tail, C.branch_factor() - size, acc, fun)
    new_first = elem(new_tail, C.branch_factor() - size)
    new_raw = small(size, new_tail, new_first)
    {new_raw, acc}
  end

  def map_reduce(
        large(size, tail_offset, level, trie, tail, _first),
        acc,
        fun
      ) do
    {new_trie, acc} = Trie.map_reduce(trie, level, acc, fun)

    {new_tail, acc} =
      Tail.partial_map_reduce(tail, C.branch_factor() + tail_offset - size, acc, fun)

    new_first = Trie.first(new_trie, level)
    new_raw = large(size, tail_offset, level, new_trie, new_tail, new_first)
    {new_raw, acc}
  end

  def map_reduce(empty_pattern(), acc, _fun), do: {@empty, acc}

  @spec zip(t(val1), t(val2)) :: t({val1, val2}) when val1: value, val2: value
  def zip(vector1, vector2) do
    size1 = size(vector1)
    size2 = size(vector2)

    cond do
      size1 > size2 -> do_zip(take(vector1, size2), vector2)
      size1 == size2 -> do_zip(vector1, vector2)
      true -> do_zip(vector1, take(vector2, size1))
    end
  end

  defp do_zip(small(size, tail1, first1), small(size, tail2, first2)) do
    new_tail = Tail.partial_zip(tail1, tail2, C.branch_factor() - size)
    small(size, new_tail, {first1, first2})
  end

  defp do_zip(
         large(size, tail_offset, level, trie1, tail1, first1),
         large(size, tail_offset, level, trie2, tail2, first2)
       ) do
    new_tail = Tail.partial_zip(tail1, tail2, C.branch_factor() + tail_offset - size)
    new_trie = Trie.zip(trie1, trie2, level)
    large(size, tail_offset, level, new_trie, new_tail, {first1, first2})
  end

  defp do_zip(empty_pattern(), empty_pattern()), do: @empty

  @spec zip_with(t(val1), t(val2), (val1, val2 -> val3)) :: t(val3)
        when val1: value, val2: value, val3: value
  def zip_with(vector1, vector2, fun) do
    size1 = size(vector1)
    size2 = size(vector2)

    cond do
      size1 > size2 -> do_zip_with(take(vector1, size2), vector2, fun)
      size1 == size2 -> do_zip_with(vector1, vector2, fun)
      true -> do_zip_with(vector1, take(vector2, size1), fun)
    end
  end

  defp do_zip_with(small(size, tail1, _first1), small(size, tail2, _first2), fun) do
    new_tail = Tail.partial_zip_with(tail1, tail2, C.branch_factor() - size, fun)
    new_first = elem(new_tail, C.branch_factor() - size)
    small(size, new_tail, new_first)
  end

  defp do_zip_with(
         large(size, tail_offset, level, trie1, tail1, _first1),
         large(size, tail_offset, level, trie2, tail2, _first2),
         fun
       ) do
    new_tail = Tail.partial_zip_with(tail1, tail2, C.branch_factor() + tail_offset - size, fun)
    new_trie = Trie.zip_with(trie1, trie2, level, fun)
    new_first = Trie.first(new_trie, level)
    large(size, tail_offset, level, new_trie, new_tail, new_first)
  end

  defp do_zip_with(empty_pattern(), empty_pattern(), _fun), do: @empty

  @spec unzip(t({val1, val2})) :: {t(val1), t(val2)} when val1: value, val2: value
  def unzip(small(size, tail, _size)) do
    {tail1, tail2} = Tail.partial_unzip(tail, C.branch_factor() - size)
    first1 = elem(tail1, C.branch_factor() - size)
    first2 = elem(tail2, C.branch_factor() - size)
    {small(size, tail1, first1), small(size, tail2, first2)}
  end

  def unzip(large(size, tail_offset, level, trie, tail, first)) do
    {tail1, tail2} = Tail.partial_unzip(tail, C.branch_factor() + tail_offset - size)
    {trie1, trie2} = Trie.unzip(trie, level)
    {first1, first2} = first

    {
      large(size, tail_offset, level, trie1, tail1, first1),
      large(size, tail_offset, level, trie2, tail2, first2)
    }
  end

  def unzip(empty_pattern()), do: {@empty, @empty}
end
