defmodule Aja.Vector.Tail do
  @moduledoc false

  require Aja.Vector.CodeGen, as: C

  alias Aja.Vector.Node

  @type t(value) :: Node.t(value | nil)

  def append(
        unquote(C.arguments(C.branch_factor() - 1) |> C.left_fill_with(nil) |> C.array()),
        value
      ) do
    unquote(C.array(C.arguments(C.branch_factor() - 1) ++ [C.var(value)]))
  end

  def delete_last(unquote(C.array_with_wildcards(C.branch_factor() - 1))) do
    unquote(
      quote do
        unquote(C.array([nil | C.arguments(C.branch_factor() - 1)]))
      end
    )
  end

  def partial_map(unquote(C.array()), fun, tail_size) do
    unquote(
      C.arguments()
      |> Enum.with_index()
      |> Enum.map(fn {arg, index} ->
        quote do
          case var!(tail_size) >= unquote(C.branch_factor() - index) do
            true -> var!(fun).(unquote(arg))
            _ -> unquote(arg)
          end
        end
      end)
      |> C.array()
    )
  end

  for i <- C.range() do
    # def partial_to_list({_, _, arg1, arg2}, 2) do
    #   [arg1, arg2]
    # end
    def partial_to_list(unquote(C.array_with_left_wildcards(i)), unquote(i)) do
      unquote(C.arguments(i))
    end
  end

  # def from_incomplete_list([arg1, arg2]) do
  #   {nil, nil, arg1, arg2}
  # end
  for i <- C.range() do
    def partial_from_list(unquote(C.arguments(i))) do
      unquote(C.arguments(i) |> C.left_fill_with(nil) |> C.array())
    end
  end

  def partial_take(node, shifted_amount)

  for i <- C.range() do
    # def take({arg1, arg2, _arg3, _arg4}, _shifted_amount = 2) do
    #   {nil, nil, arg1, arg2}
    # end
    def partial_take(
          unquote(C.array_with_wildcards(i)),
          _shifted_amount = unquote(C.branch_factor() - i)
        ) do
      unquote(C.arguments(i) |> C.left_fill_with(nil) |> C.array())
    end
  end

  for i <- C.range() do
    # def partial_duplicate(value, 2) do
    #   {nil, nil, value, value}
    # end
    def partial_duplicate(value, unquote(i)) do
      unquote(
        List.duplicate(C.var(value), i)
        |> C.left_fill_with(nil)
        |> C.array()
      )
    end
  end

  # def partial_member?({arg4, arg3, arg2, arg1}, size, value) do
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
  def partial_member?(unquote(C.reversed_arguments() |> C.array()), size, value) do
    C.find_cond_tail size do
      arg === value -> true
      _ -> false
    end
  end

  # def partial_any?({arg4, arg3, arg2, arg1}, size) do
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
  def partial_any?(unquote(C.reversed_arguments() |> C.array()), size) do
    C.find_cond_tail size do
      arg -> true
      _ -> false
    end
  end

  # def partial_all?({arg4, arg3, arg2, arg1}, size) do
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
  def partial_all?(unquote(C.reversed_arguments() |> C.array()), size) do
    C.find_cond_tail size do
      !arg -> false
      _ -> true
    end
  end

  @compile {:inline, partial_any?: 3}
  def partial_any?(tail, start, fun)

  def partial_any?(_tail, _i = C.branch_factor(), _fun), do: false

  def partial_any?(tail, i, fun) do
    i = i + 1
    value = :erlang.element(i, tail)

    if fun.(value) do
      true
    else
      partial_any?(tail, i, fun)
    end
  end

  @compile {:inline, partial_all?: 3}
  def partial_all?(tail, start, fun)

  def partial_all?(_tail, _i = C.branch_factor(), _fun), do: true

  def partial_all?(tail, i, fun) do
    i = i + 1
    value = :erlang.element(i, tail)

    if fun.(value) do
      partial_all?(tail, i, fun)
    else
      false
    end
  end

  @compile {:inline, partial_find: 3}
  def partial_find(tail, start, fun)

  def partial_find(_tail, _i = C.branch_factor(), _fun), do: nil

  def partial_find(tail, i, fun) do
    i = i + 1
    value = :erlang.element(i, tail)

    if fun.(value) do
      {:ok, value}
    else
      partial_find(tail, i, fun)
    end
  end

  @compile {:inline, partial_find_value: 3}
  def partial_find_value(tail, start, fun)

  def partial_find_value(_tail, _i = C.branch_factor(), _fun), do: nil

  def partial_find_value(tail, i, fun) do
    i = i + 1
    value = :erlang.element(i, tail) |> fun.()

    if value do
      value
    else
      partial_find_value(tail, i, fun)
    end
  end

  @compile {:inline, partial_find_index: 3}
  def partial_find_index(tail, start, fun)

  def partial_find_index(_tail, _i = C.branch_factor(), _fun), do: nil

  def partial_find_index(tail, i, fun) do
    i2 = i + 1
    value = :erlang.element(i2, tail)

    if fun.(value) do
      i
    else
      partial_find_index(tail, i2, fun)
    end
  end

  @compile {:inline, partial_find_falsy_index: 3}
  def partial_find_falsy_index(tail, start, fun)

  def partial_find_falsy_index(_tail, _i = C.branch_factor(), _fun), do: nil

  def partial_find_falsy_index(tail, i, fun) do
    i2 = i + 1
    value = :erlang.element(i2, tail)

    if fun.(value) do
      partial_find_falsy_index(tail, i2, fun)
    else
      i
    end
  end

  def complete_tail(tail, tail_size, values)

  def complete_tail(tail, _tail_size, []) do
    {tail, 0, []}
  end

  def complete_tail(tail, _tail_size = C.branch_factor(), rest) do
    {tail, 0, rest}
  end

  for i <- C.range() |> Enum.drop(-1) do
    # def complete_tail({_, _, arg1, arg2}, tail_size, [arg3, arg4 | rest]) when tail_size <= 2 do
    #   {{arg1, arg2, arg3, arg4}, 2, rest}
    # end
    def complete_tail(
          unquote(C.array_with_left_wildcards(i)),
          tail_size,
          unquote(Enum.drop(C.arguments(), i) |> C.list_with_rest(C.var(rest)))
        )
        when tail_size <= unquote(i) do
      {unquote(C.array()), unquote(C.branch_factor() - i), rest}
    end
  end

  def slice(tail, start, last, tail_size) do
    offset = C.branch_factor() - tail_size
    do_slice(tail, start + offset, last + offset + 1, [])
  end

  @compile {:inline, do_slice: 4}
  defp do_slice(_tail, i, i, acc) do
    acc
  end

  defp do_slice(tail, start, i, acc) do
    new_acc = [:erlang.element(i, tail) | acc]
    do_slice(tail, start, i - 1, new_acc)
  end

  def partial_map_reduce(tail, _i = C.branch_factor(), acc, _fun), do: {tail, acc}

  def partial_map_reduce(tail, i, acc, fun) do
    i = i + 1
    value = :erlang.element(i, tail)
    {new_value, new_acc} = fun.(value, acc)
    new_tail = :erlang.setelement(i, tail, new_value)
    partial_map_reduce(new_tail, i, new_acc, fun)
  end

  def partial_scan(tail, _i = C.branch_factor(), _acc, _fun), do: tail

  def partial_scan(tail, i, acc, fun) do
    i = i + 1
    value = :erlang.element(i, tail)
    new_acc = fun.(value, acc)
    new_tail = :erlang.setelement(i, tail, new_acc)
    partial_scan(new_tail, i, new_acc, fun)
  end

  def partial_with_index(tail, tail_size, offset)

  def partial_with_index(tail, _i = C.branch_factor(), _offset), do: tail

  def partial_with_index(tail, i, offset) do
    i = i + 1
    value = :erlang.element(i, tail)
    new_tail = :erlang.setelement(i, tail, {value, offset})
    partial_with_index(new_tail, i, offset + 1)
  end

  def partial_with_index(tail, start, offset, fun)

  def partial_with_index(tail, _i = C.branch_factor(), _offset, _fun), do: tail

  def partial_with_index(tail, i, offset, fun) do
    i = i + 1
    value = :erlang.element(i, tail)
    new_tail = :erlang.setelement(i, tail, fun.(value, offset))
    partial_with_index(new_tail, i, offset + 1, fun)
  end

  def partial_zip(tail1, tail2, start)

  def partial_zip(tail1, _tail2, _i = C.branch_factor()), do: tail1

  def partial_zip(tail1, tail2, i) do
    i = i + 1
    value1 = :erlang.element(i, tail1)
    value2 = :erlang.element(i, tail2)
    new_tail = :erlang.setelement(i, tail1, {value1, value2})
    partial_zip(new_tail, tail2, i)
  end

  def partial_zip_with(tail1, tail2, start, fun)

  def partial_zip_with(tail1, _tail2, _i = C.branch_factor(), _fun), do: tail1

  def partial_zip_with(tail1, tail2, i, fun) do
    i = i + 1
    value1 = :erlang.element(i, tail1)
    value2 = :erlang.element(i, tail2)
    new_tail = :erlang.setelement(i, tail1, fun.(value1, value2))
    partial_zip_with(new_tail, tail2, i, fun)
  end

  def partial_unzip(tail, start) do
    do_partial_unzip(tail, tail, start)
  end

  defp do_partial_unzip(left, right, _i = C.branch_factor()) do
    {left, right}
  end

  defp do_partial_unzip(left, right, i) do
    i = i + 1
    {value1, value2} = :erlang.element(i, left)
    new_left = :erlang.setelement(i, left, value1)
    new_right = :erlang.setelement(i, right, value2)
    do_partial_unzip(new_left, new_right, i)
  end
end
