defmodule Aja do
  @moduledoc ~S"""
  Convenience macros to work with Aja's data structures.

  Use `import Aja` to import everything, or import only the macros you need.
  """

  @deprecated "Use the :ion library instead (https://hex.pm/packages/ion)"
  defmacro sigil_i(term, modifiers)

  defmacro sigil_i({:<<>>, _, [piece]}, []) when is_binary(piece) do
    Macro.unescape_string(piece)
  end

  defmacro sigil_i({:<<>>, _line, pieces}, []) do
    Enum.map(pieces, &sigil_i_piece/1)
  end

  defp sigil_i_piece({:"::", _, [{{:., _, _}, _, [expr]}, {:binary, _, _}]}) do
    quote do
      Aja.IO.to_iodata(unquote(expr))
    end
  end

  defp sigil_i_piece(piece) when is_binary(piece) do
    case Macro.unescape_string(piece) do
      <<char>> -> char
      binary -> binary
    end
  end

  @doc ~S"""
  Convenience macro to create or pattern match on `Aja.OrdMap`s.

  Use `import Aja` to use it, or `import Aja, only: [ord: 1]`.

  ## Creation examples

      iex> ord(%{"一" => 1, "二" => 2, "三" => 3})
      ord(%{"一" => 1, "二" => 2, "三" => 3})
      iex> ord(%{a: "Ant", b: "Bat", c: "Cat"})
      ord(%{a: "Ant", b: "Bat", c: "Cat"})

  ## Pattern matching examples

      iex> ord(%{b: bat}) = ord(%{a: "Ant", b: "Bat", c: "Cat"}); bat
      "Bat"

  ## Replace existing keys examples

      iex> ordered = ord(%{a: "Ant", b: "Bat", c: "Cat"})
      iex> ord(%{ordered | b: "Buffalo"})
      ord(%{a: "Ant", b: "Buffalo", c: "Cat"})
      iex> ord(%{ordered | z: "Zebra"})
      ** (KeyError) key :z not found in: ord(%{a: "Ant", b: "Bat", c: "Cat"})

  """
  defmacro ord({:%{}, _context, [{:|, _context2, [ordered, key_values]}]} = call) do
    unless Enum.all?(key_values, fn key_value -> match?({_, _}, key_value) end) do
      raise_ord_argument_error(call)
    end

    quote do
      Aja.OrdMap.replace_many!(unquote(ordered), unquote(key_values))
    end
  end

  defmacro ord({:%{}, context, key_value_pairs}) do
    case __CALLER__.context do
      nil ->
        Aja.OrdMap.from_list_ast(key_value_pairs, __CALLER__)

      :match ->
        match_map = to_match_map(key_value_pairs, context)

        quote do
          %Aja.OrdMap{__ord_map__: unquote(match_map)}
        end

      :guard ->
        raise ArgumentError, "`Aja.ord/1` cannot be used in guards"
    end
  end

  defmacro ord(call) do
    raise_ord_argument_error(call)
  end

  defp raise_ord_argument_error(call) do
    raise ArgumentError, ~s"""
    Incorrect use of `Aja.ord/1`:
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
        {key,
         quote do
           [_ | unquote(value)]
         end}
      end

    {:%{}, context, wildcard_pairs}
  end

  @doc """
  Returns the size of an `ord_map`.

  It is implemented as a macro so that it can be used in guards.

  When used outside of a guard, it will just be replaced by a call to `Aja.OrdMap.size/1`.

  When used in guards, it will fail if called on something else than an `Aja.OrdMap`.
  It is recommended to verify the type first.

  Runs in constant time.

  ## Examples

      iex> import Aja
      iex> ord_map = Aja.OrdMap.new(a: 1, b: 2, c: 3)
      iex> match?(v when ord_size(v) > 5, ord_map)
      false
      iex> match?(v when ord_size(v) < 5, ord_map)
      true
      iex> ord_size(ord_map)
      3

  """
  defmacro ord_size(ord_map) do
    case __CALLER__.context do
      nil ->
        quote do
          Aja.OrdMap.size(unquote(ord_map))
        end

      :match ->
        raise ArgumentError, "`Aja.ord_size/1` cannot be used in match"

      :guard ->
        quote do
          unquote(ord_map).__ord_map__ |> :erlang.map_size()
        end
    end
  end

  @doc """
  Convenience macro to create or pattern match on `Aja.Vector`s.

  ## Examples

      iex> import Aja
      iex> vec([1, 2, 3])
      vec([1, 2, 3])
      iex> vec(first ||| last) = Aja.Vector.new(0..99_999); {first, last}
      {0, 99999}
      iex> vec([1, 2, var, _, _, _]) = Aja.Vector.new(1..6); var
      3
      iex> vec([_, _, _]) = Aja.Vector.new(1..6)
      ** (MatchError) no match of right hand side value: vec([1, 2, 3, 4, 5, 6])

  It also supports ranges with **constant** values:

      iex> vec(0..4) = Aja.Vector.new(0..4)
      vec([0, 1, 2, 3, 4])

  Variable lists or dynamic ranges cannot be passed:

      vec(my_list)  # invalid
      vec(1..n)  # invalid

  ## Explanation

  The `vec/1` macro generates the AST at compile time instead of building the vector
  at runtime. This can speedup the instanciation of vectors of known size.

  """
  defmacro vec(list) when is_list(list) do
    ast_from_list(list, __CALLER__)
  end

  defmacro vec({:.., _, [first, last]} = call) do
    case Enum.map([first, last], &Macro.expand(&1, __CALLER__)) do
      [first, last] when is_integer(first) and is_integer(last) ->
        first..last
        |> Enum.to_list()
        |> ast_from_list(__CALLER__)

      _ ->
        raise ArgumentError, ~s"""
        Incorrect use of `Aja.vec/1`:
          vec(#{Macro.to_string(call)}).

        The `vec(a..b)` syntax can only be used with constants:
          vec(1..100)
        """
    end
  end

  defmacro vec({:"..//", _, [first, last, step]} = call) do
    case Enum.map([first, last, step], &Macro.expand(&1, __CALLER__)) do
      [first, last, step] when is_integer(first) and is_integer(last) and is_integer(step) ->
        Range.new(first, last, step)
        |> Enum.to_list()
        |> ast_from_list(__CALLER__)

      _ ->
        raise ArgumentError, ~s"""
        Incorrect use of `Aja.vec/1`:
          vec(#{Macro.to_string(call)}).

        The `vec(a..b//c)` syntax can only be used with constants:
          vec(1..100//5)
        """
    end
  end

  defmacro vec({:|||, _, [first, last]}) do
    case __CALLER__.context do
      :match ->
        quote do
          %Aja.Vector{__vector__: unquote(Aja.Vector.Raw.from_first_last_ast(first, last))}
        end

      _ ->
        raise ArgumentError, "The `vec(x ||| y)` syntax can only be used in matches"
    end
  end

  defmacro vec({:_, _, _}) do
    quote do
      %Aja.Vector{__vector__: _}
    end
  end

  defmacro vec(call) do
    raise ArgumentError, ~s"""
    Incorrect use of `Aja.vec/1`:
      vec(#{Macro.to_string(call)}).

    To create a new vector from a fixed-sized list:
      vector = vec([:foo, 4, a + b])

    To create a new vector from a constant range:
      vector = vec(1..100)

    ! Variables cannot be used as lists or inside the range declaration !
      vec(my_list)  # invalid
      vec(1..n)  # invalid

    To pattern-match:
      vec([1, 2, x, _]) = vector
      vec([]) = empty_vector
      vec(_) = vector
      vec(first ||| last) = vector
    """
  end

  defp ast_from_list([head | tail], %{context: nil}) do
    if Macro.quoted_literal?(head) do
      do_ast_from_list([head | tail])
    else
      quote do
        first = unquote(head)

        unquote(
          do_ast_from_list([
            quote do
              first
            end
            | tail
          ])
        )
      end
    end
  end

  defp ast_from_list(list, _caller) do
    do_ast_from_list(list)
  end

  defp do_ast_from_list(list) do
    internal_ast = Aja.Vector.Raw.from_list_ast(list)

    quote do
      %Aja.Vector{__vector__: unquote(internal_ast)}
    end
  end

  @doc """
  Returns the size of a `vector`.

  It is implemented as a macro so that it can be used in guards.

  When used outside of a guard, it will just be replaced by a call to `Aja.Vector.size/1`.

  When used in guards, it will fail if called on something else than an `Aja.Vector`.
  It is recommended to verify the type first.

  Runs in constant time.

  ## Examples

      iex> import Aja
      iex> match?(v when vec_size(v) > 20, Aja.Vector.new(1..10))
      false
      iex> match?(v when vec_size(v) < 5, Aja.Vector.new([1, 2, 3]))
      true
      iex> vec_size(Aja.Vector.new([1, 2, 3]))
      3

  """
  defmacro vec_size(vector) do
    case __CALLER__.context do
      nil ->
        quote do
          Aja.Vector.size(unquote(vector))
        end

      :match ->
        raise ArgumentError, "`Aja.vec_size/1` cannot be used in match"

      :guard ->
        quote do
          :erlang.element(
            1,
            unquote(vector).__vector__
          )
        end
    end
  end

  @doc """
  Convenience operator to concatenate an enumerable `right` to a vector `left`.

  `left` has to be an `Aja.Vector`, `right` can be any `Enumerable`.

  It is just an alias for `Aja.Vector.concat/2`.

  Only available on Elixir versions >= 1.11.

  ## Examples

      iex> import Aja
      iex> vec(5..1//-1) +++ vec([:boom, nil])
      vec([5, 4, 3, 2, 1, :boom, nil])
      iex> vec(5..1//-1) +++ 0..3
      vec([5, 4, 3, 2, 1, 0, 1, 2, 3])

  """
  defdelegate left +++ right,
    to: Aja.Vector,
    as: :concat
end
