defmodule A.Vector.Tail do
  @moduledoc false

  alias A.Vector.CodeGen, as: C
  require C

  alias A.Vector.Node

  @type t(value) :: Node.t(value | nil)

  def pop_last(tail, i) do
    {elem(tail, i), put_elem(tail, i, nil)}
  end

  for i <- C.range() do
    # def partial_map({arg1, arg2, arg3, arg4}, fun, 2) do
    #   {fun.(arg1), fun.(arg2), arg3, arg4}
    # end
    def partial_map(unquote(C.array()), fun, unquote(i)) do
      unquote(
        C.map_until(i, C.apply_mapper(C.var(fun)))
        |> C.array()
      )
    end
  end

  for i <- C.range() do
    # def partial_to_list({arg1, arg2, _arg3, _arg4}, 2) do
    #   [arg1, arg2]
    # end
    def partial_to_list(unquote(C.array_with_wildcards(i)), unquote(i)) do
      unquote(C.arguments(i))
    end
  end

  for i <- C.range() do
    # def partial_reverse({arg1, arg2, _arg3, _arg4}, 2) do
    #   [arg2, arg1]
    # end
    def partial_reverse(unquote(C.array_with_wildcards(i)), unquote(i)) do
      unquote(C.reversed_arguments(i))
    end
  end

  for i <- C.range() do
    # def partial_duplicate(value, 2) do
    #   {value, value, nil, nil}
    # end
    def partial_duplicate(value, unquote(i)) do
      unquote(
        List.duplicate(C.var(value), i)
        |> C.fill_with(nil)
        |> C.array()
      )
    end
  end

  for i <- C.range() do
    # def partial_member?({arg1, arg2, _arg3, _arg4}, 2, value) do
    #   (arg1 === value) or (arg2 === value)
    # end
    def partial_member?(unquote(C.array_with_wildcards(i)), unquote(i), value) do
      unquote(
        C.arguments(i)
        |> Enum.map(C.strict_equal_mapper(C.var(value)))
        |> Enum.reduce(&C.strict_or_reducer/2)
      )
    end
  end

  for i <- C.range() do
    # def partial_any?({arg1, arg2, arg3, _arg4}, 3) do
    #   arg1 || arg2 || arg3
    # end
    def partial_any?(unquote(C.array_with_wildcards(i)), unquote(i)) do
      unquote(
        C.arguments(i)
        |> Enum.reduce(&C.or_reducer/2)
      )
    end
  end

  for i <- C.range() do
    # def partial_any?({arg1, arg2, arg3, _arg4}, 3, fun) do
    #   fun.(arg1) || fun.(arg2) || fun.(arg3)
    # end
    def partial_any?(unquote(C.array_with_wildcards(i)), unquote(i), fun) do
      unquote(
        C.arguments(i)
        |> Enum.map(C.apply_mapper(C.var(fun)))
        |> Enum.reduce(&C.or_reducer/2)
      )
    end
  end

  for i <- C.range() do
    # def partial_all?({arg1, arg2, arg3, _arg4}, 3) do
    #   arg1 && arg2 && arg3
    # end
    def partial_all?(unquote(C.array_with_wildcards(i)), unquote(i)) do
      unquote(
        C.arguments(i)
        |> Enum.reduce(&C.and_reducer/2)
      )
    end
  end

  for i <- C.range() do
    # def partial_all?({arg1, arg2, arg3, _arg4}, 3, fun) do
    #   fun.(arg1) && fun.(arg2) && fun.(arg3)
    # end
    def partial_all?(unquote(C.array_with_wildcards(i)), unquote(i), fun) do
      unquote(
        C.arguments(i)
        |> Enum.map(C.apply_mapper(C.var(fun)))
        |> Enum.reduce(&C.and_reducer/2)
      )
    end
  end

  for i <- C.range() do
    # def partial_sum({arg1, arg2, arg3, _arg4}, 3, acc) do
    #   acc + arg1 + arg2 + arg3
    # end
    def partial_sum(unquote(C.array_with_wildcards(i)), unquote(i), acc) do
      unquote(
        C.arguments(i)
        |> Enum.reduce(C.var(acc), &C.sum_reducer/2)
      )
    end
  end

  for i <- C.range() do
    # def partial_product({arg1, arg2, arg3, _arg4}, 3, acc) do
    #   acc * arg1 * arg2 * arg3
    # end
    def partial_product(unquote(C.array_with_wildcards(i)), unquote(i), acc) do
      unquote(
        C.arguments(i)
        |> Enum.reduce(C.var(acc), &C.product_reducer/2)
      )
    end
  end

  def partial_intersperse(
        unquote(C.array_with_wildcards(1)),
        1,
        _separator
      ) do
    unquote(C.arguments(1))
  end

  # case i = 1 needs to declare `_separator`, not `separator`
  for i <- C.range(), i > 1 do
    # def partial_intersperse({arg1, arg2, arg3, _arg4}, 3, separator) do
    #   [arg1, separator, arg2, separator, arg3]
    # end
    def partial_intersperse(
          unquote(C.array_with_wildcards(i)),
          unquote(i),
          separator
        ) do
      unquote(
        C.arguments(i)
        |> Enum.intersperse(C.var(separator))
      )
    end
  end

  def partial_join_as_iodata(
        unquote(C.array_with_wildcards(1)),
        1,
        _separator
      ) do
    [to_string(unquote(C.argument_at(0)))]
  end

  # case i = 1 needs to declare `_separator`, not `separator`
  for i <- C.range(), i > 1 do
    # def partial_join_as_iodata({arg1, arg2, arg3, _arg4}, 3, separator) do
    #   [to_string(arg1), separator, to_string(arg2), separator, to_string(arg3)]
    # end
    def partial_join_as_iodata(
          unquote(C.array_with_wildcards(i)),
          unquote(i),
          separator
        ) do
      unquote(
        C.arguments(i)
        |> Enum.map_intersperse(C.var(separator), C.apply_mapper(C.var(&to_string/1)))
      )
    end
  end

  def complete_tail(tail, tail_size, values)

  def complete_tail(tail, _tail_size, []) do
    {tail, 0, []}
  end

  for i <- C.range() do
    # def complete_tail({arg1, arg2, _arg3, _arg4}, 2, [arg3, arg4 | rest]) do
    #   {{arg1, arg2, arg3, arg4}, 2, rest}
    # end
    def complete_tail(
          unquote(C.array_with_wildcards(i)),
          unquote(i),
          unquote(Enum.drop(C.arguments(), i) |> C.list_with_rest(C.var(rest)))
        ) do
      {unquote(C.array()), unquote(C.branch_factor() - i), rest}
    end
  end

  for i <- C.range() do
    # def complete_tail(tail, tail_size, [arg1, arg2]) do
    #   new_tail = put_elem(put_elem(tail, tail_size, arg1), tail_size + 1, arg2)
    #   {new_tail, 2, []}
    # end
    def complete_tail(tail, tail_size, unquote(C.arguments(i))) do
      new_tail =
        unquote(
          C.arguments(i)
          |> Enum.with_index()
          |> Enum.reduce(C.var(tail), fn {arg, index}, acc ->
            quote do
              put_elem(unquote(acc), var!(tail_size) + unquote(index), unquote(arg))
            end
          end)
        )

      {new_tail, unquote(i), []}
    end
  end

  def slice(tail, start, last) do
    do_slice(tail, start, last, [])
  end

  @compile {:inline, do_slice: 4}
  defp do_slice(tail, i, i, acc) do
    [elem(tail, i) | acc]
  end

  defp do_slice(tail, start, i, acc) do
    new_acc = [elem(tail, i) | acc]
    do_slice(tail, start, i - 1, new_acc)
  end

  def partial_with_index(tail, tail_size, offset)

  for i <- C.range() do
    # def partial_with_index({arg1, arg2, _arg3, _arg4}, 2, offset) do
    #   {{arg1, offset + 0}, {arg2, offset + 1}, nil, nil}
    # end
    def partial_with_index(unquote(C.array_with_wildcards(i)), unquote(i), offset) do
      unquote(
        C.arguments_with_nils(i)
        |> Enum.with_index()
        |> Enum.map(fn
          {nil, _} ->
            nil

          {arg, i} ->
            quote do
              {unquote(arg), var!(offset) + unquote(i)}
            end
        end)
        |> C.array()
      )
    end
  end
end
