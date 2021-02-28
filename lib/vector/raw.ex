defmodule A.Vector.Raw do
  @moduledoc false

  import Kernel, except: [min: 2, max: 2]

  alias A.Vector.CodeGen, as: C
  require C

  alias A.Vector.{Node, Tail, Trie}

  @empty {0}

  defmacrop small(size, tail) do
    quote do
      {unquote(size), unquote(tail)}
    end
  end

  defmacrop large(size, tail_offset, shift, trie, tail) do
    quote do
      {unquote(size), unquote(tail_offset), unquote(shift), unquote(trie), unquote(tail)}
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
          {0}
          | {size, Tail.t(value)}
          | {size, tail_offset, shift, Trie.t(value), Tail.t(value)}
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

  def from_list(list) when is_list(list) do
    {size, tail_offset, leaves, tail} = Trie.group_leaves(list)

    case Trie.from_leaves(leaves) do
      nil -> small(size, tail)
      {shift, trie} -> large(size, tail_offset, shift, trie, tail)
    end
  end

  @spec from_mapped_list([v1], (v1 -> v2)) :: t(v2) when v1: value, v2: value
  def from_mapped_list([], _fun), do: @empty

  def from_mapped_list(list, fun) when is_list(list) do
    {size, tail_offset, leaves, tail} = Trie.group_map_leaves(list, fun)

    case Trie.from_leaves(leaves) do
      nil -> small(size, tail)
      {shift, trie} -> large(size, tail_offset, shift, trie, tail)
    end
  end

  def from_list_ast([]), do: unquote(Macro.escape(@empty) |> Macro.escape())

  def from_list_ast(list) do
    {size, tail_offset, leaves, tail} = Trie.group_leaves_ast(list)

    case Trie.from_ast_leaves(leaves) do
      nil -> {size, tail}
      {shift, trie} -> tuple_ast([size, tail_offset, shift, trie, tail])
    end
  end

  @spec append(t(val), val) :: t(val) when val: value
  def append(vector, value)

  def append(large(size, tail_offset, level, trie, tail), value) do
    case C.radix_rem(size) do
      0 ->
        {new_trie, new_level} = Trie.append_leaf(trie, level, tail_offset, tail)
        new_tail = unquote(C.value_with_nils(C.var(value)) |> C.array())
        large(size + 1, tail_offset + C.branch_factor(), new_level, new_trie, new_tail)

      _ ->
        new_tail = put_elem(tail, size - tail_offset, value)
        large(size + 1, tail_offset, level, trie, new_tail)
    end
  end

  def append(small(size, tail), value) do
    if size == C.branch_factor() do
      large(size + 1, size, 0, tail, unquote(C.value_with_nils(C.var(value)) |> C.array()))
    else
      new_tail = put_elem(tail, size, value)
      small(size + 1, new_tail)
    end
  end

  def append(empty_pattern(), value) do
    small(1, unquote(C.value_with_nils(C.var(value)) |> C.array()))
  end

  def concat(large(size, tail_offset, level, trie, tail), list) do
    case Tail.complete_tail(tail, size - tail_offset, list) do
      {new_tail, added, []} ->
        large(size + added, tail_offset, level, trie, new_tail)

      {first_leaf, added_tail, list} ->
        {added_size, added_offset, leaves, new_tail} = Trie.group_leaves(list)

        {new_trie, new_level} =
          Trie.append_leaves(trie, level, tail_offset, [first_leaf | leaves])

        new_size = size + added_size + added_tail
        new_offset = tail_offset + added_offset + C.branch_factor()
        large(new_size, new_offset, new_level, new_trie, new_tail)
    end
  end

  def concat(small(size, tail), list) do
    case Tail.complete_tail(tail, size, list) do
      {new_tail, added, []} ->
        small(size + added, new_tail)

      {first_leaf, added_tail, list} ->
        {added_size, tail_offset, leaves, new_tail} = Trie.group_leaves(list)

        {shift, trie} = Trie.from_leaves([first_leaf | leaves])

        large(
          size + added_size + added_tail,
          tail_offset + C.branch_factor(),
          shift,
          trie,
          new_tail
        )
    end
  end

  def concat(empty_pattern(), list) do
    from_list(list)
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
    small(n, tail)
  end

  def duplicate(value, n) do
    tail_size = C.radix_rem(n - 1) + 1
    tail = Tail.partial_duplicate(value, tail_size)

    tail_offset = n - tail_size
    {level, trie} = Trie.duplicate(value, tail_offset)

    large(n, tail_offset, level, trie, tail)
  end

  @compile {:inline, fetch_positive!: 2}
  @spec fetch_positive!(t(val), non_neg_integer) :: val when val: value
  def fetch_positive!(large(_size, tail_offset, shift, trie, tail), index) do
    if index < tail_offset do
      Trie.lookup(trie, index, shift)
    else
      elem(tail, index - tail_offset)
    end
  end

  def fetch_positive!(small(_size, tail), index) do
    elem(tail, index)
  end

  @compile {:inline, first: 2}
  @spec first(t(val), default) :: val | default when val: value, default: term
  def first(vector, default)

  def first(large(_size, _tail_offset, shift, trie, _tail), _default) do
    Trie.lookup(trie, 0, shift)
  end

  def first(small(_size, tail), _default) do
    elem(tail, 0)
  end

  def first(empty_pattern(), default) do
    default
  end

  @compile {:inline, last: 2}
  @spec last(t(val), default) :: val | default when val: value, default: term
  def last(vector, default)

  def last(large(size, tail_offset, _shift, _trie, tail), _default) do
    elem(tail, size - tail_offset - 1)
  end

  def last(small(size, tail), _default) do
    elem(tail, size - 1)
  end

  def last(empty_pattern(), default) do
    default
  end

  @spec replace_positive!(t(val), non_neg_integer, val) :: t(val) when val: value
  def replace_positive!(vector, index, value)

  def replace_positive!(large(size, tail_offset, level, trie, tail), index, value) do
    if index < tail_offset do
      new_trie = Trie.replace(trie, index, level, value)
      large(size, tail_offset, level, new_trie, tail)
    else
      new_tail = put_elem(tail, index - tail_offset, value)
      large(size, tail_offset, level, trie, new_tail)
    end
  end

  def replace_positive!(small(size, tail), index, value) do
    new_tail = put_elem(tail, index, value)
    small(size, new_tail)
  end

  @spec update_positive!(t(val), non_neg_integer, (val -> val)) :: val when val: value
  def update_positive!(vector, index, fun)

  def update_positive!(large(size, tail_offset, level, trie, tail), index, fun) do
    if index < tail_offset do
      new_trie = Trie.update(trie, index, level, fun)
      large(size, tail_offset, level, new_trie, tail)
    else
      new_tail = Node.update_at(tail, index - tail_offset, fun)
      large(size, tail_offset, level, trie, new_tail)
    end
  end

  def update_positive!(small(size, tail), index, fun) do
    new_tail = Node.update_at(tail, index, fun)
    small(size, new_tail)
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
  def pop_last(large(unquote(C.branch_factor() + 1), _, _, trie, tail)) do
    new_vector = small(C.branch_factor(), trie)
    {elem(tail, 0), new_vector}
  end

  def pop_last(large(size, tail_offset, level, trie, tail)) do
    case size - tail_offset - 1 do
      0 ->
        {new_tail, new_trie, new_level} = Trie.pop_leaf(trie, level, tail_offset - 1)

        new_vector =
          large(size - 1, tail_offset - C.branch_factor(), new_level, new_trie, new_tail)

        {elem(tail, 0), new_vector}

      tail_index ->
        new_tail = put_elem(tail, tail_index, nil)
        new_vector = large(size - 1, tail_offset, level, trie, new_tail)
        {elem(tail, tail_index), new_vector}
    end
  end

  def pop_last(small(1, tail)) do
    {elem(tail, 0), @empty}
  end

  def pop_last(small(size, tail)) do
    new_size = size - 1
    new_vector = small(new_size, put_elem(tail, new_size, nil))
    {elem(tail, new_size), new_vector}
  end

  def pop_last(empty_pattern()), do: :error

  def pop_positive!(vector, index, size) do
    case index + 1 do
      ^size ->
        pop_last(vector)

      _ ->
        left = take(vector, index)
        [popped | right] = slice(vector, index, size - 1)
        new_vector = concat(left, right)
        {popped, new_vector}
    end
  end

  def delete_positive!(vector, index, size) do
    case index + 1 do
      ^size ->
        {_last, popped} = pop_last(vector)
        popped

      amount ->
        left = take(vector, index)
        right = slice(vector, amount, size - 1)
        concat(left, right)
    end
  end

  # LOOPS

  @spec to_list(t(val)) :: [val] when val: value
  def to_list(large(size, tail_offset, shift, trie, tail)) do
    acc = Tail.partial_to_list(tail, size - tail_offset)
    Trie.to_list(trie, shift, acc)
  end

  def to_list(small(size, tail)) do
    Tail.partial_to_list(tail, size)
  end

  def to_list(empty_pattern()) do
    []
  end

  @spec reverse_to_list(t(val)) :: [val] when val: value
  C.def_foldl reverse_to_list(arg, acc \\ []) do
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
    do_map_to_list(vector, fun) |> :lists.reverse()
  end

  C.def_foldl do_map_to_list(arg, acc \\ [], fun) do
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

  def member?(large(size, tail_offset, level, trie, tail), value) do
    Trie.member?(trie, level, value) or Tail.partial_member?(tail, size - tail_offset, value)
  end

  def member?(small(size, tail), value) do
    Tail.partial_member?(tail, size, value)
  end

  def member?(empty_pattern(), _value), do: false
  @spec any?(t()) :: boolean()

  def any?(large(size, tail_offset, level, trie, tail)) do
    Trie.any?(trie, level) or Tail.partial_any?(tail, size - tail_offset)
  end

  def any?(small(size, tail)) do
    Tail.partial_any?(tail, size)
  end

  def any?(empty_pattern()), do: false

  @spec any?(t(val), (val -> as_boolean(term))) :: boolean() when val: value

  def any?(large(size, tail_offset, level, trie, tail), fun) do
    Trie.any?(trie, level, fun) or Tail.partial_any?(tail, size - tail_offset, fun)
  end

  def any?(small(size, tail), fun) do
    Tail.partial_any?(tail, size, fun)
  end

  def any?(empty_pattern(), _fun), do: false

  @spec all?(t()) :: boolean()

  def all?(large(size, tail_offset, level, trie, tail)) do
    Trie.all?(trie, level) and Tail.partial_all?(tail, size - tail_offset)
  end

  def all?(small(size, tail)) do
    Tail.partial_all?(tail, size)
  end

  def all?(empty_pattern()), do: true

  @spec all?(t(val), (val -> as_boolean(term))) :: boolean() when val: value

  def all?(large(size, tail_offset, level, trie, tail), fun) do
    Trie.all?(trie, level, fun) and Tail.partial_all?(tail, size - tail_offset, fun)
  end

  def all?(small(size, tail), fun) do
    Tail.partial_all?(tail, size, fun)
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

  defp do_find(large(size, tail_offset, level, trie, tail), fun) do
    Trie.find(trie, level, fun) || Tail.partial_find(tail, size - tail_offset, fun)
  end

  defp do_find(small(size, tail), fun) do
    Tail.partial_find(tail, size, fun)
  end

  defp do_find(empty_pattern(), _fun), do: nil

  @spec find_value(t(val), (val -> new_val)) :: new_val | nil when val: value, new_val: value

  def find_value(large(size, tail_offset, level, trie, tail), fun) do
    Trie.find_value(trie, level, fun) || Tail.partial_find_value(tail, size - tail_offset, fun)
  end

  def find_value(small(size, tail), fun) do
    Tail.partial_find_value(tail, size, fun)
  end

  def find_value(empty_pattern(), _fun), do: nil

  @spec find_index(t(val), (val -> as_boolean(term))) :: non_neg_integer | nil when val: value

  def find_index(large(size, tail_offset, level, trie, tail), fun) do
    cond do
      index = Trie.find_index(trie, level, fun) -> index
      index = Tail.partial_find_index(tail, size - tail_offset, fun) -> index + tail_offset
      true -> nil
    end
  end

  def find_index(small(size, tail), fun) do
    Tail.partial_find_index(tail, size, fun)
  end

  def find_index(empty_pattern(), _fun), do: nil

  def find_falsy_index(large(size, tail_offset, level, trie, tail), fun) do
    cond do
      index = Trie.find_falsy_index(trie, level, fun) -> index
      index = Tail.partial_find_falsy_index(tail, size - tail_offset, fun) -> index + tail_offset
      true -> nil
    end
  end

  def find_falsy_index(small(size, tail), fun) do
    Tail.partial_find_falsy_index(tail, size, fun)
  end

  def find_falsy_index(empty_pattern(), _fun), do: nil

  @compile {:inline, map: 2}
  @spec map(t(v1), (v1 -> v2)) :: t(v2) when v1: value, v2: value
  def map(vector, fun)

  def map(large(size, tail_offset, level, trie, tail), fun) do
    new_trie = Trie.map(trie, level, fun)
    new_tail = Tail.partial_map(tail, fun, size - tail_offset)

    large(size, tail_offset, level, new_trie, new_tail)
  end

  def map(small(size, tail), fun) do
    new_tail = Tail.partial_map(tail, fun, size)
    small(size, new_tail)
  end

  def map(empty_pattern(), _fun), do: @empty

  @compile {:inline, slice: 3}
  @spec slice(t(val), non_neg_integer, non_neg_integer) :: [val] when val: value
  def slice(vector, start, last)

  def slice(large(_size, tail_offset, level, trie, tail), start, last) do
    acc =
      if last < tail_offset do
        []
      else
        Tail.slice(tail, Kernel.max(0, start - tail_offset), last - tail_offset)
      end

    if start < tail_offset do
      Trie.slice(trie, start, Kernel.min(last, tail_offset - 1), level, acc)
    else
      acc
    end
  end

  def slice(small(_size, tail), start, last) do
    Tail.slice(tail, start, last)
  end

  def slice(empty_pattern(), _start, _last), do: []

  @compile {:inline, take: 2}
  @spec take(t(val), non_neg_integer) :: t(val) when val: value
  def take(vector, amount)

  def take(large(size, tail_offset, level, trie, tail) = vector, amount) do
    case amount do
      0 ->
        @empty

      too_big when too_big >= size ->
        vector

      new_size ->
        case new_size - tail_offset do
          tail_size when tail_size > 0 ->
            new_tail = Node.take(tail, tail_size)
            large(new_size, tail_offset, level, trie, new_tail)

          _ ->
            case Trie.take(trie, level, new_size) do
              {:small, new_tail} ->
                small(new_size, new_tail)

              {:large, new_trie, new_level, new_tail} ->
                large(new_size, get_tail_offset(new_size), new_level, new_trie, new_tail)
            end
        end
    end
  end

  def take(small(size, tail) = vector, amount) do
    case amount do
      0 ->
        @empty

      too_big when too_big >= size ->
        vector

      new_size ->
        new_tail = Node.take(tail, new_size)
        small(new_size, new_tail)
    end
  end

  def take(empty_pattern(), _amount), do: @empty

  defp get_tail_offset(size) do
    size - C.radix_rem(size - 1) - 1
  end

  @spec with_index(t(val), integer) :: t({val, integer}) when val: value
  def with_index(vector, offset)

  def with_index(large(size, tail_offset, level, trie, tail), offset) do
    new_trie = Trie.with_index(trie, level, offset)
    new_tail = Tail.partial_with_index(tail, size - tail_offset, offset + tail_offset)

    large(size, tail_offset, level, new_trie, new_tail)
  end

  def with_index(small(size, tail), offset) do
    new_tail = Tail.partial_with_index(tail, size, offset)
    small(size, new_tail)
  end

  def with_index(empty_pattern(), _offset), do: @empty

  def with_index(vector, offset, fun)

  def with_index(large(size, tail_offset, level, trie, tail), offset, fun) do
    new_trie = Trie.with_index(trie, level, offset, fun)
    new_tail = Tail.partial_with_index(tail, size - tail_offset, offset + tail_offset, fun)

    large(size, tail_offset, level, new_trie, new_tail)
  end

  def with_index(small(size, tail), offset, fun) do
    new_tail = Tail.partial_with_index(tail, size, offset, fun)
    small(size, new_tail)
  end

  def with_index(empty_pattern(), _offset, _fun), do: @empty

  @compile {:inline, random: 1}
  def random(empty_pattern()) do
    raise A.Vector.EmptyError
  end

  def random(vector) do
    index = :rand.uniform(size(vector)) - 1
    fetch_positive!(vector, index)
  end

  def take_random(empty_pattern(), _amount), do: @empty
  def take_random(_vector, 0), do: @empty

  def take_random(vector, 1) do
    picked = random(vector)
    small(1, unquote(C.var(picked) |> C.value_with_nils() |> C.array()))
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

  def scan(
        large(size, tail_offset, level, trie, tail),
        acc,
        fun
      ) do
    {new_trie, acc} = Trie.scan(trie, level, acc, fun)
    new_tail = Tail.partial_scan(tail, size - tail_offset, acc, fun)
    large(size, tail_offset, level, new_trie, new_tail)
  end

  def scan(small(size, tail), acc, fun) do
    new_tail = Tail.partial_scan(tail, size, acc, fun)
    small(size, new_tail)
  end

  def scan(empty_pattern(), _acc, _fun), do: @empty

  def map_reduce(
        large(size, tail_offset, level, trie, tail),
        acc,
        fun
      ) do
    {new_trie, acc} = Trie.map_reduce(trie, level, acc, fun)
    {new_tail, acc} = Tail.partial_map_reduce(tail, size - tail_offset, acc, fun)
    new_raw = large(size, tail_offset, level, new_trie, new_tail)
    {new_raw, acc}
  end

  def map_reduce(small(size, tail), acc, fun) do
    {new_tail, acc} = Tail.partial_map_reduce(tail, size, acc, fun)
    new_raw = small(size, new_tail)
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

  defp do_zip(
         large(size, tail_offset, level, trie1, tail1),
         large(size, tail_offset, level, trie2, tail2)
       ) do
    new_tail = Tail.partial_zip(tail1, tail2, size - tail_offset)
    new_trie = Trie.zip(trie1, trie2, level)
    large(size, tail_offset, level, new_trie, new_tail)
  end

  defp do_zip(small(size, tail1), small(size, tail2)) do
    new_tail = Tail.partial_zip(tail1, tail2, size)
    small(size, new_tail)
  end

  defp do_zip(empty_pattern(), empty_pattern()), do: @empty

  @spec unzip(t({val1, val2})) :: {t(val1), t(val2)} when val1: value, val2: value
  def unzip(large(size, tail_offset, level, trie, tail)) do
    {tail1, tail2} = Tail.partial_unzip(tail, size - tail_offset)
    {trie1, trie2} = Trie.unzip(trie, level)

    {
      large(size, tail_offset, level, trie1, tail1),
      large(size, tail_offset, level, trie2, tail2)
    }
  end

  def unzip(small(size, tail)) do
    {tail1, tail2} = Tail.partial_unzip(tail, size)
    {small(size, tail1), small(size, tail2)}
  end

  def unzip(empty_pattern()), do: {@empty, @empty}
end
