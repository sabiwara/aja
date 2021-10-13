defmodule Aja.List do
  @moduledoc ~S"""
  Some extra helper functions for working with lists,
  that are not in the core `List` module.
  """

  @compile {:inline, prepend: 2, do_repeat: 3}

  @doc """
  Prepends an element to a list, equivalent of `[elem | list]` that can be used in a pipe.

  ## Examples

      iex> [2, 3, 5, 8] |> Aja.List.prepend(1)
      [1, 2, 3, 5, 8]

  """
  def prepend(list, elem) do
    [elem | list]
  end

  @doc """
  Populates a list of size `n` by calling `generator_fun` repeatedly.

  ## Examples

      # Although not necessary, let's seed the random algorithm
      iex> :rand.seed(:exrop, {1, 2, 3})
      iex> Aja.List.repeat(&:rand.uniform/0, 3)
      [0.7498295129076106, 0.06161655489244533, 0.7924073127680873]

      # It is basically just syntactic sugar for the following:
      iex> Stream.repeatedly(&:rand.uniform/0) |> Enum.take(3)

  ## Rationale

  - It offers has a consistent API with `Stream.repeatedly/1` and `List.duplicate/2`
  - It provides a less verbose way of writing one of the most common uses of `Stream.repeatedly/1`
  - (before Elixir 1.12) It removes the temptation to write the following, which is more concise but is technically incorrect:

        iex> incorrect = fn n -> for _i <- 1..n, do: :rand.uniform() end
        iex> incorrect.(0) |> length()
        2
        iex> Enum.to_list(1..0)  # <- because of this
        [1, 0]

    Elixir 1.12 solved this problem by introducing a step, `1..n//1`.

  - It is more efficient

  """
  def repeat(generator_fun, n)
      when is_function(generator_fun, 0) and is_integer(n) and n >= 0 do
    do_repeat(generator_fun, n, [])
  end

  defp do_repeat(_generator_fun, 0, acc), do: :lists.reverse(acc)

  defp do_repeat(generator_fun, n, acc) do
    new_acc = [generator_fun.() | acc]
    do_repeat(generator_fun, n - 1, new_acc)
  end
end
