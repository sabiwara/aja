defmodule A.Vector.Tail do
  @moduledoc false

  import A.Vector.CodeGen

  alias A.Vector.Node

  @type t(value) :: Node.t(value | nil)

  def pop_last(tail, i) do
    {elem(tail, i), put_elem(tail, i, nil)}
  end

  for i <- args_range() do
    # def partial_map({arg1, arg2, arg3, arg4}, fun, 2) do
    #   {fun.(arg1), fun.(arg2), arg3, arg4}
    # end
    def partial_map(array(), fun, unquote(i)) do
      map_arguments(apply_mapper(var(fun)))
      |> take_drop_arguments(arguments(), unquote(i))
      |> array()
    end
  end

  for i <- args_range() do
    # def partial_to_list({arg1, arg2, _arg3, _arg4}, 2) do
    #   [arg1, arg2]
    # end
    def partial_to_list(array(arguments_with_wildcards(unquote(i))), unquote(i)) do
      take_arguments(unquote(i))
    end
  end

  for i <- args_range() do
    # def partial_reverse({arg1, arg2, _arg3, _arg4}, 2) do
    #   [arg2, arg1]
    # end
    def partial_reverse(array(arguments_with_wildcards(unquote(i))), unquote(i)) do
      reverse_arguments(take_arguments(unquote(i)))
    end
  end

  for i <- args_range() do
    # def partial_duplicate(value, 2) do
    #   {value, value, nil, nil}
    # end
    def partial_duplicate(value, unquote(i)) do
      array(arguments_with_nils(duplicate_argument(value), unquote(i)))
    end
  end

  for i <- args_range() do
    # def partial_member?({arg1, arg2, _arg3, _arg4}, 2, value) do
    #   (arg1 === value) or (arg2 === value)
    # end
    def partial_member?(array(arguments_with_wildcards(unquote(i))), unquote(i), value) do
      unquote(i)
      |> take_arguments()
      |> map_arguments(strict_equal_mapper(var(value)))
      |> reduce_arguments(&strict_or_reducer/2)
    end
  end

  for i <- args_range() do
    # def partial_any?({arg1, arg2, arg3, _arg4}, 3) do
    #   arg1 || arg2 || arg3
    # end
    def partial_any?(array(arguments_with_wildcards(unquote(i))), unquote(i)) do
      unquote(i)
      |> take_arguments()
      |> reduce_arguments(&or_reducer/2)
    end
  end

  for i <- args_range() do
    # def partial_any?({arg1, arg2, arg3, _arg4}, 3, fun) do
    #   fun.(arg1) || fun.(arg2) || fun.(arg3)
    # end
    def partial_any?(array(arguments_with_wildcards(unquote(i))), unquote(i), fun) do
      unquote(i)
      |> take_arguments()
      |> map_arguments(apply_mapper(var(fun)))
      |> reduce_arguments(&or_reducer/2)
    end
  end

  for i <- args_range() do
    # def partial_all?({arg1, arg2, arg3, _arg4}, 3) do
    #   arg1 && arg2 && arg3
    # end
    def partial_all?(array(arguments_with_wildcards(unquote(i))), unquote(i)) do
      unquote(i)
      |> take_arguments()
      |> reduce_arguments(&and_reducer/2)
    end
  end

  for i <- args_range() do
    # def partial_all?({arg1, arg2, arg3, _arg4}, 3, fun) do
    #   fun.(arg1) && fun.(arg2) && fun.(arg3)
    # end
    def partial_all?(array(arguments_with_wildcards(unquote(i))), unquote(i), fun) do
      unquote(i)
      |> take_arguments()
      |> map_arguments(apply_mapper(var(fun)))
      |> reduce_arguments(&and_reducer/2)
    end
  end

  for i <- args_range() do
    # def partial_sum({arg1, arg2, arg3, _arg4}, 3, acc) do
    #   acc + arg1 + arg2 + arg3
    # end
    def partial_sum(array(arguments_with_wildcards(unquote(i))), unquote(i), acc) do
      unquote(i)
      |> take_arguments()
      |> reduce_arguments(acc, &sum_reducer/2)
    end
  end

  def partial_intersperse(
        array(arguments_with_wildcards(1)),
        1,
        _separator
      ) do
    [argument_at(0)]
  end

  # case i = 1 needs to declare `_separator`, not `separator`
  for i <- args_range(), i > 1 do
    # def partial_intersperse({arg1, arg2, arg3, _arg4}, 3, separator) do
    #   [arg1, separator, arg2, separator, arg3]
    # end
    def partial_intersperse(
          array(arguments_with_wildcards(unquote(i))),
          unquote(i),
          separator
        ) do
      unquote(i)
      |> take_arguments()
      |> intersperse_arguments(separator)
    end
  end

  def partial_map_intersperse(
        array(arguments_with_wildcards(1)),
        1,
        _separator,
        mapper
      ) do
    [mapper.(argument_at(0))]
  end

  # case i = 1 needs to declare `_separator`, not `separator`
  for i <- args_range(), i > 1 do
    # def partial_map_intersperse({arg1, arg2, arg3, _arg4}, 3, separator, mapper) do
    #   [mapper.(arg1), separator, mapper.(arg2), separator, mapper.(arg3)]
    # end
    def partial_map_intersperse(
          array(arguments_with_wildcards(unquote(i))),
          unquote(i),
          separator,
          mapper
        ) do
      unquote(i)
      |> take_arguments()
      |> map_arguments(apply_mapper(var(mapper)))
      |> intersperse_arguments(separator)
    end
  end

  def complete_tail(tail, tail_size, values)

  def complete_tail(tail, _tail_size, []) do
    {tail, 0, []}
  end

  for i <- args_range() do
    # def complete_tail({arg1, arg2, _arg3, _arg4}, 2, [arg3, arg4 | rest]) do
    #   {{arg1, arg2, arg3, arg4}, 2, rest}
    # end
    def complete_tail(
          array(arguments_with_wildcards(unquote(i))),
          unquote(i),
          list_with_rest(drop_arguments(unquote(i)), rest)
        ) do
      {array(), unquote(branch_factor() - i), rest}
    end
  end

  for i <- args_range() do
    # def complete_tail(tail, tail_size, [arg1, arg2]) do
    #   new_tail = put_elem(put_elem(tail, tail_size, arg1), tail_size + 1, arg2)
    #   {new_tail, 2, []}
    # end
    def complete_tail(tail, tail_size, take_arguments(unquote(i))) do
      new_tail =
        unquote(i)
        |> take_arguments()
        |> reduce_arguments_with_index(tail, fn arg, index, acc ->
          quote do
            put_elem(unquote(acc), var!(tail_size) + unquote(index), unquote(arg))
          end
        end)

      {new_tail, unquote(i), []}
    end
  end
end
