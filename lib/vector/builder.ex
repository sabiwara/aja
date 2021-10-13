defmodule Aja.Vector.Builder do
  @moduledoc false

  alias Aja.Vector.{Tail, Node}
  require Aja.Vector.CodeGen, as: C

  def from_list(list) when is_list(list) do
    do_concat_list([], list)
  end

  def concat_list(builder, list) when is_list(builder) and is_list(list) do
    do_concat_list(builder, list)
  end

  defp do_concat_list(builder, unquote(C.list_with_rest(C.var(rest)))) when rest != [] do
    leaf = unquote(C.array())

    builder
    |> append_node(leaf)
    |> do_concat_list(rest)
  end

  defp do_concat_list(builder, rest) do
    {builder, length(rest), Tail.partial_from_list(rest)}
  end

  def map_from_list(list, fun) when is_list(list) and is_function(fun, 1) do
    concat_map_list([], list, fun)
  end

  defp concat_map_list(builder, unquote(C.list_with_rest(C.var(rest))), fun) when rest != [] do
    leaf = unquote(C.arguments() |> Enum.map(C.apply_mapper(C.var(fun))) |> C.array())

    builder
    |> append_node(leaf)
    |> concat_map_list(rest, fun)
  end

  defp concat_map_list(builder, rest, fun) do
    {builder, length(rest), Enum.map(rest, fun) |> Tail.partial_from_list()}
  end

  def append_nodes(builder, []), do: builder

  def append_nodes(builder, [node | nodes]) do
    builder
    |> append_node(node)
    |> append_nodes(nodes)
  end

  def append_nodes_with_offset(builder, [node], offset, tail, tail_size) do
    shifted_tail = Node.shift(tail, -tail_size)
    last_node = Node.from_offset_nodes(node, shifted_tail, offset)

    case tail_size - offset do
      new_tail_size when new_tail_size > 0 ->
        new_tail =
          shifted_tail
          |> Node.from_offset_nodes(unquote(C.fill_with([], nil) |> C.array()), offset)
          |> Node.shift(new_tail_size)

        builder
        |> append_node(last_node)
        |> append_tail(new_tail, new_tail_size)

      tail_size_complement ->
        new_tail = Node.shift(last_node, tail_size_complement)
        append_tail(builder, new_tail, C.branch_factor() + tail_size_complement)
    end
  end

  def append_nodes_with_offset(builder, [node1 | nodes = [node2 | _]], offset, tail, tail_size) do
    node = Node.from_offset_nodes(node1, node2, offset)

    builder
    |> append_node(node)
    |> append_nodes_with_offset(nodes, offset, tail, tail_size)
  end

  def append_node(builder, node)

  def append_node([], node), do: [[node]]

  def append_node([unquote(C.arguments() |> tl()) | tries], unquote(C.arguments() |> hd())) do
    trie_node = unquote(C.reversed_arguments() |> C.array())
    [[] | append_node(tries, trie_node)]
  end

  def append_node([trie | tries], node) do
    [[node | trie] | tries]
  end

  def append_tail(builder, tail, tail_size) do
    {builder, tail_size, tail}
  end

  def to_trie([[] | tries], level) do
    to_trie(tries, C.incr_level(level))
  end

  def to_trie([[dense_trie]], level) do
    {level, dense_trie}
  end

  def to_trie(sparse_trie, level) do
    to_sparse_trie(sparse_trie, level)
  end

  defp to_sparse_trie([children | rest], level) do
    node = Node.from_incomplete_reverse_list(children)

    case rest do
      [] -> {C.incr_level(level), node}
      [head | tail] -> to_sparse_trie([[node | head] | tail], C.incr_level(level))
    end
  end

  def from_trie(trie, level, index) do
    case :erlang.bsr(index, level) do
      C.branch_factor() ->
        prepend_single_builder([[trie]], level)

      _ ->
        do_from_trie(trie, level, index, [])
    end
  end

  defp do_from_trie(trie, level = C.bits(), index, acc) do
    current_index = C.radix_search(index, level)
    [subtries_list(trie, 1, current_index + 1, []) | acc]
  end

  defp do_from_trie(trie, level, index, acc) do
    current_index = C.radix_search(index, level)
    child = elem(trie, current_index)
    new_acc = [subtries_list(trie, 1, current_index + 1, []) | acc]
    do_from_trie(child, C.decr_level(level), index, new_acc)
  end

  defp prepend_single_builder(list, _level = 0), do: list

  defp prepend_single_builder(list, level) do
    prepend_single_builder([[] | list], C.decr_level(level))
  end

  defp subtries_list(_trie, _index = until, until, acc), do: acc

  defp subtries_list(trie, index, until, acc) do
    new_acc = [:erlang.element(index, trie) | acc]
    subtries_list(trie, index + 1, until, new_acc)
  end

  @compile {:inline, tail_offset: 3}
  def tail_offset([], _level, acc), do: acc

  def tail_offset([trie | tries], level, acc) do
    trie_size = length(trie) |> Bitwise.bsl(level)
    tail_offset(tries, C.incr_level(level), acc + trie_size)
  end
end
