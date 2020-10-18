defmodule A do
  @moduledoc ~S"""
  Convenience macros to work with Aja's data structures.

  Use `import A` to import everything, or import only the macros you need.
  """

  @compile {:inline, to_match_map: 2, replace_many!: 2}

  @wildcard quote do: _

  @doc ~S"""
  Convenience macro to work with `A.ExRange`s (exclusive ranges).

  Use `import A` to use it, or `import A, only: [{:~>, 2}]`.

  ## Examples

      iex> 1 ~> 5
      1 ~> 5
      iex> start ~> stop = 0 ~> 10
      iex> {start, stop}
      {0, 10}
      iex> for i <- 0 ~> 5, do: "id_#{i}"
      ["id_0", "id_1", "id_2", "id_3", "id_4"]

  """
  defmacro start ~> stop do
    case __CALLER__.context do
      nil ->
        quote do
          A.ExRange.new(unquote(start), unquote(stop))
        end

      _ ->
        quote do
          %A.ExRange{start: unquote(start), stop: unquote(stop)}
        end
    end
  end

  @doc ~S"""
  Convenience macro to create or pattern match on `A.OrdMap`s.

  Use `import A` to use it, or `import A, only: [{:ord, 1}]`.

  ## Creation examples

      iex> ord(%{"一" => 1, "二" => 2, "三" => 3})
      #A<ord(%{"一" => 1, "二" => 2, "三" => 3})>
      iex> ord(%{a: "Ant", b: "Bat", c: "Cat"})
      #A<ord(%{a: "Ant", b: "Bat", c: "Cat"})>

  ## Pattern matching examples

      iex> ord(%{b: bat}) = ord(%{a: "Ant", b: "Bat", c: "Cat"})
      #A<ord(%{a: "Ant", b: "Bat", c: "Cat"})>
      iex> bat
      "Bat"

  ## Replace existing keys examples

      iex> ordered = ord(%{a: "Ant", b: "Bat", c: "Cat"})
      iex> ord(%{ordered | b: "Buffalo"})
      #A<ord(%{a: "Ant", b: "Buffalo", c: "Cat"})>
      iex> ord(%{ordered | z: "Zebra"})
      ** (KeyError) key :z not found in: #A<ord(%{a: "Ant", b: "Bat", c: "Cat"})>

  """
  defmacro ord({:%{}, _context, [{:|, _context2, [ordered, key_values]}]} = call) do
    unless Enum.all?(key_values, fn key_value -> match?({_, _}, key_value) end) do
      raise_argument_error(call)
    end

    quote do
      replace_many!(unquote(ordered), unquote(key_values))
    end
  end

  defmacro ord({:%{}, context, key_value_pairs}) do
    case __CALLER__.context do
      nil ->
        quote do
          A.OrdMap.new(unquote(key_value_pairs))
        end

      :match ->
        match_map = to_match_map(key_value_pairs, context)

        quote do
          %A.OrdMap{map: unquote(match_map)}
        end

      :guard ->
        raise ArgumentError, "`A.ord/1` cannot be used in guards"
    end
  end

  defmacro ord(call) do
    raise_argument_error(call)
  end

  defp raise_argument_error(call) do
    raise ArgumentError, ~s"""
    Incorrect use of `A.ord/1`:
      ord(#{Macro.to_string(call)}).

    To create a new ordered map:
      ord_map = ord(%{b: "Bat", a: "Ant", c: "Cat"})

    To pattern-match:
      ord(%{a: ant}) = ord_map

    To replace an-existing key:
      ord(%{ord_map | b: "Buffalo"})
    """
  end

  defp to_match_map(key_value_pairs, context) do
    wildcard_pairs =
      for {key, value} <- key_value_pairs do
        {key, {@wildcard, value}}
      end

    {:%{}, context, wildcard_pairs}
  end

  @doc false
  def replace_many!(ordered, key_values) do
    Enum.reduce(key_values, ordered, fn
      {key, value}, acc ->
        A.OrdMap.replace!(acc, key, value)
    end)
  end
end
