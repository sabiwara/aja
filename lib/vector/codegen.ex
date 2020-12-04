defmodule A.Vector.CodeGen do
  @moduledoc false

  # Notes: averaged overhead
  # Enum.sum(for i <- 1..100, do: A.Vector.new(1..i) |> :erts_debug.size_shared()) / 100

  # 2^3 = 8 -> 87.2
  # 2^4 = 16 -> 86.96
  # 2^5 = 32 -> 93.56
  # :array -> 77.3

  # Notes: averaged over 1..1000, the trend is the opposite (:array 638.18, vec32 577.016)

  @bits 4
  @branch_factor :math.pow(2, @bits) |> round()

  @arguments_ast Macro.generate_arguments(@branch_factor, nil)
  @wildcard quote do: _

  defp expand_validate_args(args, caller) do
    expanded_args = Macro.expand(args, caller)
    unquote(@branch_factor) = length(expanded_args)
    expanded_args
  end

  defmacro bits do
    @bits
  end

  defmacro branch_factor do
    @branch_factor
  end

  defmacro incr_level(level) do
    quote do
      unquote(level) + unquote(@bits)
    end
  end

  defmacro decr_level(level) do
    quote do
      unquote(level) - unquote(@bits)
    end
  end

  defmacro radix_div(i) do
    quote do
      Bitwise.>>>(unquote(i), unquote(@bits))
    end
  end

  defmacro radix_rem(i) do
    quote do
      Bitwise.&&&(unquote(i), unquote(@branch_factor - 1))
    end
  end

  defmacro array_type(declaration, value) do
    quote do
      @type unquote(declaration) :: unquote({:{}, [], List.duplicate(value, @branch_factor)})
    end
  end

  defmacro args_range do
    quote do
      1..unquote(@branch_factor)
    end
  end

  defmacro radix_search(index, level) do
    quote do
      unquote(index)
      |> Bitwise.>>>(unquote(level))
      |> Bitwise.&&&(unquote(@branch_factor - 1))
    end
  end

  defmacro array(args \\ @arguments_ast) do
    expanded_args = expand_validate_args(args, __CALLER__)
    {:{}, [], expanded_args}
  end

  defmacro array_ast(args \\ @arguments_ast) do
    expanded_args = expand_validate_args(args, __CALLER__)
    {:{}, [], [:{}, [], expanded_args]}
  end

  defmacro arguments do
    @arguments_ast
  end

  defmacro argument_at(n) do
    expanded_n = Macro.expand(n, __CALLER__)
    Enum.at(@arguments_ast, expanded_n)
  end

  defmacro reverse_arguments(args \\ @arguments_ast) do
    # note: not only reversing full arguments, no validation
    # do not use expand_validate_args
    expanded_args = Macro.expand(args, __CALLER__)
    Enum.reverse(expanded_args)
  end

  defmacro duplicate_argument(arg) do
    List.duplicate(arg, @branch_factor)
  end

  defmacro arguments_with_wildcards(args \\ @arguments_ast, n) do
    expanded_args = expand_validate_args(args, __CALLER__)
    expanded_n = Macro.expand(n, __CALLER__)
    arguments_with_filler(expanded_args, expanded_n, @wildcard)
  end

  defmacro arguments_with_nils(args \\ @arguments_ast, n) do
    expanded_args = expand_validate_args(args, __CALLER__)
    expanded_n = Macro.expand(n, __CALLER__)
    arguments_with_filler(expanded_args, expanded_n, nil)
  end

  defmacro partial_arguments_with_nils(args) do
    expanded_args = Macro.expand(args, __CALLER__)
    arguments_with_filler(expanded_args, length(expanded_args), nil)
  end

  defmacro value_with_nils(value) do
    arguments_with_filler([value], 1, nil)
  end

  defmacro list_with_rest(args \\ @arguments_ast, rest_variable) do
    # note: is used with args len != branch factor
    # do not use expand_validate_args
    expanded_args = Macro.expand(args, __CALLER__)

    case length(expanded_args) do
      0 ->
        rest_variable

      len ->
        List.update_at(expanded_args, len - 1, fn last_arg ->
          quote do
            unquote(last_arg) | unquote(rest_variable)
          end
        end)
    end
  end

  defmacro map_arguments(args \\ @arguments_ast, fun_ast) do
    expanded_args = Macro.expand(args, __CALLER__)
    fun = Code.eval_quoted(fun_ast, [], __CALLER__) |> get_eval_fun(1)

    for arg <- expanded_args do
      fun.(arg)
    end
  end

  defmacro reduce_arguments(args, fun_ast) do
    expanded_args = Macro.expand(args, __CALLER__)
    fun = Code.eval_quoted(fun_ast, [], __CALLER__) |> get_eval_fun(2)

    Enum.reduce(expanded_args, fun)
  end

  defmacro reduce_arguments(args, acc, fun_ast) do
    expanded_args = Macro.expand(args, __CALLER__)
    fun = Code.eval_quoted(fun_ast, [], __CALLER__) |> get_eval_fun(2)

    Enum.reduce(expanded_args, acc, fun)
  end

  defmacro reduce_arguments_with_index(args, acc, fun_ast) do
    expanded_args = Macro.expand(args, __CALLER__)
    fun = Code.eval_quoted(fun_ast, [], __CALLER__) |> get_eval_fun(3)

    expanded_args
    |> Enum.with_index()
    |> Enum.reduce(acc, fn {arg, index}, acc ->
      fun.(arg, index, acc)
    end)
  end

  defp get_eval_fun({fun, _}, arity) when is_function(fun, arity) do
    fun
  end

  defmacro take_arguments(args \\ @arguments_ast, n) do
    expanded_args = expand_validate_args(args, __CALLER__)
    expanded_n = Macro.expand(n, __CALLER__)

    Enum.take(expanded_args, expanded_n)
  end

  defmacro take_drop_arguments(args1, args2, n) do
    expanded_args1 = expand_validate_args(args1, __CALLER__)
    expanded_args2 = expand_validate_args(args2, __CALLER__)
    expanded_n = Macro.expand(n, __CALLER__)

    Enum.take(expanded_args1, expanded_n) ++ Enum.drop(expanded_args2, expanded_n)
  end

  defmacro drop_arguments(args \\ @arguments_ast, n) do
    expanded_args = Macro.expand(args, __CALLER__)
    expanded_n = Macro.expand(n, __CALLER__)

    Enum.drop(expanded_args, expanded_n)
  end

  defmacro var(variable) do
    Macro.escape(variable)
  end

  defp arguments_with_filler(args, n, filler) when n >= 0 and n <= @branch_factor do
    fillers = List.duplicate(filler, @branch_factor - n)
    Enum.take(args, n) ++ fillers
  end

  # MAPPERS

  def apply_mapper(fun) do
    fn arg ->
      quote do
        unquote(fun).(unquote(arg))
      end
    end
  end

  def strict_equal_mapper(val) do
    fn arg ->
      quote do
        unquote(arg) === unquote(val)
      end
    end
  end

  # REDUCERS

  def sum_reducer(arg, acc) do
    quote do
      unquote(acc) + unquote(arg)
    end
  end

  def strict_or_reducer(arg, acc) do
    quote do
      unquote(arg) or unquote(acc)
    end
  end

  def or_reducer(arg, acc) do
    quote do
      unquote(arg) || unquote(acc)
    end
  end

  def strict_and_reducer(arg, acc) do
    quote do
      unquote(arg) and unquote(acc)
    end
  end

  def and_reducer(arg, acc) do
    quote do
      unquote(arg) && unquote(acc)
    end
  end

  def intersperse_reducer(element) do
    fn arg, acc ->
      quote do
        [unquote(arg), unquote(element) | unquote(acc)]
      end
    end
  end
end
