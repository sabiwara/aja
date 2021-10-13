defmodule Aja.Integer do
  @moduledoc ~S"""
  Some extra helper functions for working with integers,
  that are not in the core `Integer` module.
  """

  @thousand_decimals 3

  @compile {:inline, div_rem: 2, decimal_format: 2, do_format: 2, format_loop: 3}

  @doc """
  Returns both the result of `div/2` and `rem/2` at once.

  ## Examples

      iex> Aja.Integer.div_rem(7, 3)
      {2, 1}
      iex> Aja.Integer.div_rem(-99, 2)
      {-49, -1}
      iex> Aja.Integer.div_rem(100, 0)
      ** (ArithmeticError) bad argument in arithmetic expression

  """
  @spec div_rem(integer, pos_integer | neg_integer) :: {integer, integer}
  def div_rem(dividend, divisor)
      when is_integer(dividend) and is_integer(divisor) do
    {div(dividend, divisor), rem(dividend, divisor)}
  end

  @doc """
  Format integers for humans, with thousand separators.

  ## Examples

      iex> Aja.Integer.decimal_format(1_234_567)
      "1,234,567"
      iex> Aja.Integer.decimal_format(-123)
      "-123"
      iex> Aja.Integer.decimal_format(-1_234, separator: ?_)
      "-1_234"
  """
  def decimal_format(integer, opts \\ []) when is_integer(integer) and is_list(opts) do
    separator = Keyword.get(opts, :separator, ?,)

    integer
    |> do_format(separator)
    |> IO.iodata_to_binary()
  end

  defp do_format(integer, separator) when integer < 0 do
    [?- | do_format(-integer, separator)]
  end

  defp do_format(integer, separator) do
    integer
    |> Integer.to_string()
    |> format_loop([], separator)
  end

  defp format_loop(integer_string, acc, separator) do
    case byte_size(integer_string) - @thousand_decimals do
      offset when offset > 0 ->
        {rest, chunk} = String.split_at(integer_string, offset)
        format_loop(rest, [separator, chunk | acc], separator)

      _ ->
        [integer_string | acc]
    end
  end
end
