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

  # def partial_member?({arg1, arg2, arg3, _arg4}, size, value) do
  #   cond do
  #     arg1 === value -> true
  #     size === 1 -> false
  #     arg2 === value -> true
  #     size === 2 -> false
  #     arg3 === value -> true
  #     size === 3 -> false
  #     arg4 === value -> true
  #     true -> false
  #   end
  # end
  def partial_member?(unquote(C.array()), size, value) do
    C.find_cond_tail size do
      arg === value -> true
      _ -> false
    end
  end

  # def partial_any?({arg1, arg2, arg3, arg4}, size) do
  #   cond do
  #     arg1 -> true
  #     size === 1 -> false
  #     arg2 -> true
  #     size === 2 -> false
  #     arg3 -> true
  #     size === 3 -> false
  #     arg4 -> true
  #     true -> false
  #   end
  # end
  def partial_any?(unquote(C.array()), size) do
    C.find_cond_tail size do
      arg -> true
      _ -> false
    end
  end

  # def partial_any?({arg1, arg2, arg3, arg4}, size, fun) do
  #   cond do
  #     fun.(arg1) -> true
  #     size === 1 -> false
  #     fun.(arg2) -> true
  #     size === 2 -> false
  #     fun.(arg3) -> true
  #     size === 3 -> false
  #     fun.(arg4) -> true
  #     true -> false
  #   end
  # end
  def partial_any?(unquote(C.array()), size, fun) do
    C.find_cond_tail size do
      fun.(arg) -> true
      _ -> false
    end
  end

  # def partial_all?({arg1, arg2, arg3, arg4}, size) do
  #   cond do
  #     !arg1 -> false
  #     size === 1 -> true
  #     !arg2 -> false
  #     size === 2 -> true
  #     !arg3 -> false
  #     size === 3 -> true
  #     !arg4 -> false
  #     true -> true
  #   end
  # end
  def partial_all?(unquote(C.array()), size) do
    C.find_cond_tail size do
      !arg -> false
      _ -> true
    end
  end

  # def partial_all?({arg1, arg2, arg3, arg4}, size, fun) do
  #   cond do
  #     !fun.(arg1) -> false
  #     size === 1 -> true
  #     !fun.(arg2) -> false
  #     size === 2 -> true
  #     !fun.(arg3) -> false
  #     size === 3 -> true
  #     !fun.(arg4) -> false
  #     true -> true
  #   end
  # end
  def partial_all?(unquote(C.array()), size, fun) do
    C.find_cond_tail size do
      !fun.(arg) -> false
      _ -> true
    end
  end

  def partial_find(unquote(C.array()), size, fun) do
    C.find_cond_tail size do
      fun.(arg) -> {:ok, arg}
      _ -> nil
    end
  end

  def partial_find_value(unquote(C.array()), size, fun) do
    C.find_cond_tail size do
      value = fun.(arg) -> value
      _ -> nil
    end
  end

  def partial_find_index(unquote(C.array()), size, fun) do
    C.find_cond_tail size do
      fun.(arg) -> i
      _ -> nil
    end
  end

  def partial_find_falsy_index(unquote(C.array()), size, fun) do
    C.find_cond_tail size do
      !fun.(arg) -> i
      _ -> nil
    end
  end

  def partial_intersperse(tail, size, separator) do
    value = :erlang.element(size, tail)
    do_partial_intersperse(tail, size - 1, separator, [value])
  end

  @compile {:inline, do_partial_intersperse: 4}
  defp do_partial_intersperse(_tail, _erl_index = 0, _separator, acc), do: acc

  defp do_partial_intersperse(tail, erl_index, separator, acc) do
    value = :erlang.element(erl_index, tail)
    new_acc = [value, separator | acc]
    do_partial_intersperse(tail, erl_index - 1, separator, new_acc)
  end

  def partial_join_as_iodata(tail, size, separator) do
    value = :erlang.element(size, tail) |> to_string()
    do_partial_join_as_iodata(tail, size - 1, separator, [value])
  end

  @compile {:inline, do_partial_join_as_iodata: 4}
  defp do_partial_join_as_iodata(_tail, _erl_index = 0, _separator, acc), do: acc

  defp do_partial_join_as_iodata(tail, erl_index, separator, acc) do
    value = :erlang.element(erl_index, tail) |> to_string()
    new_acc = [value, separator | acc]
    do_partial_join_as_iodata(tail, erl_index - 1, separator, new_acc)
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

  def partial_zip(tail1, tail2, tail_size)

  for i <- C.range() do
    # def partial_zip(tail1, tail2, 2) do
    #   {{elem(tail1, 0), elem(tail2, 0)}, {elem(tail1, 1), elem(tail2, 1)}, nil, nil}
    # end
    def partial_zip(tail1, tail2, unquote(i)) do
      unquote(
        Enum.map(C.range(), fn
          j when j <= i ->
            quote do
              {:erlang.element(unquote(j), var!(tail1)), :erlang.element(unquote(j), var!(tail2))}
            end

          _ ->
            nil
        end)
        |> C.array()
      )
    end
  end

  def partial_unzip(tail, tail_size)

  for i <- C.range() do
    # def partial_zip({{arg1, arg5}, {arg2, arg6}, _, _}, 2) do
    #   {{arg1, arg2, nil, nil}, {arg5, arg6, nil, nil}}
    # end
    def partial_unzip(
          unquote(
            Enum.zip(C.arguments(i), C.other_arguments(i))
            |> C.fill_with(nil)
            |> C.array()
          ),
          unquote(i)
        ) do
      {
        unquote(C.arguments(i) |> C.fill_with(nil) |> C.array()),
        unquote(C.other_arguments(i) |> C.fill_with(nil) |> C.array())
      }
    end
  end
end
