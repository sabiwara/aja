defmodule A.ExRange do
  @moduledoc ~S"""
  Exclusive ranges are an exact copy of regular ranges (see `Range`),
  except that they exclude the second parameter.

  ## Why/when would you need exclusive ranges?

  The most typical use case would be when using `1..n` for loops based
  on a parameter `n >= 0`:

      iex> incorrect = fn n -> for i <- 1..n, do: "id_#{i}" end
      iex> incorrect.(3) # works fine in general...
      ["id_1", "id_2", "id_3"]
      iex> incorrect.(0)  # weird bug at edge case!
      ["id_1", "id_0"]

  To fix it, you would typically need to match the `n == 0` case and handle
  it differently, which is adds noise.
  With exclusive ranges like `0 ~> n`, you get to keep the compact and elegant
  approach from above, while having a correct algorithm that covers the edge case:

      iex> correct = fn n -> for i <- 1 ~> n + 1, do: "id_#{i}" end
      iex> correct.(3) # works fine
      ["id_1", "id_2", "id_3"]
      iex> correct.(0)  # edge case works fine too
      []

  Exclusive ranges can be either increasing (`start <= stop`) or
  decreasing (`start > stop`). The `start` parameter is included
  (except if `start == stop`), the `stop` parameter is *always* excluded.

  An exclusive range is represented internally as a struct
  `A.ExRange{start: start, stop: stop}` and can be used as is.

  The `A.~>/2` convenience macro makes it possible to have a more compact
  syntax, similar to `../2`.
  It is totally optional and needs to be imported:

      iex> import A
      iex> import A, only: [{:~>, 2}]  # more selective

  ## Examples:

      iex> A.ExRange.new(5)
      #A<0 ~> 5>
      iex> range = 0 ~> 5
      #A<0 ~> 5>
      iex> start ~> stop = range
      iex> {start, stop}
      iex> {0, 4}
      iex> Enum.to_list(range)
      [0, 1, 2, 3, 4]
      iex> Enum.count(range)
      5
      iex> Enum.member?(range, 5)
      false
      iex> Enum.member?(range, 4)
      true
      iex> Enum.to_list(3 ~> 0)
      [3, 2, 1]

  Just like `Range`s, such function calls are efficient memory-wise
  no matter the size of the range. The implementation of the `Enumerable`
  protocol uses logic based solely on the endpoints and does
  not materialize the whole list of integers.
  """

  import A, only: [{:~>, 2}]

  @type t :: %__MODULE__{start: integer, stop: integer}
  @enforce_keys [:start, :stop]
  defstruct [:start, :stop]

  @doc """
  Creates a new exclusive range.
  `start` defaults to 0.

  ## Examples

      iex> A.ExRange.new(0, 100)
      #A<0 ~> 100>
      iex> A.ExRange.new(10)
      #A<0 ~> 10>

  """
  @spec new(integer, integer) :: t
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
