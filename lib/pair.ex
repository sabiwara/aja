defmodule Aja.Pair do
  @moduledoc ~S"""
  Convenience helpers for working with `{atom, value}` tuples without breaking the pipe.
  """

  @doc """
  Wraps the `value` as an idiomatic `{atom, value}` tuple.
  Convenient for not breaking the pipe.

  ## Examples

      iex> 55 |> Aja.Pair.wrap(:ok)
      {:ok, 55}
      iex> %{a: 5} |> Map.update!(:a, & &1 + 1) |> Aja.Pair.wrap(:no_reply)
      {:no_reply, %{a: 6}}
  """
  def wrap(value, atom) when is_atom(atom) do
    {atom, value}
  end

  @doc """
  Unwraps an idiomatic `{atom, value}` tuple when the atom is what is being expected.
  Convenient for not breaking the pipe.

  ## Examples

      iex> {:ok, 55} |> Aja.Pair.unwrap!(:ok)
      55
      iex> :error |> Aja.Pair.unwrap!(:ok)
      ** (ArgumentError) unwrap!/2 expected {:ok, _}, got: :error
  """
  def unwrap!(pair, atom) when is_atom(atom) do
    case pair do
      {^atom, value} ->
        value

      got ->
        raise ArgumentError, "unwrap!/2 expected {#{inspect(atom)}, _}, got: #{inspect(got)}"
    end
  end
end
