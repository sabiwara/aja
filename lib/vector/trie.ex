defmodule A.Vector.Trie do
  @moduledoc false

  import A.Vector.CodeGen
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
  defp do_group_leaves(list_with_rest(rest), acc, count) when rest != [] do
    do_group_leaves(rest, [array() | acc], count + branch_factor())
  end

  for i <- args_range() do
    defp do_group_leaves(take_arguments(unquote(i)), acc, count) do
      last = array(arguments_with_nils(unquote(i)))
      {count + unquote(i), count, :lists.reverse(acc), last}
    end
  end

  @spec group_map_leaves([v1], (v1 -> v2)) ::
          {non_neg_integer, non_neg_integer, [leaf(v2)], Tail.t(v2)}
        when v1: value, v2: value
  def group_map_leaves(list, fun) do
    do_group_map_leaves(list, fun, [], 0)
  end

  @compile {:inline, do_group_map_leaves: 4}
  defp do_group_map_leaves(list_with_rest(rest), fun, acc, count) when rest != [] do
    new_leaf =
      arguments()
      |> map_arguments(apply_mapper(var(fun)))
      |> array()

    do_group_map_leaves(rest, fun, [new_leaf | acc], count + branch_factor())
  end

  for i <- args_range() do
    defp do_group_map_leaves(take_arguments(unquote(i)), fun, acc, count) do
      last =
        arguments()
        |> map_arguments(apply_mapper(var(fun)))
        |> arguments_with_nils(unquote(i))
        |> array()

      {count + unquote(i), count, :lists.reverse(acc), last}
    end
  end

  def group_leaves_ast(list) do
    do_group_leaves_ast(list, [], 0)
  end

  defp do_group_leaves_ast(list_with_rest(rest), acc, count) when rest != [] do
    do_group_leaves_ast(rest, [array_ast() | acc], count + branch_factor())
  end

  for i <- args_range() do
    defp do_group_leaves_ast(take_arguments(unquote(i)), acc, count) do
      last = array_ast(arguments_with_nils(unquote(i)))
      {count + unquote(i), count, :lists.reverse(acc), last}
    end
  end

  def duplicate_leaves(_value, _n = 0), do: :empty

  def duplicate_leaves(value, n) when n <= branch_factor() do
    {:small, Tail.partial_duplicate(value, n)}
  end

  def duplicate_leaves(value, n) do
    leaf = Node.duplicate(value)
    leaf_count = radix_div(n - 1)
    tail_size = radix_rem(n - 1) + 1

    leaves = List.duplicate(leaf, leaf_count)
    tail = Tail.partial_duplicate(value, tail_size)
    {:large, leaves, tail, tail_size}
  end

  @spec from_leaves([leaf(val)]) :: nil | {non_neg_integer, t(val)} when val: value
  def from_leaves(leaves)

  def from_leaves([]), do: nil
  def from_leaves([leaf]), do: {0, leaf}
  def from_leaves(leaves), do: do_from_nodes(leaves, bits())

  @compile {:inline, do_from_nodes: 2}
  defp do_from_nodes(nodes, level)

  defp do_from_nodes(list_with_rest(rest), level) when rest != [] do
    nodes = [array() | group_nodes(rest)]
    do_from_nodes(nodes, incr_level(level))
  end

  defp do_from_nodes(nodes, level) do
    {level, Node.from_incomplete_list(nodes)}
  end

  defp group_nodes(nodes)

  defp group_nodes(list_with_rest(rest)) when rest != [] do
    [array() | group_nodes(rest)]
  end

  defp group_nodes(nodes) do
    [Node.from_incomplete_list(nodes)]
  end

  @spec from_ast_leaves([leaf(val)]) :: nil | {non_neg_integer, t(val)} when val: value
  def from_ast_leaves(leaves)

  def from_ast_leaves([]), do: nil
  def from_ast_leaves([leaf]), do: {0, leaf}
  def from_ast_leaves(leaves), do: do_from_ast_nodes(leaves, bits())

  defp do_from_ast_nodes(nodes, level)

  defp do_from_ast_nodes(list_with_rest(rest), level) when rest != [] do
    nodes = [array_ast() | group_ast_nodes(rest)]
    do_from_ast_nodes(nodes, incr_level(level))
  end

  defp do_from_ast_nodes(nodes, level) do
    {level, Node.ast_from_incomplete_list(nodes)}
  end

  defp group_ast_nodes(nodes)

  defp group_ast_nodes(list_with_rest(rest)) when rest != [] do
    [array_ast() | group_ast_nodes(rest)]
  end

  defp group_ast_nodes(nodes) do
    [Node.ast_from_incomplete_list(nodes)]
  end

  @compile {:inline, append_leaf: 4}
  def append_leaf(trie, level, index, leaf)

  def append_leaf(trie, _level = 0, _index, leaf) do
    {array(partial_arguments_with_nils([trie, leaf])), bits()}
  end

  def append_leaf(trie, level, index, leaf) do
    case index >>> level do
      branch_factor() ->
        new_branch = build_single_branch(leaf, level)
        {array(partial_arguments_with_nils([trie, new_branch])), incr_level(level)}

      _ ->
        new_trie = append_leaf_to_existing(trie, level, index, leaf)
        {new_trie, level}
    end
  end

  defp append_leaf_to_existing(nil, level, _index, leaf) do
    build_single_branch(leaf, level)
  end

  defp append_leaf_to_existing(trie, _level = bits(), index, leaf) do
    put_elem(trie, radix_search(index, bits()), leaf)
  end

  defp append_leaf_to_existing(trie, level, index, leaf) do
    current_index = radix_search(index, level)
    child = elem(trie, current_index)

    new_child = append_leaf_to_existing(child, decr_level(level), index, leaf)

    put_elem(trie, current_index, new_child)
  end

  defp build_single_branch(leaf, _level = 0) do
    leaf
  end

  defp build_single_branch(leaf, level) do
    child = build_single_branch(leaf, decr_level(level))
    array(value_with_nils(child))
  end

  @compile {:inline, append_leaves: 4}
  def append_leaves(trie, level, index, leaves)

  def append_leaves(trie, level, _index, []), do: {trie, level}

  def append_leaves(trie, level, index, [leaf | rest]) do
    {new_trie, new_level} = append_leaf(trie, level, index, leaf)
    append_leaves(new_trie, new_level, index + branch_factor(), rest)
  end

  # ACCESS

  @compile {:inline, first: 2}
  def first(trie, level)

  def first(leaf, _level = 0) do
    elem(leaf, 0)
  end

  def first(trie, level) do
    child = elem(trie, 0)
    first(child, decr_level(level))
  end

  @compile {:inline, lookup: 3}
  def lookup(trie, index, level)

  def lookup(leaf, index, _level = 0) do
    elem(leaf, radix_rem(index))
  end

  def lookup(trie, index, level) do
    current_index = radix_search(index, level)
    child = elem(trie, current_index)
    lookup(child, index, decr_level(level))
  end

  def replace(trie, index, level, value)

  def replace(leaf, index, _level = 0, value) do
    current_index = radix_rem(index)
    put_elem(leaf, current_index, value)
  end

  def replace(trie, index, level, value) do
    current_index = radix_search(index, level)
    child = elem(trie, current_index)

    new_child = replace(child, index, decr_level(level), value)

    put_elem(trie, current_index, new_child)
  end

  def update(trie, index, level, fun)

  def update(leaf, index, _level = 0, fun) do
    current_index = radix_rem(index)
    Node.update_at(leaf, current_index, fun)
  end

  def update(trie, index, level, fun) do
    current_index = radix_search(index, level)
    child = elem(trie, current_index)

    new_child = update(child, index, decr_level(level), fun)

    put_elem(trie, current_index, new_child)
  end

  # POP LEAF

  def pop_leaf(trie, level) do
    {popped, new} = do_nested_pop_leaf(trie, level)

    case elem(new, 1) do
      nil -> {popped, elem(new, 0), decr_level(level)}
      _ -> {popped, new, level}
    end
  end

  defp do_nested_pop_leaf(leaves, _level = bits()) do
    do_pop_leaf(leaves)
  end

  defp do_nested_pop_leaf(array(arguments_with_nils(1)), level) do
    {popped, argument_at(0)} = do_nested_pop_leaf(argument_at(0), decr_level(level))

    case argument_at(0) do
      nil ->
        {popped, nil}

      _ ->
        new_trie = array(arguments_with_nils(1))
        {popped, new_trie}
    end
  end

  for i <- args_range(), i > 1 do
    defp do_nested_pop_leaf(array(arguments_with_nils(unquote(i))), level) do
      {popped, argument_at(unquote(i - 1))} =
        do_nested_pop_leaf(argument_at(unquote(i - 1)), decr_level(level))

      new_trie = array(arguments_with_nils(unquote(i)))
      {popped, new_trie}
    end
  end

  defp do_pop_leaf(array(arguments_with_nils(1))) do
    {argument_at(0), nil}
  end

  for i <- args_range(), i > 1 do
    defp do_pop_leaf(array(arguments_with_nils(unquote(i)))) do
      {argument_at(unquote(i - 1)), array(arguments_with_nils(unquote(i - 1)))}
    end
  end

  # LOOPS

  def to_list(trie, level, acc)

  # def to_list({arg1, arg2, arg3, arg4}, _level = 0, acc) do
  #   [arg1, arg2, arg3, arg4 | acc]
  # end
  def to_list(array(), _level = 0, acc) do
    list_with_rest(acc)
  end

  # def to_list({arg1, arg2, nil, nil}, level, acc) do
  #   child_level = level - bits
  #   to_list(arg1, child_level, to_list(arg2, child_level, acc))
  # end
  for i <- args_range() do
    def to_list(array(arguments_with_nils(unquote(i))), level, acc) do
      child_level = decr_level(level)

      unquote(i)
      |> take_arguments()
      |> reverse_arguments()
      |> reduce_arguments(acc, fn arg, acc ->
        quote do
          to_list(unquote(arg), var!(child_level), unquote(acc))
        end
      end)
    end
  end

  def to_reverse_list(trie, level, acc)

  # def to_reverse_list({arg1, arg2, arg3, arg4}, _level = 0, acc) do
  #   [arg4, arg3, arg2, arg1 | acc]
  # end
  def to_reverse_list(array(), _level = 0, acc) do
    list_with_rest(reverse_arguments(), acc)
  end

  # def to_reverse_list({arg1, arg2, nil, nil}, level, acc) do
  #   child_level = level - bits
  #   to_reverse_list(arg2, child_level, to_reverse_list(arg1, child_level, acc))
  # end
  for i <- args_range() do
    def to_reverse_list(array(arguments_with_nils(unquote(i))), level, acc) do
      child_level = decr_level(level)

      unquote(i)
      |> take_arguments()
      |> reduce_arguments(acc, fn arg, acc ->
        quote do
          to_reverse_list(unquote(arg), var!(child_level), unquote(acc))
        end
      end)
    end
  end

  def member?(trie, level, value)

  # def member?({arg1, arg2, arg3, arg4}, _level = 0, value) do
  #   (arg1 === value) or (arg2 === value) or (arg3 === value) or (arg4 === value)
  # end
  def member?(array(), _level = 0, value) do
    arguments()
    |> map_arguments(strict_equal_mapper(var(value)))
    |> reduce_arguments(&strict_or_reducer/2)
  end

  # def member?({arg1, arg2, nil, nil}, level, value) do
  #   child_level = level - bits
  #   member?(arg1, child_level, value) or member?(arg1, child_level, value)
  # end
  for i <- args_range() do
    def member?(array(arguments_with_nils(unquote(i))), level, value) do
      child_level = decr_level(level)

      unquote(i)
      |> take_arguments()
      |> map_arguments(fn arg ->
        quote do
          member?(unquote(arg), var!(child_level), var!(value))
        end
      end)
      |> reduce_arguments(&strict_or_reducer/2)
    end
  end

  def any?(trie, level)

  # def any?({arg1, arg2, arg3, arg4}, _level = 0) do
  #   arg1 || arg2 || arg3 || arg4
  # end
  def any?(array(), _level = 0) do
    arguments()
    |> reduce_arguments(&or_reducer/2)
  end

  # def any?({arg1, arg2, nil, nil}, level) do
  #   child_level = level - bits
  #   any?(arg1, child_level) || any?(arg1, child_level)
  # end
  for i <- args_range() do
    def any?(array(arguments_with_nils(unquote(i))), level) do
      child_level = decr_level(level)

      unquote(i)
      |> take_arguments()
      |> map_arguments(fn arg ->
        quote do
          any?(unquote(arg), var!(child_level))
        end
      end)
      |> reduce_arguments(&or_reducer/2)
    end
  end

  def any?(trie, level, fun)

  # def any?({arg1, arg2, arg3, arg4}, _level = 0, fun) do
  #   fun.(arg1) || fun.(arg2) || fun.(arg3) || fun.(arg4)
  # end
  def any?(array(), _level = 0, fun) do
    arguments()
    |> map_arguments(apply_mapper(var(fun)))
    |> reduce_arguments(&or_reducer/2)
  end

  # def any?({arg1, arg2, nil, nil}, level, fun) do
  #   child_level = level - bits
  #   any?(arg1, child_level, fun) || any?(arg1, child_level, fun)
  # end
  for i <- args_range() do
    def any?(array(arguments_with_nils(unquote(i))), level, fun) do
      child_level = decr_level(level)

      unquote(i)
      |> take_arguments()
      |> map_arguments(fn arg ->
        quote do
          any?(unquote(arg), var!(child_level), var!(fun))
        end
      end)
      |> reduce_arguments(&or_reducer/2)
    end
  end

  def all?(trie, level)

  # def all?({arg1, arg2, arg3, arg4}, _level = 0) do
  #   arg1 && arg2 && arg3 && arg4
  # end
  def all?(array(), _level = 0) do
    arguments()
    |> reduce_arguments(&and_reducer/2)
  end

  # def all?({arg1, arg2, nil, nil}, level) do
  #   child_level = level - bits
  #   all?(arg1, child_level) && all?(arg1, child_level)
  # end
  for i <- args_range() do
    def all?(array(arguments_with_nils(unquote(i))), level) do
      child_level = decr_level(level)

      unquote(i)
      |> take_arguments()
      |> map_arguments(fn arg ->
        quote do
          all?(unquote(arg), var!(child_level))
        end
      end)
      |> reduce_arguments(&and_reducer/2)
    end
  end

  def all?(trie, level, fun)

  # def all?({arg1, arg2, arg3, arg4}, _level = 0, fun) do
  #   fun.(arg1) && fun.(arg2) && fun.(arg3) && fun.(arg4)
  # end
  def all?(array(), _level = 0, fun) do
    arguments()
    |> map_arguments(apply_mapper(var(fun)))
    |> reduce_arguments(&and_reducer/2)
  end

  # def all?({arg1, arg2, nil, nil}, level, fun) do
  #   child_level = level - bits
  #   all?(arg1, child_level, fun) && all?(arg1, child_level, fun)
  # end
  for i <- args_range() do
    def all?(array(arguments_with_nils(unquote(i))), level, fun) do
      child_level = decr_level(level)

      unquote(i)
      |> take_arguments()
      |> map_arguments(fn arg ->
        quote do
          all?(unquote(arg), var!(child_level), var!(fun))
        end
      end)
      |> reduce_arguments(&and_reducer/2)
    end
  end

  def foldl(trie, level, acc, fun) do
    foldl_leaves(trie, level, acc, fun, &foldl_leaf/3)
  end

  # defp foldl_leaf({arg1, arg2, arg3, arg4}, fun, acc) do
  #   fun(arg1, fun(arg2, fun(arg3, fun(arg4, acc))))
  # end
  def foldl_leaf(array(arguments()), fun, acc) do
    reduce_arguments(arguments(), acc, fn arg, acc ->
      quote do
        var!(fun).(unquote(arg), unquote(acc))
      end
    end)
  end

  def foldr(trie, level, acc, fun) do
    foldr_leaves(trie, level, acc, fun, &foldr_leaf/3)
  end

  # defp foldr_leaf({arg1, arg2, arg3, arg4}, fun, acc) do
  #   fun(arg1, fun(arg2, fun(arg3, fun(arg4, acc))))
  # end
  def foldr_leaf(array(arguments()), fun, acc) do
    reduce_arguments(reverse_arguments(), acc, fn arg, acc ->
      quote do
        var!(fun).(unquote(arg), unquote(acc))
      end
    end)
  end

  def sum(trie, level, acc)

  # def sum({arg1, arg2, arg3, arg4}, _level = 0, acc) do
  #   acc + arg1 + arg2 + arg3 + arg4
  # end
  def sum(array(), _level = 0, acc) do
    reduce_arguments(arguments(), acc, &sum_reducer/2)
  end

  # def sum({arg1, arg2, nil, nil}, level, acc) do
  #   child_level = level - bits
  #   sum(arg2, child_level, sum(arg1, child_level, acc))
  # end
  for i <- args_range() do
    def sum(array(arguments_with_nils(unquote(i))), level, acc) do
      child_level = decr_level(level)

      unquote(i)
      |> take_arguments()
      |> reduce_arguments(acc, fn arg, acc ->
        quote do
          sum(unquote(arg), var!(child_level), unquote(acc))
        end
      end)
    end
  end

  def join_as_iodata(trie, level, joiner, acc) do
    foldr_leaves(trie, level, acc, joiner, &join_as_iodata_leaf/3)
  end

  # def join_as_iodata({arg1, arg2, arg3, arg4}, joiner, acc) do
  #   [to_string(arg1), joiner, to_string(arg2), ... joiner | acc]
  # end
  defp join_as_iodata_leaf(array(), joiner, acc) do
    reverse_arguments()
    |> map_arguments(apply_mapper(var(&to_string/1)))
    |> reduce_arguments(acc, intersperse_reducer(var(joiner)))
  end

  def map(trie, level, fun)

  # def map({arg1, arg2, arg3, arg4}, _level = 0, f) do
  #   {f.(arg1), f.(arg2), f.(arg3), f.(arg4)}
  # end
  def map(array(), _level = 0, fun) do
    array(map_arguments(apply_mapper(var(fun))))
  end

  # def map({arg1, arg2, nil, nil}, level, f) do
  #   child_level = level - bits
  #   {map(arg1, child_level, f), map(arg2, child_level, f), nil, nil}
  # end
  for i <- args_range() do
    def map(array(arguments_with_nils(unquote(i))), level, fun) do
      child_level = decr_level(level)

      map_arguments(fn arg ->
        quote do
          map(unquote(arg), var!(child_level), var!(fun))
        end
      end)
      |> arguments_with_nils(unquote(i))
      |> array()
    end
  end

  defp foldl_leaves(trie, level, acc, params, fun)

  defp foldl_leaves(leaf, _level = 0, acc, params, fun) do
    fun.(leaf, params, acc)
  end

  # def foldl_leaves({arg1, arg2, nil, nil}, level, acc, params, fun) do
  #   child_level = level - bits
  #   foldl_leaves(arg2, child_level, foldl_leaves(arg1, child_level, acc, params, fun), params, fun)
  # end
  for i <- args_range() do
    defp foldl_leaves(array(arguments_with_nils(unquote(i))), level, acc, params, fun) do
      child_level = decr_level(level)

      unquote(i)
      |> take_arguments()
      |> reduce_arguments(acc, fn arg, acc ->
        quote do
          foldl_leaves(unquote(arg), var!(child_level), unquote(acc), var!(params), var!(fun))
        end
      end)
    end
  end

  defp foldr_leaves(trie, level, acc, params, fun)

  defp foldr_leaves(leaf, _level = 0, acc, params, fun) do
    fun.(leaf, params, acc)
  end

  # def foldr_leaves({arg1, arg2, nil, nil}, level, acc, params, fun) do
  #   child_level = level - bits
  #   foldr_leaves(arg1, child_level, foldr_leaves(arg2, child_level, acc, params, fun), params, fun)
  # end
  for i <- args_range() do
    defp foldr_leaves(array(arguments_with_nils(unquote(i))), level, acc, params, fun) do
      child_level = decr_level(level)

      unquote(i)
      |> take_arguments()
      |> reverse_arguments()
      |> reduce_arguments(acc, fn arg, acc ->
        quote do
          foldr_leaves(unquote(arg), var!(child_level), unquote(acc), var!(params), var!(fun))
        end
      end)
    end
  end
end
