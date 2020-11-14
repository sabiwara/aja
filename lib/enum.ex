defmodule A.Enum do
  @moduledoc ~S"""
  Some extra helper functions for working with enumerables,
  that are not in the core `Enum` module.
  """

  @doc """
  Sorts the `enumerable` and removes duplicates.

  It is more efficient than calling `Enum.sort/1` followed by `Enum.uniq/1`,
  and slightly faster than `Enum.sort/1` followed by `Enum.dedup/1`.

  ## Examples

      iex> A.Enum.sort_uniq([1, 4, 2, 2, 3, 1, 4, 3])
      [1, 2, 3, 4]

  """
  def sort_uniq(enumerable) do
    enumerable
    |> Enum.sort()
    |> dedup()
  end

  @doc """
  Sorts the `enumerable` by the given function and removes duplicates.

  See `Enum.sort/2` for more details about how the second parameter works.

  ## Examples

      iex> A.Enum.sort_uniq([1, 4, 2, 2, 3, 1, 4, 3], &(&1 >= &2))
      [4, 3, 2, 1]
      iex> A.Enum.sort_uniq([1, 4, 2, 2, 3, 1, 4, 3], :asc)
      [1, 2, 3, 4]
      iex> A.Enum.sort_uniq([1, 4, 2, 2, 3, 1, 4, 3], :desc)
      [4, 3, 2, 1]
      iex> dates = [~D[2019-01-01], ~D[2020-03-02], ~D[2019-01-01], ~D[2020-03-02]]
      iex> A.Enum.sort_uniq(dates, {:desc, Date})
      [~D[2020-03-02], ~D[2019-01-01]]

  """
  def sort_uniq(enumerable, fun) do
    enumerable
    |> Enum.sort(fun)
    |> dedup()
  end

  defp dedup([]), do: []
  defp dedup([elem, elem | rest]), do: dedup([elem | rest])
  defp dedup([elem | rest]), do: [elem | dedup(rest)]
end
