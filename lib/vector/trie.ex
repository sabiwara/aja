defmodule Aja.Vector.Trie do
  @moduledoc false

  require Aja.Vector.CodeGen, as: C

  alias Aja.Vector.{Node, Tail}

  @type value :: term
  @type leaf(value) :: Node.t(value)
  @type t(value) :: Node.t(t(value) | value)

  # BUILD TRIE
  def group_leaves_ast(list) do
    do_group_leaves_ast(list, [], 0)
  end

  defp do_group_leaves_ast(unquote(C.list_with_rest(C.var(rest))), acc, count) when rest != [] do
    do_group_leaves_ast(rest, [unquote(C.array_ast()) | acc], count + C.branch_factor())
  end

  defp do_group_leaves_ast(rest, acc, count) do
    last = rest |> C.left_fill_with(nil) |> C.array()
    {count + length(rest), count, :lists.reverse(acc), last}
  end

  def duplicate(value, n) do
    div = C.radix_div(n)
    {level, acc} = do_duplicate(value, div, 0, [])

    case :erlang.bsl(1, level) do
      ^n ->
        [{1, trie}] = acc
        {C.decr_level(level), trie}

      _ ->
        [{count, node} | rest] = acc
        base_trie = Node.partial_duplicate(node, count)

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
        0 -> Node.duplicate(nil) |> Node.partial_duplicate(1)
        _ -> Node.partial_duplicate(child_node, child_count)
      end

    child = duplicate_rest(child_base, rest, child_count)

    put_elem(node, count, child)
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
    {level, nodes |> C.fill_with(nil) |> C.array()}
  end

  defp group_ast_nodes(nodes)

  defp group_ast_nodes(unquote(C.list_with_rest(C.var(rest)))) when rest != [] do
    [unquote(C.array_ast()) | group_ast_nodes(rest)]
  end

  defp group_ast_nodes(nodes) do
    [nodes |> C.fill_with(nil) |> C.array()]
  end

  def append_leaf(trie, level, index, leaf)

  def append_leaf(trie, _level = 0, _index, leaf) do
    {
      unquote(C.var([trie, leaf]) |> C.fill_with(nil) |> C.array()),
      C.bits()
    }
  end

  def append_leaf(trie, level, index, leaf) do
    case :erlang.bsr(index, level) do
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

  # ACCESS

  @compile {:inline, first: 2}
  def first(trie, level)

  def first(leaf, _level = 0) do
    elem(leaf, 0)
  end

  def first(trie, level) do
    child = elem(trie, 0)
    first(child, C.decr_level(level))
  end

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

  def pop_leaf(trie, level, index) do
    {popped, new} = do_nested_pop_leaf(trie, level, index)

    case elem(new, 1) do
      nil -> {popped, elem(new, 0), C.decr_level(level)}
      _ -> {popped, new, level}
    end
  end

  defp do_nested_pop_leaf(leaves, level = C.bits(), index) do
    current_index = C.radix_search(index, level)
    do_pop_leaf(leaves, current_index)
  end

  defp do_nested_pop_leaf(trie, level, index) do
    current_index = C.radix_search(index, level)
    child = elem(trie, current_index)

    {popped, new_child} = do_nested_pop_leaf(child, C.decr_level(level), index)

    case {current_index, new_child} do
      {0, nil} ->
        {popped, nil}

      _ ->
        new_trie = put_elem(trie, current_index, new_child)
        {popped, new_trie}
    end
  end

  defp do_pop_leaf(trie, index) do
    new_trie =
      case index do
        0 -> nil
        _ -> put_elem(trie, index, nil)
      end

    {elem(trie, index), new_trie}
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

  # FIND

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

    C.find_cond_trie do
      member?(arg, child_level, value) -> true
      _ -> false
    end
  end

  def any?(trie, level)

  # def any?({arg1, arg2, arg3, arg4}, _level = 0) do
  #   cond do
  #     arg1 -> true
  #     arg2 -> true
  #     arg3 -> true
  #     arg4 -> true
  #     true -> false
  #   end
  # end
  def any?(unquote(C.array()), _level = 0) do
    C.find_cond_leaf do
      arg -> true
      _ -> false
    end
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

    C.find_cond_trie do
      any?(arg, child_level) -> true
      _ -> false
    end
  end

  def any?(trie, level, fun)

  # def any?({arg1, arg2, arg3, arg4}, _level = 0, fun) do
  #   cond do
  #     fun.(arg1) -> true
  #     fun.(arg2) -> true
  #     fun.(arg3) -> true
  #     fun.(arg4) -> true
  #     true -> false
  #   end
  # end
  def any?(unquote(C.array()), _level = 0, fun) do
    C.find_cond_leaf do
      fun.(arg) -> true
      _ -> false
    end
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

    C.find_cond_trie do
      any?(arg, child_level, fun) -> true
      _ -> false
    end
  end

  def all?(trie, level)

  # def all?({arg1, arg2, arg3, arg4}, _level = 0) do
  #   cond do
  #     !arg1 -> false
  #     !arg2 -> false
  #     !arg3 -> false
  #     !arg4 -> false
  #     true -> true
  #   end
  # end
  def all?(unquote(C.array()), _level = 0) do
    C.find_cond_leaf do
      !arg -> false
      _ -> true
    end
  end

  # def all?({arg1, arg2, arg3, arg4}, level) do
  #   child_level = level - bits
  #   cond do
  #     !all?(arg1, child_level) -> false
  #     arg2 === null -> true
  #     !all?(arg2, child_level) -> false
  #     arg3 === null -> true
  #     !all?(arg3, child_level) -> false
  #     arg4 === null -> true
  #     !all?(arg4, child_level) -> false
  #     true -> true
  #   end
  # end
  def all?(unquote(C.array()), level) do
    child_level = C.decr_level(level)

    C.find_cond_trie do
      !all?(arg, child_level) -> false
      _ -> true
    end
  end

  def all?(trie, level, fun)

  # def all?({arg1, arg2, arg3, arg4}, _level = 0, fun) do
  #   cond do
  #     !fun.(arg1) -> false
  #     !fun.(arg2) -> false
  #     !fun.(arg3) -> false
  #     !fun.(arg4) -> false
  #     true -> true
  #   end
  # end
  def all?(unquote(C.array()), _level = 0, fun) do
    C.find_cond_leaf do
      !fun.(arg) -> false
      _ -> true
    end
  end

  # def all?({arg1, arg2, arg3, arg4}, level, fun) do
  #   child_level = level - bits
  #   cond do
  #     !all?(arg1, child_level, fun) -> false
  #     arg2 === null -> true
  #     !all?(arg2, child_level, fun) -> false
  #     arg3 === null -> true
  #     !all?(arg3, child_level, fun) -> false
  #     arg4 === null -> true
  #     !all?(arg4, child_level, fun) -> false
  #     true -> true
  #   end
  # end
  def all?(unquote(C.array()), level, fun) do
    child_level = C.decr_level(level)

    C.find_cond_trie do
      !all?(arg, child_level, fun) -> false
      _ -> true
    end
  end

  def find(trie, level, fun)

  def find(unquote(C.array()), _level = 0, fun) do
    C.find_cond_leaf do
      fun.(arg) -> {:ok, arg}
      _ -> nil
    end
  end

  def find(unquote(C.array()), level, fun) do
    child_level = C.decr_level(level)

    C.find_cond_trie do
      value = find(arg, child_level, fun) -> value
      _ -> nil
    end
  end

  def find_value(trie, level, fun)

  def find_value(unquote(C.array()), _level = 0, fun) do
    C.find_cond_leaf do
      value = fun.(arg) -> value
      _ -> nil
    end
  end

  def find_value(unquote(C.array()), level, fun) do
    child_level = C.decr_level(level)

    C.find_cond_trie do
      value = find_value(arg, child_level, fun) -> value
      _ -> nil
    end
  end

  def find_index(trie, level, fun)

  def find_index(unquote(C.array()), _level = 0, fun) do
    C.find_cond_leaf do
      fun.(arg) -> i
      _ -> nil
    end
  end

  def find_index(unquote(C.array()), level, fun) do
    child_level = C.decr_level(level)

    C.find_cond_trie do
      child_index = find_index(arg, child_level, fun) -> child_index + :erlang.bsl(i, level)
      _ -> nil
    end
  end

  def find_falsy_index(trie, level, fun)

  def find_falsy_index(unquote(C.array()), _level = 0, fun) do
    C.find_cond_leaf do
      !fun.(arg) -> i
      _ -> nil
    end
  end

  def find_falsy_index(unquote(C.array()), level, fun) do
    child_level = C.decr_level(level)

    C.find_cond_trie do
      child_index = find_falsy_index(arg, child_level, fun) -> child_index + :erlang.bsl(i, level)
      _ -> nil
    end
  end

  # FOLDS

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

  def list_leaves(trie, _level = 0, acc, _index) do
    [trie | acc]
  end

  def list_leaves(trie, level, acc, index) do
    current_index = C.radix_search(index, level)
    child = elem(trie, current_index)

    child_acc = list_leaves(child, C.decr_level(level), acc, index)
    list_leaves_sparse(trie, level, child_acc, current_index)
  end

  def list_leaves_sparse(_trie, _level, acc, _current_index = 0), do: acc

  def list_leaves_sparse(trie, level, acc, current_index) do
    child = :erlang.element(current_index, trie)
    new_acc = list_leaves_dense(child, C.decr_level(level), acc)
    list_leaves_sparse(trie, level, new_acc, current_index - 1)
  end

  def list_leaves_dense(trie, _level = 0, acc) do
    [trie | acc]
  end

  def list_leaves_dense(unquote(C.array()), _level = C.bits(), acc) do
    unquote(C.list_with_rest(C.var(acc)))
  end

  def list_leaves_dense(unquote(C.array()), level, acc) do
    child_level = C.decr_level(level)

    unquote(
      C.reversed_arguments()
      |> Enum.reduce(C.var(acc), fn arg, ast_acc ->
        quote do
          list_leaves_dense(
            unquote(arg),
            var!(child_level),
            unquote(ast_acc)
          )
        end
      end)
    )
  end

  def foldr_leaves(trie, level, acc, params, fun)

  def foldr_leaves(leaf, _level = 0, acc, params, fun) do
    fun.(leaf, params, acc)
  end

  # def foldr_leaves({arg1, arg2, arg3, arg4}, level, acc, params, fun) do
  #   child_level = level - bits
  #
  #   foldr_leaves(arg1, child_level,
  #     case arg2 do
  #       nil -> acc
  #       _ -> foldr_leaves(arg2, child_level,
  #         case arg3 do
  #           nil -> acc
  #           _ -> foldr_leaves(arg3, child_level,
  #             case arg4 do
  #               nil -> acc
  #               _ -> foldr_leaves(arg4, child_level, acc, params, fun)
  #             end,
  #             params, fun)
  #         end,
  #         params, fun)
  #     end,
  #     params, fun)
  # end
  def foldr_leaves(
        unquote(C.array()),
        level,
        acc,
        params,
        fun
      ) do
    child_level = C.decr_level(level)

    unquote(
      C.reversed_arguments()
      |> Enum.with_index(1)
      |> Enum.reduce(C.var(acc), fn {arg, i}, ast_acc ->
        recursive_call =
          quote do
            foldr_leaves(
              unquote(arg),
              var!(child_level),
              unquote(ast_acc),
              var!(params),
              var!(fun)
            )
          end

        if i == C.branch_factor() do
          recursive_call
        else
          quote do
            case unquote(arg) do
              nil -> var!(acc)
              _ -> unquote(recursive_call)
            end
          end
        end
      end)
    )
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
        {new_tail, new_trie, new_level} = pop_leaf(tmp_trie, tmp_level, amount - 1)
        {:large, new_trie, new_level, new_tail}
    end
  end

  defp do_take(leaf, _level = 0, last_index, _same_level?) do
    {0, Tail.partial_take(leaf, C.branch_factor() - C.radix_rem(last_index) - 1)}
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

  # def map_reduce({arg1, arg2, arg3, arg4}, _level = 0, acc, fun) do
  #   {arg1, acc} = fun.(arg1, acc)
  #   {arg2, acc} = fun.(arg2, acc)
  #   {arg3, acc} = fun.(arg3, acc)
  #   {arg4, acc} = fun.(arg4, acc)
  #   {{arg1, arg2, arg3, arg4}, acc}
  # end
  def map_reduce(unquote(C.array()), _level = 0, acc, fun) do
    unquote(
      C.arguments()
      |> Enum.map(fn arg ->
        quote do
          {unquote(arg), unquote(C.var(acc))} = var!(fun).(unquote(arg), unquote(C.var(acc)))
        end
      end)
      |> C.block()
    )

    {unquote(C.array()), unquote(C.var(acc))}
  end

  # def map_reduce({arg1, arg2, arg3, arg4}, level, acc, fun) do
  #   child_level = level - bits
  #
  #   {arg1, acc} = case arg1 do
  #     nil -> {nil, acc}
  #     child -> map_reduce(child, child_level, acc, fun)
  #   end
  #   {arg2, acc} = case arg2 do
  #     nil -> {nil, acc}
  #     child -> map_reduce(child, child_level, acc, fun)
  #   end
  #   # ...
  #
  #   {{arg1, arg2, arg3, arg4}, acc}
  # end
  def map_reduce(unquote(C.array()), level, acc, fun) do
    child_level = C.decr_level(level)

    unquote(
      C.arguments()
      |> Enum.map(fn arg ->
        quote do
          {unquote(arg), var!(acc)} =
            case unquote(arg) do
              nil ->
                {nil, var!(acc)}

              child ->
                map_reduce(
                  child,
                  var!(child_level),
                  var!(acc),
                  var!(fun)
                )
            end
        end
      end)
      |> C.block()
    )

    {unquote(C.array()), acc}
  end

  # def scan({arg1, arg2, arg3, arg4}, _level = 0, acc, fun) do
  #   arg1 = fun.(arg1, acc)
  #   arg2 = fun.(arg2, arg1)
  #   arg3 = fun.(arg3, arg2)
  #   arg4 = fun.(arg4, arg3)
  #   {{arg1, arg2, arg3, arg4}, arg4}
  # end
  def scan(unquote(C.array()), _level = 0, acc, fun) do
    unquote(
      Enum.zip(C.arguments(), [C.var(acc) | C.arguments()])
      |> Enum.map(fn {arg, acc} ->
        quote do
          unquote(arg) = var!(fun).(unquote(arg), unquote(acc))
        end
      end)
      |> C.block()
    )

    {unquote(C.array()), unquote(C.argument_at(C.branch_factor() - 1))}
  end

  # def scan({arg1, arg2, arg3, arg4}, level, acc, fun) do
  #   child_level = level - bits
  #
  #   {arg1, acc} = case arg1 do
  #     nil -> {nil, acc}
  #     child -> scan(child, child_level, acc, fun)
  #   end
  #   {arg2, acc} = case arg2 do
  #     nil -> {nil, acc}
  #     child -> scan(child, child_level, acc, fun)
  #   end
  #   # ...
  #
  #   {{arg1, arg2, arg3, arg4}, acc}
  # end
  def scan(unquote(C.array()), level, acc, fun) do
    child_level = C.decr_level(level)

    unquote(
      C.arguments()
      |> Enum.map(fn arg ->
        quote do
          {unquote(arg), var!(acc)} =
            case unquote(arg) do
              nil ->
                {nil, var!(acc)}

              child ->
                scan(
                  child,
                  var!(child_level),
                  var!(acc),
                  var!(fun)
                )
            end
        end
      end)
      |> C.block()
    )

    {unquote(C.array()), acc}
  end

  def with_index(trie, level, offset)

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
              var!(offset) + :erlang.bsl(unquote(index), var!(level))
            )
        end
      end)
      |> C.array()
    )
  end

  def with_index(trie, level, offset, fun)

  def with_index(unquote(C.array()), _level = 0, offset, fun) do
    unquote(
      C.arguments()
      |> Enum.with_index()
      |> Enum.map(fn {arg, index} ->
        quote do
          var!(fun).(unquote(arg), var!(offset) + unquote(index))
        end
      end)
      |> C.array()
    )
  end

  def with_index(unquote(C.array()), level, offset, fun) do
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
              var!(offset) + :erlang.bsl(unquote(index), var!(level)),
              var!(fun)
            )
        end
      end)
      |> C.array()
    )
  end

  def zip(trie1, trie2, level)

  # def zip({arg1, arg2, arg3, arg4}, {arg5, arg6, arg7, arg8}, _level = 0) do
  #   {{arg1, arg5}, {arg2, arg6}, {arg3, arg7}, {arg4, arg8}}
  # end
  def zip(unquote(C.array()), unquote(C.array(C.other_arguments())), _level = 0) do
    unquote(
      Enum.zip(C.arguments(), C.other_arguments())
      |> Enum.map(fn {arg, other_arg} ->
        quote do
          {unquote(arg), unquote(other_arg)}
        end
      end)
      |> C.array()
    )
  end

  # def zip({arg1, arg2, arg3, arg4}, {arg5, arg6, arg7, arg8}, level) do
  #   child_level = level - bits
  #   {
  #     arg1 && zip(arg1, arg5, child_level),
  #     arg2 && zip(arg2, arg6, child_level),
  #     arg3 && zip(arg3, arg7, child_level),
  #     arg4 && zip(arg4, arg8, child_level),
  #  }
  # end
  def zip(unquote(C.array()), unquote(C.array(C.other_arguments())), level) do
    child_level = C.decr_level(level)

    unquote(
      Enum.zip(C.arguments(), C.other_arguments())
      |> Enum.map(fn {arg, other_arg} ->
        quote do
          unquote(arg) &&
            zip(
              unquote(arg),
              unquote(other_arg),
              var!(child_level)
            )
        end
      end)
      |> C.array()
    )
  end

  def zip_with(trie1, trie2, level, fun)

  def zip_with(unquote(C.array()), unquote(C.array(C.other_arguments())), _level = 0, fun) do
    unquote(
      Enum.zip(C.arguments(), C.other_arguments())
      |> Enum.map(fn {arg, other_arg} ->
        quote do
          var!(fun).(unquote(arg), unquote(other_arg))
        end
      end)
      |> C.array()
    )
  end

  def zip_with(unquote(C.array()), unquote(C.array(C.other_arguments())), level, fun) do
    child_level = C.decr_level(level)

    unquote(
      Enum.zip(C.arguments(), C.other_arguments())
      |> Enum.map(fn {arg, other_arg} ->
        quote do
          unquote(arg) &&
            zip_with(
              unquote(arg),
              unquote(other_arg),
              var!(child_level),
              var!(fun)
            )
        end
      end)
      |> C.array()
    )
  end

  def unzip(trie, level)

  # def unzip({{arg1, arg5, {arg2, arg6}, {arg3, arg7}, {arg4, arg8}}, _level = 0) do
  #   {{arg1, arg2, arg3, arg4}, {arg5, arg6, arg7, arg8}}
  # end
  def unzip(
        unquote(C.array(Enum.zip(C.arguments(), C.other_arguments()))),
        _level = 0
      ) do
    {unquote(C.array()), unquote(C.array(C.other_arguments()))}
  end

  # def unzip({arg1, arg2, arg3, arg4}, level) do
  #   child_level = level - bits
  #
  #   {arg1, arg5} = case arg1 do
  #     nil -> {nil, nil}
  #     value -> unzip(value, child_level)
  #   end
  #   # ...
  #   {arg4, arg8} = case arg4 do
  #     nil -> {nil, nil}
  #     value -> unzip(value, child_level)
  #   end
  #
  #   {{arg1, arg2, arg3, arg4}, {arg5, arg6, arg7, arg8}}
  # end
  def unzip(unquote(C.array()), level) do
    child_level = C.decr_level(level)

    unquote(
      Enum.zip(C.arguments(), C.other_arguments())
      |> Enum.map(fn {arg, other_arg} ->
        quote do
          {unquote(arg), unquote(other_arg)} =
            case unquote(arg) do
              nil -> {nil, nil}
              value -> unzip(value, var!(child_level))
            end
        end
      end)
      |> C.block()
    )

    {unquote(C.array()), unquote(C.array(C.other_arguments()))}
  end
end
