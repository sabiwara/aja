defmodule A.Vector.Node do
  @moduledoc false

  import A.Vector.CodeGen

  # @type t(value) :: {value, value, value, value}
  array_type(t(value), value)

  def update_at(tuple, index, fun) do
    # Benchmarks showed that generating pattern matching clauses was not faster
    value = elem(tuple, index)
    put_elem(tuple, index, fun.(value))
  end

  # def from_list([arg1, arg2, arg3, arg4]) do
  #   {arg1, arg2, arg3, arg4}
  # end
  def from_list(arguments()) do
    array(arguments())
  end

  # def from_incomplete_list([arg1, arg2]) do
  #   {arg1, arg2, nil, nil}
  # end
  for i <- args_range() do
    def from_incomplete_list(take_arguments(unquote(i))) do
      array(arguments_with_nils(unquote(i)))
    end
  end

  # def from_incomplete_reverse_list([arg1, arg2]) do
  #   {arg2, arg1, nil, nil}
  # end
  for i <- args_range() do
    def from_incomplete_reverse_list(take_arguments(unquote(i))) do
      array(partial_arguments_with_nils(reverse_arguments(take_arguments(unquote(i)))))
    end
  end

  # def ast_from_incomplete_list([arg1, arg2]) do
  #   {:{}, [], [arg1, arg2, nil, nil]}
  # end
  for i <- args_range() do
    def ast_from_incomplete_list(take_arguments(unquote(i))) do
      array_ast(arguments_with_nils(unquote(i)))
    end
  end

  # def to_list({arg1, arg2, arg3, arg4}) do
  #   [arg1, arg2, arg3, arg4]
  # end
  def to_list(array()) do
    arguments()
  end

  # def duplicate(value) do
  #   {value, value, value, value}
  # end
  def duplicate(value) do
    array(duplicate_argument(value))
  end

  # def foldl({arg1, arg2, arg3, arg4}, acc, f) do
  #   f(arg4, f(arg3, f(arg2, f(arg1, acc))))
  # end
  def foldl(array(arguments()), acc, fun) do
    reduce_arguments(arguments(), acc, fn arg, acc ->
      quote do
        var!(fun).(unquote(arg), unquote(acc))
      end
    end)
  end

  # def foldr({arg1, arg2, arg3, arg4}, acc, f) do
  #   f(arg1, f(arg2, f(arg3, f(arg4, acc))))
  # end
  def foldr(array(arguments()), acc, fun) do
    reduce_arguments(reverse_arguments(), acc, fn arg, acc ->
      quote do
        var!(fun).(unquote(arg), unquote(acc))
      end
    end)
  end
end
