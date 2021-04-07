defmodule A.ExRange do
  @moduledoc false

  import A, only: [~>: 2]

  @type t :: %__MODULE__{start: integer, stop: integer}
  @enforce_keys [:start, :stop]
  defstruct [:start, :stop]

  # TODO remove in 0.6
  @doc false
  @deprecated "Use first..last//1 instead"
  def new(start \\ 0, stop)

  def new(start, stop) when is_integer(start) and is_integer(stop) do
    %A.ExRange{start: start, stop: stop}
  end

  def new(start, stop) do
    raise ArgumentError,
          "A.ExRange (start ~> stop) expect both sides to be integers, " <>
            "got: #{inspect(start)} ~> #{inspect(stop)}"
  end

  @doc """
  Checks if two ranges are disjoint.

  ## Examples

      iex> A.ExRange.disjoint?(1 ~> 6, 6 ~> 9)
      true
      iex> A.ExRange.disjoint?(6 ~> 1, 6 ~> 9)
      true
      iex> A.ExRange.disjoint?(1 ~> 6, 5 ~> 9)
      false
      iex> A.ExRange.disjoint?(1 ~> 6, 2 ~> 7)
      false

  """
  @spec disjoint?(t, t) :: boolean
  def disjoint?(start1 ~> stop1 = _range1, start2 ~> stop2 = _range2) do
    {start1, stop1} = normalize(start1, stop1)
    {start2, stop2} = normalize(start2, stop2)
    stop2 < start1 + 1 or stop1 < start2 + 1
  end

  @compile inline: [normalize: 2]
  defp normalize(start, stop) when start > stop, do: {stop, start}
  defp normalize(start, stop), do: {start, stop}

  defimpl Enumerable do
    def reduce(start ~> stop, acc, fun) do
      reduce(start, stop, acc, fun, _up? = stop >= start)
    end

    defp reduce(_start, _stop, {:halt, acc}, _fun, _up?) do
      {:halted, acc}
    end

    defp reduce(start, stop, {:suspend, acc}, fun, up?) do
      {:suspended, acc, &reduce(start, stop, &1, fun, up?)}
    end

    defp reduce(start, stop, {:cont, acc}, fun, _up? = true) when start < stop do
      reduce(start + 1, stop, fun.(start, acc), fun, _up? = true)
    end

    defp reduce(start, stop, {:cont, acc}, fun, _up? = false) when start > stop do
      reduce(start - 1, stop, fun.(start, acc), fun, _up? = false)
    end

    defp reduce(_, _, {:cont, acc}, _fun, _up) do
      {:done, acc}
    end

    def member?(start ~> stop, value) when is_integer(value) do
      if start <= stop do
        {:ok, start <= value and value < stop}
      else
        {:ok, stop < value and value <= start}
      end
    end

    def member?(_ ~> _, _value) do
      {:ok, false}
    end

    def count(start ~> stop) do
      if start <= stop do
        {:ok, stop - start}
      else
        {:ok, start - stop}
      end
    end

    def slice(start ~> stop) do
      if start <= stop do
        {:ok, stop - start, &slice_asc(start + &1, &2)}
      else
        {:ok, start - stop, &slice_desc(start - &1, &2)}
      end
    end

    defp slice_asc(current, 1), do: [current]
    defp slice_asc(current, remaining), do: [current | slice_asc(current + 1, remaining - 1)]

    defp slice_desc(current, 1), do: [current]
    defp slice_desc(current, remaining), do: [current | slice_desc(current - 1, remaining - 1)]
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(start ~> stop, opts) do
      concat([
        "#A<",
        to_doc(start, opts),
        " ~> ",
        to_doc(stop, opts),
        ">"
      ])
    end
  end
end
