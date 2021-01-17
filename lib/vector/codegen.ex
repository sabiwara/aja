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
  @range 1..@branch_factor

  @arguments_ast Macro.generate_arguments(@branch_factor, nil)
  @wildcard quote do: _

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

  defmacro radix_search(index, level) do
    quote do
      unquote(index)
      |> Bitwise.>>>(unquote(level))
      |> Bitwise.&&&(unquote(@branch_factor - 1))
    end
  end

  def range do
    @range
  end

  def block(lines) when is_list(lines) do
    {:__block__, [], lines}
  end

  def array() do
    do_array(@arguments_ast)
  end

  def array(args) do
    args
    |> validate_args_length()
    |> do_array()
  end

  def array_ast() do
    {:{}, [], [:{}, [], @arguments_ast]}
  end

  def array_ast(args) do
    validate_args_length(args)

    {:{}, [], [:{}, [], args]}
  end

  def arguments do
    @arguments_ast
  end

  for i <- @range do
    def arguments(unquote(i)) do
      unquote(
        @arguments_ast
        |> Enum.take(i)
        |> Macro.escape()
      )
    end
  end

  for i <- @range do
    def argument_at(unquote(i - 1)) do
      unquote(
        @arguments_ast
        |> Enum.at(i - 1)
        |> Macro.escape()
      )
    end
  end

  def reversed_arguments() do
    unquote(
      @arguments_ast
      |> Enum.reverse()
      |> Macro.escape()
    )
  end

  for i <- @range do
    def reversed_arguments(unquote(i)) do
      unquote(
        @arguments_ast
        |> Enum.take(i)
        |> Enum.reverse()
        |> Macro.escape()
      )
    end
  end

  def duplicate_argument(arg) do
    List.duplicate(arg, @branch_factor)
  end

  for i <- @range do
    def arguments_with_nils(unquote(i)) do
      unquote(
        @arguments_ast
        |> Enum.take(i)
        |> Kernel.++(List.duplicate(nil, @branch_factor - i))
        |> Macro.escape()
      )
    end
  end

  for i <- @range do
    def arguments_with_wildcards(unquote(i)) do
      unquote(
        @arguments_ast
        |> Enum.take(i)
        |> Kernel.++(List.duplicate(@wildcard, @branch_factor - i))
        |> Macro.escape()
      )
    end
  end

  for i <- 1..(@branch_factor - 1) do
    def arguments_with_nil_then_wildcards(unquote(i)) do
      unquote(
        @arguments_ast
        |> Enum.take(i)
        |> Kernel.++([nil])
        |> Kernel.++(List.duplicate(@wildcard, @branch_factor - 1 - i))
        |> Macro.escape()
      )
    end
  end

  def arguments_with_nil_then_wildcards(@branch_factor) do
    @arguments_ast
  end

  def array_with_wildcards(n) do
    n
    |> arguments_with_wildcards()
    |> do_array()
  end

  def array_with_nils(n) do
    n
    |> arguments_with_nils()
    |> do_array()
  end

  def array_with_nil_then_wildcards(n) do
    n
    |> arguments_with_nil_then_wildcards()
    |> do_array()
  end

  def value_with_nils(value) do
    [value] |> fill_with(nil)
  end

  def fill_with(args, value) do
    missing = @branch_factor - length(args)
    args ++ List.duplicate(value, missing)
  end

  def map_until(args \\ @arguments_ast, n, fun) when is_integer(n) and is_function(fun, 1) do
    args
    |> Enum.with_index()
    |> Enum.map(fn
      {arg, i} when i < n -> fun.(arg)
      {arg, _} -> arg
    end)
  end

  def list_with_rest(args \\ @arguments_ast, rest_variable) do
    case length(args) do
      0 ->
        rest_variable

      len ->
        List.update_at(args, len - 1, fn last_arg ->
          quote do
            unquote(last_arg) | unquote(rest_variable)
          end
        end)
    end
  end

  defmacro var(variable) do
    Macro.escape(variable)
  end

  defp validate_args_length(args) do
    # raise on unexpected args
    unquote(@branch_factor) = length(args)

    args
  end

  def do_array(args) do
    {:{}, [], args}
  end

  def sparse_map(args, fun) do
    Enum.map(args, fn
      nil -> nil
      arg -> fun.(arg)
    end)
  end

  # MAPPERS

  def apply_mapper(fun) do
    fn arg ->
      quote do
        unquote(fun).(unquote(arg))
      end
    end
  end

  def apply_sparse_mapper(fun) do
    fn
      nil ->
        nil

      arg ->
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

  def product_reducer(arg, acc) do
    quote do
      unquote(acc) * unquote(arg)
    end
  end

  def strict_or_reducer(arg, acc) do
    quote do
      unquote(acc) or unquote(arg)
    end
  end

  def or_reducer(arg, acc) do
    quote do
      unquote(acc) || unquote(arg)
    end
  end

  def strict_and_reducer(arg, acc) do
    quote do
      unquote(acc) and unquote(arg)
    end
  end

  def and_reducer(arg, acc) do
    quote do
      unquote(acc) && unquote(arg)
    end
  end
end
