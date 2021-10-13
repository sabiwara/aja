defmodule Aja.Vector.Node do
  @moduledoc false

  require Aja.Vector.CodeGen, as: C

  # @type t(value) :: {value, value, value, value}
  C.array_type(t(value), value)

  def update_at(tuple, index, fun) do
    # Benchmarks showed that generating pattern matching clauses was not faster
    value = elem(tuple, index)
    put_elem(tuple, index, fun.(value))
  end

  # def from_incomplete_list([arg1, arg2]) do
  #   {arg1, arg2, nil, nil}
  # end
  for i <- C.range() do
    def from_incomplete_list(unquote(C.arguments(i))) do
      unquote(C.array_with_nils(i))
    end
  end

  # def from_incomplete_reverse_list([arg2, arg1]) do
  #   {arg1, arg2, nil, nil}
  # end
  for i <- C.range() do
    def from_incomplete_reverse_list(unquote(C.arguments(i) |> Enum.reverse())) do
      unquote(C.array_with_nils(i))
    end
  end

  # def from_offset_nodes({_, _, _, arg1}, {arg2, arg3, arg4, _}, 3) do
  #   {arg1, arg2, arg3, arg4}
  # end
  for i <- C.range() do
    def from_offset_nodes(
          unquote(C.array_with_left_wildcards(i)),
          unquote(C.array_with_complement_wildcards(i)),
          unquote(C.branch_factor() - i)
        ) do
      unquote(C.array())
    end
  end

  # def shift(node, offset) do
  #   {elem(node, (0 + offset) &&& 15), elem(node, (1 + offset) &&& 15), ...}
  # end
  def shift(node, offset) do
    unquote(
      Enum.map(C.range(), fn i ->
        quote do
          elem(var!(node), C.radix_rem(unquote(i - 1) + var!(offset)))
        end
      end)
      |> C.array()
    )
  end

  # def to_list({arg1, arg2, arg3, arg4}) do
  #   [arg1, arg2, arg3, arg4]
  # end
  def to_list(unquote(C.array())) do
    unquote(C.arguments())
  end

  # def prepend_all({arg1, arg2, arg3, arg4}, acc) do
  #   [arg1, arg2, arg3, arg4 | acc]
  # end
  def prepend_all(unquote(C.array()), acc) do
    unquote(C.list_with_rest(C.var(acc)))
  end

  # def duplicate(value) do
  #   {value, value, value, value}
  # end
  def duplicate(value) do
    unquote(
      C.var(value)
      |> C.duplicate_argument()
      |> C.array()
    )
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

  def take(node, amount)

  for i <- C.range() do
    # def take({arg1, arg2, _arg3, _arg4}, _amount = 2) do
    #   {arg1, arg2, nil, nil}
    # end
    def take(unquote(C.array_with_wildcards(i)), _amount = unquote(i)) do
      unquote(C.array_with_nils(i))
    end
  end
end
