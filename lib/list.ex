defmodule A.List do
  @moduledoc ~S"""
  Some extra helper functions for working with lists,
  that are not in the core `List` module.
  """

  @doc """
  Populates a list of size `n` by calling `generator_fun` repeatedly.

  ## Examples

      # Although not necessary, let's seed the random algorithm
      iex> :rand.seed(:exsplus, {1, 2, 3})
      iex> A.List.repeatedly(&:rand.uniform/0, 3)
      [0.40502929729990744, 0.45336720247823126, 0.04094511692041057]

      # It is basically just syntactic sugar for the following:
      iex> Stream.repeatedly(&:rand.uniform/0) |> Enum.take(3)

  ## Rationale

  - It has a consistent API with `Stream.repeatedly/1` and `List.duplicate/2`
  - It provides a less verbose way of writing one of the most common uses of `Stream.repeatedly/1`
  - It removes the temptation to write the following, which is more concise but is technically incorrect:

      iex> incorrect = fn n -> for _i <- 1..n, do: :rand.uniform() end
      iex> incorrect.(0) |> length()
      2
      # because:
      iex> Enum.to_list(1..0)
      [1, 0]

  This is the same problem that `A.ExRange` is addressing.
  """
  def repeatedly(generator_fun, n)
      when is_function(generator_fun, 0) and is_integer(n) and n >= 0 do
    Stream.repeatedly(generator_fun) |> Enum.take(n)
  end
end
