defmodule A.Vector.Trie do
  @moduledoc false

  alias A.Vector.CodeGen, as: C
  require C

  import Bitwise

  alias A.Vector.{Node, Tail}

  @type value :: term
  @type leaf(value) :: Node.t(value)
  @type t(value) :: Node.t(t(value) | value)

  # BUILD TRIE

  @spec group_leaves([val]) :: {non_neg_integer, non_neg_integer, [leaf(val)], Tail.t(val)}
        when val: value
  def group_leaves(list) do
    do_group_leaves(list, [], 0)
  end

  @compile {:inline, do_group_leaves: 3}
  defp do_group_leaves(unquote(C.list_with_rest(C.var(rest))), acc, count) when rest != [] do
    do_group_leaves(
      rest,
      [unquote(C.array()) | acc],
      count + C.branch_factor()
    )
  end

  defp do_group_leaves(rest, acc, count) do
    last = Node.from_incomplete_list(rest)
    {count + length(rest), count, :lists.reverse(acc), last}
  end

  @spec group_map_leaves([v1], (v1 -> v2)) ::
          {non_neg_integer, non_neg_integer, [leaf(v2)], Tail.t(v2)}
        when v1: value, v2: value
  def group_map_leaves(list, fun) do
    do_group_map_leaves(list, fun, [], 0)
  end

  @compile {:inline, do_group_map_leaves: 4}
  defp do_group_map_leaves(unquote(C.list_with_rest(C.var(rest))), fun, acc, count)
       when rest != [] do
    new_leaf =
      unquote(
        C.arguments()
        |> Enum.map(C.apply_mapper(C.var(fun)))
        |> C.array()
      )

    do_group_map_leaves(rest, fun, [new_leaf | acc], count + C.branch_factor())
  end

  defp do_group_map_leaves(rest, fun, acc, count) do
    last =
      rest
      |> Enum.map(fun)
      |> Node.from_incomplete_list()

    {count + length(rest), count, :lists.reverse(acc), last}
  end

  def group_leaves_ast(list) do
    do_group_leaves_ast(list, [], 0)
  end

  defp do_group_leaves_ast(unquote(C.list_with_rest(C.var(rest))), acc, count) when rest != [] do
    do_group_leaves_ast(rest, [unquote(C.array_ast()) | acc], count + C.branch_factor())
  end

  defp do_group_leaves_ast(rest, acc, count) do
    last = Node.ast_from_incomplete_list(rest)
    {count + length(rest), count, :lists.reverse(acc), last}
  end

  def duplicate(value, n) do
    div = C.radix_div(n)
    {level, acc} = do_duplicate(value, div, 0, [])

    case 1 <<< level do
      ^n ->
        [{1, trie}] = acc
        {C.decr_level(level), trie}

      _ ->
        [{count, node} | rest] = acc
        base_trie = Tail.partial_duplicate(node, count)

        trie = duplicate_rest(base_trie, rest, count)

        {level, trie}
    end
  end

  defp do_duplicate(_node, _n = 0, level, acc) do
    {level, acc}
  end

  defp do_duplicate(node, n, level, acc) do
    new_node = Node.duplicate(node)
    rem = C.radix_rem(n)

    div = C.radix_div(n)

    new_acc =
      case {rem, acc} do
        {0, []} -> []
        _ -> [{rem, new_node} | acc]
      end

    do_duplicate(new_node, div, C.incr_level(level), new_acc)
  end

  defp duplicate_rest(trie, _rest = [], _count) do
    trie
  end

  defp duplicate_rest(node, [{child_count, child_node} | rest], count) do
    child_base =
      case child_count do
        0 -> Node.duplicate(nil) |> Tail.partial_duplicate(1)
        _ -> Tail.partial_duplicate(child_node, child_count)
      end

    child = duplicate_rest(child_base, rest, child_count)

    put_elem(node, count, child)
  end

  @spec from_leaves([leaf(val)]) :: nil | {non_neg_integer, t(val)} when val: value
  def from_leaves(leaves)

  def from_leaves([]), do: nil
  def from_leaves([leaf]), do: {0, leaf}
  def from_leaves(leaves), do: do_from_nodes(leaves, C.bits())

  @compile {:inline, do_from_nodes: 2}
  defp do_from_nodes(nodes, level)

  defp do_from_nodes(unquote(C.list_with_rest(C.var(rest))), level) when rest != [] do
    nodes = [unquote(C.array()) | group_nodes(rest)]
    do_from_nodes(nodes, C.incr_level(level))
  end

  defp do_from_nodes(nodes, level) do
    {level, Node.from_incomplete_list(nodes)}
  end

  defp group_nodes(nodes)

  defp group_nodes(unquote(C.list_with_rest(C.var(rest)))) when rest != [] do
    [unquote(C.array()) | group_nodes(rest)]
  end

  defp group_nodes(nodes) do
    [Node.from_incomplete_list(nodes)]
  end

  @spec from_ast_leaves([leaf(val)]) :: nil | {non_neg_integer, t(val)} when val: value
  def from_ast_leaves(leaves)

  def from_ast_leaves([]), do: nil
  def from_ast_leaves([leaf]), do: {0, leaf}
  def from_ast_leaves(leaves), do: do_from_ast_nodes(leaves, C.bits())

  defp do_from_ast_nodes(nodes, level)

  defp do_from_ast_nodes(unquote(C.list_with_rest(C.var(rest))), level) when rest != [] do
    nodes = [unquote(C.array_ast()) | group_ast_nodes(rest)]
    do_from_ast_nodes(nodes, C.incr_level(level))
  end

  defp do_from_ast_nodes(nodes, level) do
    {level, Node.ast_from_incomplete_list(nodes)}
  end

  defp group_ast_nodes(nodes)

  defp group_ast_nodes(unquote(C.list_with_rest(C.var(rest)))) when rest != [] do
    [unquote(C.array_ast()) | group_ast_nodes(rest)]
  end

  defp group_ast_nodes(nodes) do
    [Node.ast_from_incomplete_list(nodes)]
  end

  @compile {:inline, append_leaf: 4}
  def append_leaf(trie, level, index, leaf)

  def append_leaf(trie, _level = 0, _index, leaf) do
    {
      unquote(C.var([trie, leaf]) |> C.fill_with(nil) |> C.array()),
      C.bits()
    }
  end

  def append_leaf(trie, level, index, leaf) do
    case index >>> level do
      C.branch_factor() ->
        new_branch = build_single_branch(leaf, level)

        {
          unquote(C.var([trie, new_branch]) |> C.fill_with(nil) |> C.array()),
          C.incr_level(level)
        }

      _ ->
        new_trie = append_leaf_to_existing(trie, level, index, leaf)
        {new_trie, level}
    end
  end

  defp append_leaf_to_existing(nil, level, _index, leaf) do
    build_single_branch(leaf, level)
  end

  defp append_leaf_to_existing(trie, _level = C.bits(), index, leaf) do
    put_elem(trie, C.radix_search(index, C.bits()), leaf)
  end

  defp append_leaf_to_existing(trie, level, index, leaf) do
    current_index = C.radix_search(index, level)
    child = elem(trie, current_index)

    new_child = append_leaf_to_existing(child, C.decr_level(level), index, leaf)

    put_elem(trie, current_index, new_child)
  end

  defp build_single_branch(leaf, _level = 0) do
    leaf
  end

  defp build_single_branch(leaf, level) do
    child = build_single_branch(leaf, C.decr_level(level))
    unquote(C.var(child) |> C.value_with_nils() |> C.array())
  end

  @compile {:inline, append_leaves: 4}
  def append_leaves(trie, level, index, leaves)

  def append_leaves(trie, level, _index, []), do: {trie, level}

  def append_leaves(trie, level, index, [leaf | rest]) do
    {new_trie, new_level} = append_leaf(trie, level, index, leaf)
    append_leaves(new_trie, new_level, index + C.branch_factor(), rest)
  end

  # ACCESS

  @compile {:inline, lookup: 3}
  def lookup(trie, index, level)

  def lookup(leaf, index, _level = 0) do
    elem(leaf, C.radix_rem(index))
  end

  def lookup(trie, index, level) do
    current_index = C.radix_search(index, level)
    child = elem(trie, current_index)
    lookup(child, index, C.decr_level(level))
  end

  def replace(trie, index, level, value)

  def replace(leaf, index, _level = 0, value) do
    current_index = C.radix_rem(index)
    put_elem(leaf, current_index, value)
  end

  def replace(trie, index, level, value) do
    erl_index = C.radix_search(index, level) + 1
    child = :erlang.element(erl_index, trie)

    new_child = replace(child, index, C.decr_level(level), value)

    :erlang.setelement(erl_index, trie, new_child)
  end

  def update(trie, index, level, fun)

  def update(leaf, index, _level = 0, fun) do
    erl_index = C.radix_rem(index) + 1
    value = :erlang.element(erl_index, leaf)
    :erlang.setelement(erl_index, leaf, fun.(value))
  end

  def update(trie, index, level, fun) do
    erl_index = C.radix_search(index, level) + 1
    child = :erlang.element(erl_index, trie)

    new_child = update(child, index, C.decr_level(level), fun)

    :erlang.setelement(erl_index, trie, new_child)
  end

  # POP LEAF

  def pop_leaf(trie, level) do
    {popped, new} = do_nested_pop_leaf(trie, level)

    case elem(new, 1) do
      nil -> {popped, elem(new, 0), C.decr_level(level)}
      _ -> {popped, new, level}
    end
  end

  defp do_nested_pop_leaf(leaves, _level = C.bits()) do
    do_pop_leaf(leaves)
  end

  defp do_nested_pop_leaf(unquote(C.array_with_nils(1)), level) do
    {popped, trie} = do_nested_pop_leaf(unquote(C.argument_at(0)), C.decr_level(level))

    case trie do
      nil ->
        {popped, nil}

      _ ->
        new_trie = unquote(C.var(trie) |> C.value_with_nils() |> C.array())
        {popped, new_trie}
    end
  end

  for i <- C.range(), i > 1 do
    defp do_nested_pop_leaf(unquote(C.array_with_nils(i)), level) do
      {popped, unquote(C.argument_at(i - 1))} =
        do_nested_pop_leaf(unquote(C.argument_at(i - 1)), C.decr_level(level))

      new_trie = unquote(C.array_with_nils(i))
      {popped, new_trie}
    end
  end

  defp do_pop_leaf(unquote(C.array_with_nils(1))) do
    {unquote(C.argument_at(0)), nil}
  end

  for i <- C.range(), i > 1 do
    defp do_pop_leaf(unquote(C.array_with_nils(i))) do
      {unquote(C.argument_at(i - 1)), unquote(C.array_with_nils(i - 1))}
    end
  end

  # LOOPS

  def to_list(trie, level, acc)

  # def to_list({arg1, arg2, arg3, arg4}, _level = 0, acc) do
  #   [arg1, arg2, arg3, arg4 | acc]
  # end
  def to_list(unquote(C.array()), _level = 0, acc) do
    unquote(C.list_with_rest(C.var(acc)))
  end

  # def to_list({arg1, arg2, nil, nil}, level, acc) do
  #   child_level = level - bits
  #   to_list(arg1, child_level, to_list(arg2, child_level, acc))
  # end
  for i <- C.range() do
    def to_list(unquote(C.array_with_nils(i)), level, acc) do
      child_level = C.decr_level(level)

      unquote(
        C.reversed_arguments(i)
        |> Enum.reduce(C.var(acc), fn arg, acc ->
          quote do
            to_list(unquote(arg), var!(child_level), unquote(acc))
          end
        end)
      )
    end
  end

  def to_reverse_list(trie, level, acc)

  def to_reverse_list(_trie = nil, _level, acc), do: acc

  # def to_reverse_list({arg1, arg2, arg3, arg4}, _level = 0, acc) do
  #   [arg4, arg3, arg2, arg1 | acc]
  # end
  def to_reverse_list(unquote(C.array()), _level = 0, acc) do
    unquote(C.reversed_arguments() |> C.list_with_rest(C.var(acc)))
  end

  # def to_reverse_list({arg1, arg2, arg3, arg4}, level, acc) do
  #   child_level = level - bits
  #   to_reverse_list(arg4, child_level,
  #     to_reverse_list(arg3, child_level,
  #       to_reverse_list(arg2, child_level,
  #         to_reverse_list(arg1, child_level, acc)
  #       )
  #     )
  #   )
  # end
  def to_reverse_list(unquote(C.array()), level, acc) do
    child_level = C.decr_level(level)

    unquote(
      C.arguments()
      |> Enum.reduce(C.var(acc), fn arg, acc ->
        quote do
          to_reverse_list(unquote(arg), var!(child_level), unquote(acc))
        end
      end)
    )
  end

  def member?(trie, level, value)

  # def member?({arg1, arg2, arg3, arg4}, _level = 0, value) do
  #   case value do
  #     ^arg1 -> true
  #     ^arg2 -> true
  #     ^arg3 -> true
  #     ^arg4 -> true
  #     _ -> false
  #   end
  # end
  def member?(unquote(C.array()), _level = 0, value) do
    case value do
      unquote(
        Enum.flat_map(
          C.arguments(),
          fn arg ->
            quote do
              ^unquote(arg) -> true
            end
          end
        ) ++
          quote do
            _ -> false
          end
      )
    end
  end

  # def member?({arg1, arg2, arg3, arg4}, level, value) do
  #   child_level = level - bits
  #   cond do
  #     member?(arg1, child_level, value) -> true
  #     arg2 === null -> false
  #     member?(arg2, child_level, value) -> true
  #     arg3 === null -> false
  #     member?(arg3, child_level, value) -> true
  #     arg4 === null -> false
  #     member?(arg4, child_level, value) -> true
  #     true -> false
  #   end
  # end
  def member?(unquote(C.array()), level, value) do
    child_level = C.decr_level(level)

    cond do
      unquote(
        C.any_cond_trie(fn arg ->
          quote do
            member?(unquote(arg), var!(child_level), var!(value))
          end
        end)
      )
    end
  end

  def any?(trie, level)

  # def any?({arg1, arg2, arg3, arg4}, _level = 0) do
  #   arg1 || arg2 || arg3 || arg4
  # end
  def any?(unquote(C.array()), _level = 0) do
    unquote(C.arguments() |> Enum.reduce(&C.or_reducer/2))
  end

  # def any?({arg1, arg2, arg3, arg4}, level) do
  #   child_level = level - bits
  #   cond do
  #     any?(arg1, child_level) -> true
  #     arg2 === null -> false
  #     any?(arg2, child_level) -> true
  #     arg3 === null -> false
  #     any?(arg3, child_level) -> true
  #     arg4 === null -> false
  #     any?(arg4, child_level) -> true
  #     true -> false
  #   end
  # end
  def any?(unquote(C.array()), level) do
    child_level = C.decr_level(level)

    cond do
      unquote(
        C.any_cond_trie(fn arg ->
          quote do
            any?(unquote(arg), var!(child_level))
          end
        end)
      )
    end
  end

  def any?(trie, level, fun)

  # def any?({arg1, arg2, arg3, arg4}, _level = 0, fun) do
  #   fun.(arg1) || fun.(arg2) || fun.(arg3) || fun.(arg4)
  # end
  def any?(unquote(C.array()), _level = 0, fun) do
    unquote(
      C.arguments()
      |> Enum.map(C.apply_mapper(C.var(fun)))
      |> Enum.reduce(&C.or_reducer/2)
    )
  end

  # def any?({arg1, arg2, arg3, arg4}, level, fun) do
  #   child_level = level - bits
  #   cond do
  #     any?(arg1, child_level, fun) -> true
  #     arg2 === null -> false
  #     any?(arg2, child_level, fun) -> true
  #     arg3 === null -> false
  #     any?(arg3, child_level, fun) -> true
  #     arg4 === null -> false
  #     any?(arg4, child_level, fun) -> true
  #     true -> false
  #   end
  # end
  def any?(unquote(C.array()), level, fun) do
    child_level = C.decr_level(level)

    cond do
      unquote(
        C.any_cond_trie(fn arg ->
          quote do
            any?(unquote(arg), var!(child_level), var!(fun))
          end
        end)
      )
    end
  end

  def all?(trie, level)

  # def all?({arg1, arg2, arg3, arg4}, _level = 0) do
  #   arg1 && arg2 && arg3 && arg4
  # end
  def all?(unquote(C.array()), _level = 0) do
    unquote(C.arguments() |> Enum.reduce(&C.and_reducer/2))
  end

  # def all?({arg1, arg2, arg3, arg4}, level) do
  #   child_level = level - bits
  #   !cond do
  #     !all?(arg1, child_level) -> true
  #     arg2 === null -> false
  #     !all?(arg2, child_level) -> true
  #     arg3 === null -> false
  #     !all?(arg3, child_level) -> true
  #     arg4 === null -> false
  #     !all?(arg4, child_level) -> true
  #     true -> false
  #   end
  # end
  def all?(unquote(C.array()), level) do
    child_level = C.decr_level(level)

    !cond do
      unquote(
        C.any_cond_trie(fn arg ->
          quote do
            !all?(unquote(arg), var!(child_level))
          end
        end)
      )
    end
  end

  def all?(trie, level, fun)

  # def all?({arg1, arg2, arg3, arg4}, _level = 0, fun) do
  #   fun.(arg1) && fun.(arg2) && fun.(arg3) && fun.(arg4)
  # end
  def all?(unquote(C.array()), _level = 0, fun) do
    unquote(
      C.arguments()
      |> Enum.map(C.apply_mapper(C.var(fun)))
      |> Enum.reduce(&C.and_reducer/2)
    )
  end

  # def all?({arg1, arg2, arg3, arg4}, level, fun) do
  #   child_level = level - bits
  #   !cond do
  #     !all?(arg1, child_level, fun) -> true
  #     arg2 === null -> false
  #     !all?(arg2, child_level, fun) -> true
  #     arg3 === null -> false
  #     !all?(arg3, child_level, fun) -> true
  #     arg4 === null -> false
  #     !all?(arg4, child_level, fun) -> true
  #     true -> false
  #   end
  # end
  def all?(unquote(C.array()), level, fun) do
    child_level = C.decr_level(level)

    !cond do
      unquote(
        C.any_cond_trie(fn arg ->
          quote do
            !all?(unquote(arg), var!(child_level), var!(fun))
          end
        end)
      )
    end
  end

  def foldl(trie, level, acc, fun)
  def foldl(_trie = nil, _level, acc, _fun), do: acc

  # def foldl({arg1, arg2, arg3, arg4}, _level = 0, acc, fun) do
  #   fun(arg1, fun(arg2, fun(arg3, fun(arg4, acc))))
  # end
  def foldl(unquote(C.array()), _level = 0, acc, fun) do
    unquote(
      C.arguments()
      |> Enum.reduce(C.var(acc), fn arg, acc ->
        quote do
          var!(fun).(unquote(arg), unquote(acc))
        end
      end)
    )
  end

  # def foldl({arg1, arg2, arg3, arg4}, level, acc, fun) do
  #   child_level = level - bits
  #   foldl(arg4, child_level,
  #     foldl(arg3, child_level,
  #       foldl(arg2, child_level,
  #         foldl(arg1, child_level, acc, fun),
  #         fun),
  #       fun),
  #     fun)
  # end
  def foldl(
        unquote(C.array()),
        level,
        acc,
        fun
      ) do
    child_level = C.decr_level(level)

    unquote(
      C.arguments()
      |> Enum.reduce(C.var(acc), fn arg, acc ->
        quote do
          foldl(unquote(arg), var!(child_level), unquote(acc), var!(fun))
        end
      end)
    )
  end

  def foldr(trie, level, acc, fun) do
    foldr_leaves(trie, level, acc, fun, &foldr_leaf/3)
  end

  # defp foldr_leaf({arg1, arg2, arg3, arg4}, fun, acc) do
  #   fun(arg1, fun(arg2, fun(arg3, fun(arg4, acc))))
  # end
  def foldr_leaf(unquote(C.array()), fun, acc) do
    unquote(
      C.reversed_arguments()
      |> Enum.reduce(C.var(acc), fn arg, acc ->
        quote do
          var!(fun).(unquote(arg), unquote(acc))
        end
      end)
    )
  end

  def filter(trie, level, fun, acc)
  def filter(_trie = nil, _level, _fun, acc), do: acc

  # def filter({arg1, arg2, arg3, arg4}, _level = 0, fun, acc) do
  #   acc = if(fun.(arg1), do: [arg1 | acc], else: acc)
  #   acc = if(fun.(arg2), do: [arg2 | acc], else: acc)
  #   acc = if(fun.(arg3), do: [arg3 | acc], else: acc)
  #   if(fun.(arg4), do: [arg4 | acc], else: acc)
  # end
  def filter(unquote(C.array()), _level = 0, fun, acc) do
    unquote(
      C.arguments()
      |> Enum.reduce(C.var(acc), fn arg, acc ->
        quote do
          acc = unquote(acc)

          if var!(fun).(unquote(arg)) do
            [unquote(arg) | acc]
          else
            acc
          end
        end
      end)
    )
  end

  # def filter({arg1, arg2, arg3, arg4}, level, fun, acc) do
  #   child_level = level - bits
  #   filter(arg4, child_level, fun,
  #     filter(arg3, child_level, fun,
  #       filter(arg2, child_level, fun,
  #         filter(arg1, child_level, fun, acc)
  #       )
  #     )
  #   )
  # end
  def filter(unquote(C.array()), level, fun, acc) do
    child_level = C.decr_level(level)

    unquote(
      C.arguments()
      |> Enum.reduce(C.var(acc), fn arg, acc ->
        quote do
          filter(unquote(arg), var!(child_level), var!(fun), unquote(acc))
        end
      end)
    )
  end

  def each(trie, level, fun)

  # def each({arg1, arg2, arg3, arg4}, _level = 0, fun) do
  #   fun.(arg1)
  #   fun.(arg2)
  #   fun.(arg3)
  #   fun.(arg4)
  #   :ok
  # end
  def each(unquote(C.array()), _level = 0, fun) do
    unquote(
      C.arguments()
      |> Enum.map(C.apply_mapper(C.var(fun)))
      |> C.block()
    )

    :ok
  end

  # def each({arg1, arg2, arg3, arg4}, level, fun) do
  #   child_level = level - bits
  #   arg1 && each(arg1, child_level, fun) &&
  #   arg2 && each(arg2, child_level, fun) &&
  #   arg3 && each(arg3, child_level, fun) &&
  #   arg4 && each(arg4, child_level, fun)
  # end
  def each(unquote(C.array()), level, fun) do
    child_level = C.decr_level(level)

    unquote(
      C.arguments()
      |> Enum.map(fn arg ->
        quote do
          unquote(arg) && each(unquote(arg), var!(child_level), var!(fun))
        end
      end)
      |> Enum.reduce(fn
        expr, acc ->
          quote do
            unquote(acc) && unquote(expr)
          end
      end)
    )

    :ok
  end

  def sum(trie, level, acc)

  def sum(_trie = nil, _level, acc), do: acc

  # def sum({arg1, arg2, arg3, arg4}, _level = 0, acc) do
  #   acc + arg1 + arg2 + arg3 + arg4
  # end
  def sum(unquote(C.array()), _level = 0, acc) do
    unquote(C.arguments() |> Enum.reduce(C.var(acc), &C.sum_reducer/2))
  end

  # def sum({arg1, arg2, arg3, arg4}, level, acc) do
  #   child_level = level - bits
  #   sum(arg4, child_level,
  #     sum(arg3, child_level,
  #        sum(arg2, child_level,
  #          sum(arg1, child_level, acc))))
  # end
  def sum(unquote(C.array()), level, acc) do
    child_level = C.decr_level(level)

    unquote(
      C.arguments()
      |> Enum.reduce(C.var(acc), fn arg, acc ->
        quote do
          sum(unquote(arg), var!(child_level), unquote(acc))
        end
      end)
    )
  end

  def product(trie, level, acc)
  def product(_trie = nil, _level, acc), do: acc

  # def product({arg1, arg2, arg3, arg4}, _level = 0, acc) do
  #   acc * arg1 * arg2 * arg3 * arg4
  # end
  def product(unquote(C.array()), _level = 0, acc) do
    unquote(C.arguments() |> Enum.reduce(C.var(acc), &C.product_reducer/2))
  end

  # def product({arg1, arg2, arg3, arg4}, level, acc) do
  #   child_level = level - bits
  #   product(arg4, child_level,
  #     product(arg3, child_level,
  #        product(arg2, child_level,
  #          product(arg1, child_level, acc))))
  # end
  def product(unquote(C.array()), level, acc) do
    child_level = C.decr_level(level)

    unquote(
      C.arguments()
      |> Enum.reduce(C.var(acc), fn arg, acc ->
        quote do
          product(unquote(arg), var!(child_level), unquote(acc))
        end
      end)
    )
  end

  def intersperse(trie, level, separator, acc) do
    foldr_leaves(trie, level, acc, separator, &intersperse_leaf/3)
  end

  # def intersperse_leaf({arg1, arg2, arg3, arg4}, separator, acc) do
  #   [arg1, separator, arg2, ... separator | acc]
  # end
  defp intersperse_leaf(unquote(C.array()), separator, acc) do
    unquote(
      C.arguments()
      |> Enum.intersperse(C.var(separator))
      |> Enum.concat([C.var(separator)])
      |> C.list_with_rest(C.var(acc))
    )
  end

  def join(trie, level, joiner, acc) do
    foldr_leaves(trie, level, acc, joiner, &join_leaf/3)
  end

  # def join({arg1, arg2, arg3, arg4}, joiner, acc) do
  #   [mapper.(arg1), joiner, mapper.(arg2), ... joiner | acc]
  # end
  defp join_leaf(unquote(C.array()), joiner, acc) do
    unquote(
      C.arguments()
      |> Enum.map_intersperse(C.var(joiner), C.apply_mapper(C.var(&to_string/1)))
      |> Enum.concat([C.var(joiner)])
      |> C.list_with_rest(C.var(acc))
    )
  end

  def map(trie, level, fun)

  # def map({arg1, arg2, arg3, arg4}, _level = 0, f) do
  #   {f.(arg1), f.(arg2), f.(arg3), f.(arg4)}
  # end
  def map(unquote(C.array()), _level = 0, fun) do
    unquote(
      C.arguments()
      |> Enum.map(C.apply_mapper(C.var(fun)))
      |> C.array()
    )
  end

  # def map({arg1, arg2, arg3, arg4}, level, f) do
  #   child_level = level - bits
  #   {
  #     arg1 && map(arg1, child_level, f),
  #     arg2 && map(arg2, child_level, f),
  #     arg3 && map(arg3, child_level, f),
  #     arg4 && map(arg4, child_level, f),
  #   }
  # end
  def map(unquote(C.array()), level, fun) do
    child_level = C.decr_level(level)

    unquote(
      C.arguments()
      |> C.sparse_map(fn arg ->
        quote do
          unquote(arg) && map(unquote(arg), var!(child_level), var!(fun))
        end
      end)
      |> C.array()
    )
  end

  defp foldr_leaves(trie, level, acc, params, fun)

  defp foldr_leaves(leaf, _level = 0, acc, params, fun) do
    fun.(leaf, params, acc)
  end

  # def foldr_leaves({arg1, arg2, nil, nil}, level, acc, params, fun) do
  #   child_level = level - bits
  #   foldr_leaves(arg1, child_level, foldr_leaves(arg2, child_level, acc, params, fun), params, fun)
  # end
  for i <- C.range() do
    defp foldr_leaves(
           unquote(C.array_with_nils(i)),
           level,
           acc,
           params,
           fun
         ) do
      child_level = C.decr_level(level)

      unquote(
        C.reversed_arguments(i)
        |> Enum.reduce(C.var(acc), fn arg, acc ->
          quote do
            foldr_leaves(unquote(arg), var!(child_level), unquote(acc), var!(params), var!(fun))
          end
        end)
      )
    end
  end

  @compile {:inline, slice: 6}
  def slice(trie, start, last, level, acc, nodes \\ [])

  def slice(leaf, start, last, _level = 0, acc, nodes) do
    last_index = C.radix_rem(last)
    remaining = last - start

    case remaining - last_index do
      new_remaining when new_remaining > 0 ->
        new_acc = partial_slice_leaf(leaf, 0, last_index, acc)
        slice_next(new_remaining, new_acc, nodes)

      neg_first_index ->
        partial_slice_leaf(leaf, -neg_first_index, last_index, acc)
    end
  end

  def slice(trie, start, last, level, acc, nodes) do
    current_index = C.radix_search(last, level)

    new_nodes =
      case current_index do
        0 -> nodes
        _ -> [{trie, level, current_index - 1} | nodes]
      end

    child = elem(trie, current_index)
    slice(child, start, last, C.decr_level(level), acc, new_nodes)
  end

  @compile {:inline, do_slice: 4}
  defp do_slice(leaf, remaining, acc, nodes) do
    case remaining - C.branch_factor() do
      new_remaining when new_remaining > 0 ->
        new_acc = Node.prepend_all(leaf, acc)
        slice_next(new_remaining, new_acc, nodes)

      neg_first_index ->
        partial_slice_leaf(leaf, -neg_first_index, C.branch_factor() - 1, acc)
    end
  end

  @compile {:inline, slice_next: 3}
  defp slice_next(remaining, acc, [node | nodes]) do
    {new_leaf, new_nodes} = unpack_slice_nodes(node, nodes)
    do_slice(new_leaf, remaining, acc, new_nodes)
  end

  @compile {:inline, partial_slice_leaf: 4}
  defp partial_slice_leaf(leaf, index, index, acc) do
    [elem(leaf, index) | acc]
  end

  defp partial_slice_leaf(leaf, until, index, acc) do
    partial_slice_leaf(leaf, until, index - 1, [elem(leaf, index) | acc])
  end

  @compile {:inline, unpack_slice_nodes: 2}
  defp unpack_slice_nodes({trie, level, index}, nodes) do
    case level do
      0 ->
        {trie, nodes}

      _ ->
        child = elem(trie, index)
        new_node = {child, C.decr_level(level), unquote(C.branch_factor() - 1)}

        case index do
          0 -> unpack_slice_nodes(new_node, nodes)
          _ -> unpack_slice_nodes(new_node, [{trie, level, index - 1} | nodes])
        end
    end
  end

  def take(trie, level, amount) do
    case do_take(trie, level, amount - 1, false) do
      {0, tail} ->
        {:small, tail}

      {tmp_level, tmp_trie} ->
        {new_tail, new_trie, new_level} = pop_leaf(tmp_trie, tmp_level)
        {:large, new_trie, new_level, new_tail}
    end
  end

  defp do_take(leaf, _level = 0, last_index, _same_level?) do
    {0, Node.take(leaf, C.radix_rem(last_index) + 1)}
  end

  defp do_take(trie, level, last_index, same_level?) do
    child_level = C.decr_level(level)
    radix = C.radix_search(last_index, level)
    child = elem(trie, radix)

    case {radix, same_level?} do
      {0, false} ->
        do_take(child, child_level, last_index, false)

      _ ->
        {_, new_child} = do_take(child, child_level, last_index, true)

        new_trie =
          trie
          |> put_elem(radix, new_child)
          |> Node.take(radix + 1)

        {level, new_trie}
    end
  end

  def with_index(trie, level, fun)

  # def with_index({arg1, arg2, arg3, arg4}, _level = 0, offset) do
  #   {{arg1, offset + 0, {arg2, offset + 1}, {arg3, offset + 2}, {arg4, offset + 3}}
  # end
  def with_index(unquote(C.array()), _level = 0, offset) do
    unquote(
      C.arguments()
      |> Enum.with_index()
      |> Enum.map(fn {arg, index} ->
        quote do
          {unquote(arg), var!(offset) + unquote(index)}
        end
      end)
      |> C.array()
    )
  end

  # def with_index({arg1, arg2, arg3, arg3}, level, offset) do
  #   child_level = level - bits
  #   {
  #     arg1 && with_index(arg1, child_level, offset + (0 <<< level)),
  #     arg2 && with_index(arg2, child_level, offset + (1 <<< level)),
  #     arg3 && with_index(arg3, child_level, offset + (2 <<< level)),
  #     arg4 && with_index(arg4, child_level, offset + (3 <<< level)),
  #  }
  # end
  def with_index(unquote(C.array()), level, offset) do
    child_level = C.decr_level(level)

    unquote(
      C.arguments()
      |> Enum.with_index()
      |> Enum.map(fn {arg, index} ->
        quote do
          unquote(arg) &&
            with_index(
              unquote(arg),
              var!(child_level),
              var!(offset) + (unquote(index) <<< var!(level))
            )
        end
      end)
      |> C.fill_with(nil)
      |> C.array()
    )
  end
end
