defmodule A.Vector.Raw do
  @moduledoc false

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

  @spec new(Enumerable.t()) :: t()
  def new(enumerable) do
    enumerable
    |> A.FastEnum.to_list()
    |> from_list()
  end

  @spec new(Enumerable.t(), (v1 -> v2)) :: t(v2) when v1: value, v2: value
  def new(enumerable, fun) do
    enumerable
    |> A.FastEnum.to_list()
    |> from_mapped_list(fun)
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

  def append_many(large(size, tail_offset, level, trie, tail), list) do
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

  def append_many(small(size, tail), list) do
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

  def append_many(empty_pattern(), list) do
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

  @compile {:inline, fetch_positive: 2}
  @spec fetch_positive(t(val), non_neg_integer) :: {:ok, val} | :error when val: value
  def fetch_positive(large(size, tail_offset, shift, trie, tail), index) do
    cond do
      index < tail_offset -> {:ok, Trie.lookup(trie, index, shift)}
      index >= size -> :error
      true -> {:ok, elem(tail, index - tail_offset)}
    end
  end

  def fetch_positive(small(size, tail), index) do
    if index >= size do
      :error
    else
      {:ok, elem(tail, index)}
    end
  end

  def fetch_positive(empty_pattern(), _index) do
    :error
  end

  @compile {:inline, fetch_any: 2}
  @spec fetch_any(t(val), integer) :: {:ok, val} | :error when val: value
  def fetch_any(vector, index) when index >= 0 do
    fetch_positive(vector, index)
  end

  def fetch_any(vector, index) do
    case size(vector) + index do
      negative when negative < 0 -> :error
      positive -> fetch_positive(vector, positive)
    end
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
    Trie.first(trie, shift)
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

  @spec replace_positive(t(val), non_neg_integer, val) :: {:ok, val} | :error when val: value
  def replace_positive(vector, index, value)

  def replace_positive(large(size, tail_offset, level, trie, tail), index, value) do
    cond do
      index < tail_offset ->
        new_trie = Trie.replace(trie, index, level, value)
        {:ok, large(size, tail_offset, level, new_trie, tail)}

      index >= size ->
        :error

      true ->
        new_tail = put_elem(tail, index - tail_offset, value)
        {:ok, large(size, tail_offset, level, trie, new_tail)}
    end
  end

  def replace_positive(small(size, tail), index, value) do
    if index >= size do
      :error
    else
      new_tail = put_elem(tail, index, value)
      {:ok, small(size, new_tail)}
    end
  end

  def replace_positive(empty_pattern(), _index, _value) do
    :error
  end

  @spec replace_any(t(val), integer, val) :: {:ok, t(val)} | :error when val: value
  def replace_any(vector, index, value) when index >= 0 do
    replace_positive(vector, index, value)
  end

  def replace_any(vector, index, value) do
    case size(vector) + index do
      negative when negative < 0 -> :error
      positive -> replace_positive(vector, positive, value)
    end
  end

  @spec update_positive(t(val), non_neg_integer, (val -> val)) :: {:ok, val} | :error
        when val: value
  def update_positive(vector, index, fun)

  def update_positive(large(size, tail_offset, level, trie, tail), index, fun) do
    cond do
      index < tail_offset ->
        new_trie = Trie.update(trie, index, level, fun)
        {:ok, large(size, tail_offset, level, new_trie, tail)}

      index >= size ->
        :error

      true ->
        new_tail = Node.update_at(tail, index - tail_offset, fun)
        {:ok, large(size, tail_offset, level, trie, new_tail)}
    end
  end

  def update_positive(small(size, tail), index, fun) do
    if index >= size do
      :error
    else
      new_tail = Node.update_at(tail, index, fun)
      {:ok, small(size, new_tail)}
    end
  end

  def update_positive(empty_pattern(), _index, _fun) do
    :error
  end

  @spec update_any(t(val), integer, (val -> val)) :: {:ok, t(val)} | :error when val: value
  def update_any(vector, index, fun) when index >= 0 do
    update_positive(vector, index, fun)
  end

  def update_any(vector, index, fun) do
    case size(vector) + index do
      negative when negative < 0 -> :error
      positive -> update_positive(vector, positive, fun)
    end
  end

  def get_and_update_any(vector, index, fun) when index >= 0 do
    get_and_update_positive(vector, index, fun)
  end

  def get_and_update_any(vector, index, fun) do
    case size(vector) + index do
      negative when negative < 0 ->
        get_and_update_missing_index(vector, fun)

      positive ->
        get_and_update_positive(vector, positive, fun)
    end
  end

  defp get_and_update_positive(vector, index, fun) do
    case fetch_positive(vector, index) do
      {:ok, value} ->
        case fun.(value) do
          {returned, new_value} ->
            {:ok, new_vector} = replace_positive(vector, index, new_value)
            {returned, new_vector}

          :pop ->
            {value, delete_positive(vector, index, size(vector))}

          other ->
            get_and_update_error(other)
        end

      :error ->
        get_and_update_missing_index(vector, fun)
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
        {new_tail, new_trie, new_level} = Trie.pop_leaf(trie, level)

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

  # Note: deletion is not efficient
  # Could still be implemented a bit nicer to reuse leaves when possible
  def pop_any(vector, index) do
    size = size(vector)

    cond do
      index >= size or index < -size -> :error
      index >= 0 -> pop_exisiting(vector, index, size)
      index -> pop_exisiting(vector, size + index, size)
    end
  end

  defp pop_exisiting(vector, index, size) do
    case index + 1 do
      ^size ->
        pop_last(vector)

      _ ->
        left = take(vector, index)
        [popped | right] = slice(vector, index, size - 1)
        new_vector = append_many(left, right)
        {popped, new_vector}
    end
  end

  def delete_any(vector, index) do
    size = size(vector)

    cond do
      index >= size or index < -size -> :error
      index >= 0 -> {:ok, delete_positive(vector, index, size)}
      index -> {:ok, delete_positive(vector, size + index, size)}
    end
  end

  defp delete_positive(vector, index, size) do
    case index + 1 do
      ^size ->
        {_last, popped} = pop_last(vector)
        popped

      amount ->
        left = take(vector, index)
        right = slice(vector, amount, size - 1)
        append_many(left, right)
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

  @spec to_reverse_list(t(val)) :: [val] when val: value
  def to_reverse_list(large(size, tail_offset, shift, trie, tail)) do
    acc = Trie.to_reverse_list(trie, shift, [])
    Tail.partial_reverse(tail, size - tail_offset) ++ acc
  end

  def to_reverse_list(small(size, tail)) do
    Tail.partial_reverse(tail, size)
  end

  def to_reverse_list(empty_pattern()) do
    []
  end

  @spec foldl(t(val), acc, (val, acc -> acc)) :: acc when val: value, acc: term
  def foldl(vector, acc, fun)

  def foldl(large(size, tail_offset, level, trie, tail), acc, fun) do
    new_acc = Trie.foldl(trie, level, acc, fun)

    Tail.partial_to_list(tail, size - tail_offset)
    |> List.foldl(new_acc, fun)
  end

  def foldl(small(size, tail), acc, fun) do
    Tail.partial_to_list(tail, size)
    |> List.foldl(acc, fun)
  end

  def foldl(empty_pattern(), acc, _fun), do: acc

  @spec foldr(t(val), acc, (val, acc -> acc)) :: acc when val: value, acc: term
  def foldr(vector, acc, fun)

  def foldr(large(size, tail_offset, level, trie, tail), acc, fun) do
    new_acc =
      Tail.partial_to_list(tail, size - tail_offset)
      |> List.foldr(acc, fun)

    Trie.foldr(trie, level, new_acc, fun)
  end

  def foldr(small(size, tail), acc, fun) do
    Tail.partial_to_list(tail, size)
    |> List.foldr(acc, fun)
  end

  def foldr(empty_pattern(), acc, _fun), do: acc

  @spec each(t(val), (val -> term)) :: :ok when val: value
  def each(vector, fun)

  def each(large(size, tail_offset, level, trie, tail), fun) do
    Trie.each(trie, level, fun)

    Tail.partial_to_list(tail, size - tail_offset)
    |> Enum.each(fun)
  end

  def each(small(size, tail), fun) do
    Tail.partial_to_list(tail, size)
    |> Enum.each(fun)
  end

  def each(empty_pattern(), _fun), do: :ok

  @spec sum(t(number)) :: number
  def sum(vector)

  def sum(large(size, tail_offset, level, trie, tail)) do
    acc = Trie.sum(trie, level, 0)
    Tail.partial_sum(tail, size - tail_offset, acc)
  end

  def sum(small(size, tail)) do
    Tail.partial_sum(tail, size, 0)
  end

  def sum(empty_pattern()), do: 0

  @spec product(t(number)) :: number
  def product(vector)

  def product(large(size, tail_offset, level, trie, tail)) do
    acc = Trie.product(trie, level, 1)
    Tail.partial_product(tail, size - tail_offset, acc)
  end

  def product(small(size, tail)) do
    Tail.partial_product(tail, size, 1)
  end

  def product(empty_pattern()), do: 1

  @spec intersperse(t(val), sep) :: [val | sep] when val: value, sep: value
  def intersperse(vector, separator)

  def intersperse(large(size, tail_offset, level, trie, tail), separator) do
    acc = Tail.partial_intersperse(tail, size - tail_offset, separator)

    Trie.intersperse(trie, level, separator, acc)
  end

  def intersperse(small(size, tail), separator) do
    Tail.partial_intersperse(tail, size, separator)
  end

  def intersperse(empty_pattern(), _separator), do: []

  @spec join_as_iodata(t(val), String.t()) :: iodata when val: String.Chars.t()
  def join_as_iodata(vector, joiner)

  def join_as_iodata(large(size, tail_offset, level, trie, tail), joiner) do
    acc = Tail.partial_join_as_iodata(tail, size - tail_offset, joiner)

    Trie.join(trie, level, joiner, acc)
  end

  def join_as_iodata(small(size, tail), joiner) do
    Tail.partial_join_as_iodata(tail, size, joiner)
  end

  def join_as_iodata(empty_pattern(), _separator), do: []

  def max(empty_pattern()) do
    raise A.Vector.EmptyError
  end

  def max(vector) do
    # TODO write optimized version
    foldl(vector, last(vector, nil), fn val, acc ->
      if val > acc do
        val
      else
        acc
      end
    end)
  end

  def min(empty_pattern()) do
    raise A.Vector.EmptyError
  end

  def min(vector) do
    # TODO write optimized version
    foldl(vector, last(vector, nil), fn val, acc ->
      if val < acc do
        val
      else
        acc
      end
    end)
  end

  def member?(large(size, tail_offset, level, trie, tail), value) do
    Trie.member?(trie, level, value) or Tail.partial_member?(tail, size - tail_offset, value)
  end

  def member?(small(size, tail), value) do
    Tail.partial_member?(tail, size, value)
  end

  def member?(empty_pattern(), _value), do: false

  @spec any?(t()) :: boolean()

  def any?(large(size, tail_offset, level, trie, tail)) do
    (Trie.any?(trie, level) || Tail.partial_any?(tail, size - tail_offset))
    |> as_boolean()
  end

  def any?(small(size, tail)) do
    Tail.partial_any?(tail, size) |> as_boolean()
  end

  def any?(empty_pattern()), do: false

  @spec any?(t(val), (val -> as_boolean(term))) :: boolean() when val: value

  def any?(large(size, tail_offset, level, trie, tail), fun) do
    (Trie.any?(trie, level, fun) || Tail.partial_any?(tail, size - tail_offset, fun))
    |> as_boolean()
  end

  def any?(small(size, tail), fun) do
    Tail.partial_any?(tail, size, fun) |> as_boolean()
  end

  def any?(empty_pattern(), _fun), do: false

  @spec all?(t()) :: boolean()

  def all?(large(size, tail_offset, level, trie, tail)) do
    (Trie.all?(trie, level) && Tail.partial_all?(tail, size - tail_offset))
    |> as_boolean()
  end

  def all?(small(size, tail)) do
    Tail.partial_all?(tail, size) |> as_boolean()
  end

  def all?(empty_pattern()), do: true

  @spec all?(t(val), (val -> as_boolean(term))) :: boolean() when val: value

  def all?(large(size, tail_offset, level, trie, tail), fun) do
    (Trie.all?(trie, level, fun) && Tail.partial_all?(tail, size - tail_offset, fun))
    |> as_boolean()
  end

  def all?(small(size, tail), fun) do
    Tail.partial_all?(tail, size, fun) |> as_boolean()
  end

  def all?(empty_pattern(), _fun), do: true

  defp as_boolean(value) do
    if value do
      true
    else
      false
    end
  end

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

  @spec filter(t(val), (val -> as_boolean(term))) :: t(val) when val: value
  def filter(vector, fun) do
    # TODO optimize
    vector
    |> foldr([], fn el, acc ->
      if fun.(el) do
        [el | acc]
      else
        acc
      end
    end)
    |> from_list()
  end

  @spec reject(t(val), (val -> as_boolean(term))) :: t(val) when val: value
  def reject(vector, fun) do
    # TODO optimize
    filter(vector, &(!fun.(&1)))
  end

  @compile {:inline, slice: 3}
  @spec slice(t(val), non_neg_integer, non_neg_integer) :: [val] when val: value
  def slice(vector, start, last)

  def slice(large(_size, tail_offset, level, trie, tail), start, last) do
    acc =
      if last < tail_offset do
        []
      else
        Tail.slice(tail, max(0, start - tail_offset), last - tail_offset)
      end

    if start < tail_offset do
      Trie.slice(trie, start, min(last, tail_offset - 1), level, acc)
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

  def with_index(empty_pattern(), _fun), do: @empty

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
end
