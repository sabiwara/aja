defmodule A.Vector.Node do
  @moduledoc false

  alias A.Vector.CodeGen, as: C
  require C

  # @type t(value) :: {value, value, value, value}
  C.array_type(t(value), value)

  def update_at(tuple, index, fun) do
    # Benchmarks showed that generating pattern matching clauses was not faster
    value = elem(tuple, index)
    put_elem(tuple, index, fun.(value))
  end

  # def from_list([arg1, arg2, arg3, arg4]) do
  #   {arg1, arg2, arg3, arg4}
  # end
  def from_list(unquote(C.arguments())) do
    unquote(C.array())
  end

  # def from_incomplete_list([arg1, arg2]) do
  #   {arg1, arg2, nil, nil}
  # end
  for i <- C.range() do
    def from_incomplete_list(unquote(C.arguments(i))) do
      unquote(C.array_with_nils(i))
    end
  end

  # def from_incomplete_reverse_list([arg1, arg2]) do
  #   {arg2, arg1, nil, nil}
  # end
  for i <- C.range() do
    def from_incomplete_reverse_list(unquote(C.arguments(i))) do
      unquote(
        C.reversed_arguments(i)
        |> C.fill_with(nil)
        |> C.array()
      )
    end
  end

  # def ast_from_incomplete_list([arg1, arg2]) do
  #   {:{}, [], [arg1, arg2, nil, nil]}
  # end
  for i <- C.range() do
    def ast_from_incomplete_list(unquote(C.arguments(i))) do
      unquote(C.array_ast(C.arguments_with_nils(i)))
    end
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
