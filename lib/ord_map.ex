defmodule Aja.OrdMap do
  base_doc = ~S"""
  A map preserving key insertion order, with efficient lookups, updates and enumeration.

  It works like regular maps, except that the insertion order is preserved:

      iex> %{"one" => 1, "two" => 2, "three" => 3}
      %{"one" => 1, "three" => 3, "two" => 2}
      iex> Aja.OrdMap.new([{"one", 1}, {"two", 2}, {"three", 3}])
      ord(%{"one" => 1, "two" => 2, "three" => 3})

  There is an unavoidable overhead compared to natively implemented maps, so
  keep using regular maps when you do not care about the insertion order.

  `Aja.OrdMap`:
  - provides efficient (logarithmic) access: it is not a simple list of tuples
  - implements the `Access` behaviour, `Enum` / `Inspect` / `Collectable` protocols
  - optionally implements the `Jason.Encoder` protocol if `Jason` is installed

  ## Examples

  `Aja.OrdMap` offers the same API as `Map` :

      iex> ord_map = Aja.OrdMap.new([b: "Bat", a: "Ant", c: "Cat"])
      ord(%{b: "Bat", a: "Ant", c: "Cat"})
      iex> Aja.OrdMap.get(ord_map, :c)
      "Cat"
      iex> Aja.OrdMap.fetch(ord_map, :a)
      {:ok, "Ant"}
      iex> Aja.OrdMap.put(ord_map, :d, "Dinosaur")
      ord(%{b: "Bat", a: "Ant", c: "Cat", d: "Dinosaur"})
      iex> Aja.OrdMap.put(ord_map, :b, "Buffalo")
      ord(%{b: "Buffalo", a: "Ant", c: "Cat"})
      iex> Enum.to_list(ord_map)
      [b: "Bat", a: "Ant", c: "Cat"]
      iex> [d: "Dinosaur", b: "Buffalo", e: "Eel"] |> Enum.into(ord_map)
      ord(%{b: "Buffalo", a: "Ant", c: "Cat", d: "Dinosaur", e: "Eel"})

  ## Specific functions

  Due to its ordered nature, `Aja.OrdMap` also offers some extra methods not present in `Map`, like:
  - `first/1` and `last/1` to efficiently retrieve the first / last key-value pair
  - `foldl/3` and `foldr/3` to efficiently fold (reduce) from left-to-right or right-to-left

  Examples:

      iex> ord_map = Aja.OrdMap.new(b: "Bat", a: "Ant", c: "Cat")
      iex> Aja.OrdMap.first(ord_map)
      {:b, "Bat"}
      iex> Aja.OrdMap.last(ord_map)
      {:c, "Cat"}
      iex> Aja.OrdMap.foldr(ord_map, [], fn {_key, value}, acc -> [value <> "man" | acc] end)
      ["Batman", "Antman", "Catman"]

  ## Access behaviour

  `Aja.OrdMap` implements the `Access` behaviour.

      iex> ord_map = Aja.OrdMap.new([a: "Ant", b: "Bat", c: "Cat"])
      iex> ord_map[:a]
      "Ant"
      iex> put_in(ord_map[:b], "Buffalo")
      ord(%{a: "Ant", b: "Buffalo", c: "Cat"})
      iex> put_in(ord_map[:d], "Dinosaur")
      ord(%{a: "Ant", b: "Bat", c: "Cat", d: "Dinosaur"})
      iex> {"Cat", updated} = pop_in(ord_map[:c]); updated
      ord(%{a: "Ant", b: "Bat"})

  ## Convenience [`ord/1`](`Aja.ord/1`) and [`ord_size/1`](`Aja.ord_size/1`) macros

  The `Aja.OrdMap` module can be used without any macro.

  The `Aja.ord/1` macro does however provide some syntactic sugar to make
  it more convenient to work with ordered maps, namely:
  - construct new ordered maps without the clutter of a entry list
  - pattern match on key-values like regular maps
  - update some existing keys

  Examples:

      iex> import Aja
      iex> ord_map = ord(%{"一" => 1, "二" => 2, "三" => 3})
      ord(%{"一" => 1, "二" => 2, "三" => 3})
      iex> ord(%{"三" => three, "一" => one}) = ord_map
      iex> {one, three}
      {1, 3}
      iex> ord(%{ord_map | "二" => "NI!"})
      ord(%{"一" => 1, "二" => "NI!", "三" => 3})

  Notes:
  - pattern-matching on keys is not affected by insertion order.
  - For expressions with constant keys, `Aja.ord/1` is able to generate the AST at compile time like the `Aja.vec/1` macro.

  The `Aja.ord_size/1` macro can be used in guards:

      iex> import Aja
      iex> match?(v when ord_size(v) > 2, ord%{"一" => 1, "二" => 2, "三" => 3})
      true


  ## With `Jason`

      iex> Aja.OrdMap.new([{"un", 1}, {"deux", 2}, {"trois", 3}]) |> Jason.encode!()
      "{\"un\":1,\"deux\":2,\"trois\":3}"

  JSON encoding preserves the insertion order. Comparing with a regular map:

      iex> Map.new([{"un", 1}, {"deux", 2}, {"trois", 3}]) |> Jason.encode!()
      "{\"deux\":2,\"trois\":3,\"un\":1}"

  There is no way as of now to decode JSON using `Aja.OrdMap`.

  ## Key deletion and sparse maps

  Due to the underlying structures being used, efficient key deletion implies keeping around some
  "holes" to avoid rebuilding the whole structure.

  Such an ord map will be called **sparse**, while an ord map that never had a key deleted will be
  referred as **dense**.

  The implications of sparse structures are multiple:
  - unlike dense structures, they cannot be compared as erlang terms
    (using either `==/2`, `===/2` or the pin operator `^`)
  - `Aja.OrdMap.equal?/2` can safely compare both sparse and dense structures, but is slower for sparse
  - enumerating sparse structures is less efficient than dense ones

  Calling `Aja.OrdMap.new/1` on a sparse ord map will rebuild a new dense one from scratch (which can be expensive).

      iex> dense = Aja.OrdMap.new(a: "Ant", b: "Bat")
      ord(%{a: "Ant", b: "Bat"})
      iex> sparse = Aja.OrdMap.new(c: "Cat", a: "Ant", b: "Bat") |> Aja.OrdMap.delete(:c)
      #Aja.OrdMap<%{a: "Ant", b: "Bat"}, sparse?: true>
      iex> dense == sparse
      false
      iex> match?(^dense, sparse)
      false
      iex> Aja.OrdMap.equal?(dense, sparse)  # works with sparse maps, but less efficient
      true
      iex> new_dense = Aja.OrdMap.new(sparse)  # rebuild a dense map from a sparse one
      ord(%{a: "Ant", b: "Bat"})
      iex> new_dense === dense
      true

  In order to avoid having to worry about memory issues when adding and deleting keys successively,
  ord maps cannot be more than half sparse, and are periodically rebuilt as dense upon deletion.

      iex> sparse = Aja.OrdMap.new(c: "Cat", a: "Ant", b: "Bat") |> Aja.OrdMap.delete(:c)
      #Aja.OrdMap<%{a: "Ant", b: "Bat"}, sparse?: true>
      iex> Aja.OrdMap.delete(sparse, :a)
      ord(%{b: "Bat"})

  Note: Deleting the last key does not make a dense ord map sparse. This is not a bug,
  but an expected behavior due to how data is stored.

      iex> Aja.OrdMap.new([one: 1, two: 2, three: 3]) |> Aja.OrdMap.delete(:three)
      ord(%{one: 1, two: 2})

  The `dense?/1` and `sparse?/1` functions can be used to check if a `Aja.OrdMap` is dense or sparse.

  While this design puts some burden on the developer, the idea behind it is:
  - to keep it as convenient and performant as possible unless deletion is necessary
  - to be transparent about sparse structures and their limitation
  - instead of constantly rebuild new dense structures, let users decide the best timing to do it
  - still work fine with sparse structures, but in a degraded mode
  - protect users about potential memory leaks and performance issues

  ## Pattern-matching and opaque type

  An `Aja.OrdMap` is represented internally using the `%Aja.OrdMap{}` struct. This struct
  can be used whenever there's a need to pattern match on something being an `Aja.OrdMap`:
      iex> match?(%Aja.OrdMap{}, Aja.OrdMap.new())
      true

  Note, however, than `Aja.OrdMap` is an [opaque type](https://hexdocs.pm/elixir/typespecs.html#user-defined-types):
  its struct internal fields must not be accessed directly.

  As discussed in the previous section, [`ord/1`](`Aja.ord/1`) and [`ord_size/1`](`Aja.ord_size/1`) makes it
  possible to pattern match on keys as well as check the type and size.

  ## Memory overhead

  `Aja.OrdMap` takes roughly 2~3x more memory than a regular map depending on the type of data:

  """

  module_doc =
    if(System.otp_release() |> String.to_integer() >= 24) do
      base_doc <>
        ~S"""
            iex> map_size = Map.new(1..100, fn i -> {i, i} end) |> :erts_debug.size()
            366
            iex> ord_map_size = Aja.OrdMap.new(1..100, fn i -> {i, i} end) |> :erts_debug.size()
            1019
            iex> Float.round(ord_map_size / map_size, 2)
            2.78
        """
    else
      base_doc
    end

  @moduledoc module_doc

  require Aja.Vector.Raw, as: RawVector

  @behaviour Access

  @type key :: term
  @type value :: term
  @typep index :: non_neg_integer
  @typep internals(key, value) :: %__MODULE__{
           __ord_map__: %{optional(key) => [index | value]},
           __ord_vector__: RawVector.t({key, value})
         }
  @type t(key, value) :: internals(key, value)
  @type t :: t(key, value)
  defstruct __ord_map__: %{}, __ord_vector__: RawVector.empty()

  @doc false
  defguard is_dense(ord_map)
           # TODO simplify when stop supporting Elixir 1.10
           when :erlang.map_get(:__ord_map__, ord_map) |> map_size() ===
                  :erlang.map_get(:__ord_vector__, ord_map) |> RawVector.size()

  @doc """
  Returns the number of keys in `ord_map`.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> Aja.OrdMap.size(ord_map)
      3
      iex> Aja.OrdMap.size(Aja.OrdMap.new())
      0

  """
  @spec size(t) :: non_neg_integer
  def size(ord_map)

  def size(%__MODULE__{__ord_map__: map}) do
    map_size(map)
  end

  @doc """
  Returns all keys from `ord_map`.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(b: "Bat", c: "Cat", a: "Ant")
      iex> Aja.OrdMap.keys(ord_map)
      [:b, :c, :a]

  """
  @spec keys(t(k, value)) :: [k] when k: key
  def keys(ord_map)

  def keys(%__MODULE__{__ord_vector__: vector}) do
    RawVector.foldr(vector, [], fn
      {key, _value}, acc -> [key | acc]
      nil, acc -> acc
    end)
  end

  @doc """
  Returns all values from `ord_map`.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(b: "Bat", c: "Cat", a: "Ant")
      iex> Aja.OrdMap.values(ord_map)
      ["Bat", "Cat", "Ant"]

  """
  @spec values(t(key, v)) :: [v] when v: value
  def values(ord_map)

  def values(%__MODULE__{__ord_vector__: vector}) do
    RawVector.foldr(vector, [], fn
      {_key, value}, acc -> [value | acc]
      nil, acc -> acc
    end)
  end

  @doc """
  Returns all key-values pairs from `ord_map` as a list.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(b: "Bat", c: "Cat", a: "Ant")
      iex> Aja.OrdMap.to_list(ord_map)
      [b: "Bat", c: "Cat", a: "Ant"]

  """
  @spec to_list(t(k, v)) :: [{k, v}] when k: key, v: value
  def to_list(ord_map)

  def to_list(%__MODULE__{__ord_vector__: vector} = ord_map) when is_dense(ord_map) do
    RawVector.to_list(vector)
  end

  def to_list(%__MODULE__{__ord_vector__: vector}) do
    RawVector.sparse_to_list(vector)
  end

  @doc """
  Returns a new empty ordered map.

  ## Examples

      iex> Aja.OrdMap.new()
      ord(%{})

  """
  @spec new :: t
  def new() do
    %__MODULE__{}
  end

  @doc """
  Creates an ordered map from an `enumerable`.

  Preserves the original order of keys.
  Duplicated keys are removed; the latest one prevails.

  ## Examples

      iex> Aja.OrdMap.new(b: "Bat", a: "Ant", c: "Cat")
      ord(%{b: "Bat", a: "Ant", c: "Cat"})
      iex> Aja.OrdMap.new(b: "Bat", a: "Ant", b: "Buffalo", a: "Antelope")
      ord(%{b: "Buffalo", a: "Antelope"})

  `new/1` will return dense ord maps untouched, but will rebuild sparse ord maps from scratch.
  This can be used to build a dense ord map from from a sparse one.
  See the [section about sparse structures](#module-key-deletion-and-sparse-maps) for more information.

      iex> sparse = Aja.OrdMap.new(c: "Cat", a: "Ant", b: "Bat") |> Aja.OrdMap.delete(:c)
      #Aja.OrdMap<%{a: "Ant", b: "Bat"}, sparse?: true>
      iex> Aja.OrdMap.new(sparse)
      ord(%{a: "Ant", b: "Bat"})

  """
  @spec new(Enumerable.t()) :: t(key, value)
  def new(%__MODULE__{} = ord_map) when is_dense(ord_map), do: ord_map

  def new(enumerable) do
    # TODO add from_vector to avoid intermediate list?
    enumerable
    |> Aja.EnumHelper.to_list()
    |> from_list()
  end

  @doc """
  Creates an ordered map from an `enumerable` via the given `transform` function.

  Preserves the original order of keys.
  Duplicated keys are removed; the latest one prevails.

  ## Examples

      iex> Aja.OrdMap.new([:a, :b], fn x -> {x, x} end)
      ord(%{a: :a, b: :b})

  """
  @spec new(Enumerable.t(), (term -> {k, v})) :: t(k, v) when k: key, v: value
  def new(enumerable, fun) when is_function(fun, 1) do
    enumerable
    |> Aja.EnumHelper.map(fun)
    |> from_list()
  end

  @doc """
  Returns whether the given `key` exists in `ord_map`.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> Aja.OrdMap.has_key?(ord_map, :a)
      true
      iex> Aja.OrdMap.has_key?(ord_map, :d)
      false

  """
  @spec has_key?(t(k, value), k) :: boolean when k: key
  def has_key?(ord_map, key)

  def has_key?(%__MODULE__{__ord_map__: map}, key) do
    Map.has_key?(map, key)
  end

  @doc ~S"""
  Fetches the value for a specific `key` and returns it in a ok-entry.
  If the key does not exist, returns :error.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(a: "A", b: "B", c: "C")
      iex> Aja.OrdMap.fetch(ord_map, :c)
      {:ok, "C"}
      iex> Aja.OrdMap.fetch(ord_map, :z)
      :error

  """
  @impl Access
  @spec fetch(t(k, v), k) :: {:ok, v} | :error when k: key, v: value
  def fetch(ord_map, key)

  def fetch(%__MODULE__{__ord_map__: map}, key) do
    case map do
      %{^key => [_index | value]} ->
        {:ok, value}

      _ ->
        :error
    end
  end

  @doc ~S"""
  Fetches the value for a specific `key` in the given `ord_map`,
  erroring out if `ord_map` doesn't contain `key`.

  If `ord_map` doesn't contain `key`, a `KeyError` exception is raised.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(a: "A", b: "B", c: "C")
      iex> Aja.OrdMap.fetch!(ord_map, :c)
      "C"
      iex> Aja.OrdMap.fetch!(ord_map, :z)
      ** (KeyError) key :z not found in: ord(%{a: "A", b: "B", c: "C"})

  """
  @spec fetch!(t(k, v), k) :: v when k: key, v: value
  def fetch!(%__MODULE__{__ord_map__: map} = ord_map, key) do
    case map do
      %{^key => [_index | value]} ->
        value

      _ ->
        raise KeyError, key: key, term: ord_map
    end
  end

  @doc """
  Puts the given `value` under `key` unless the entry `key`
  already exists in `ord_map`.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(b: "Bat", c: "Cat")
      iex> Aja.OrdMap.put_new(ord_map, :a, "Ant")
      ord(%{b: "Bat", c: "Cat", a: "Ant"})
      iex> Aja.OrdMap.put_new(ord_map, :b, "Buffalo")
      ord(%{b: "Bat", c: "Cat"})

  """
  @spec put_new(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def put_new(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector} = ord_map,
        key,
        value
      ) do
    case map do
      %{^key => _value} ->
        ord_map

      _ ->
        do_add_new(map, vector, key, value)
    end
  end

  @doc """
  Puts a value under `key` only if the `key` already exists in `ord_map`.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> Aja.OrdMap.replace(ord_map, :b, "Buffalo")
      ord(%{a: "Ant", b: "Buffalo", c: "Cat"})
      iex> Aja.OrdMap.replace(ord_map, :d, "Dinosaur")
      ord(%{a: "Ant", b: "Bat", c: "Cat"})

  """
  @spec replace(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def replace(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector} = ord_map,
        key,
        value
      ) do
    case map do
      %{^key => [index | _value]} ->
        do_add_existing(map, vector, index, key, value)

      _ ->
        ord_map
    end
  end

  @doc """
  Puts a value under `key` only if the `key` already exists in `ord_map`.

  If `key` is not present in `ord_map`, a `KeyError` exception is raised.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> Aja.OrdMap.replace!(ord_map, :b, "Buffalo")
      ord(%{a: "Ant", b: "Buffalo", c: "Cat"})
      iex> Aja.OrdMap.replace!(ord_map, :d, "Dinosaur")
      ** (KeyError) key :d not found in: ord(%{a: \"Ant\", b: \"Bat\", c: \"Cat\"})

  """
  @spec replace!(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def replace!(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector} = ord_map,
        key,
        value
      ) do
    case map do
      %{^key => [index | _value]} ->
        do_add_existing(map, vector, index, key, value)

      _ ->
        raise KeyError, key: key, term: ord_map
    end
  end

  @doc """
  Evaluates `fun` and puts the result under `key`
  in `ord_map` unless `key` is already present.

  This function is useful in case you want to compute the value to put under
  `key` only if `key` is not already present, as for example, when the value is expensive to
  calculate or generally difficult to setup and teardown again.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(b: "Bat", c: "Cat")
      iex> expensive_fun = fn -> "Ant" end
      iex> Aja.OrdMap.put_new_lazy(ord_map, :a, expensive_fun)
      ord(%{b: "Bat", c: "Cat", a: "Ant"})
      iex> Aja.OrdMap.put_new_lazy(ord_map, :b, expensive_fun)
      ord(%{b: "Bat", c: "Cat"})

  """
  @spec put_new_lazy(t(k, v), k, (() -> v)) :: t(k, v) when k: key, v: value
  def put_new_lazy(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector} = ord_map,
        key,
        fun
      )
      when is_function(fun, 0) do
    if has_key?(ord_map, key) do
      ord_map
    else
      do_add_new(map, vector, key, fun.())
    end
  end

  @doc """
  Returns a new ordered map with all the key-value pairs in `ord_map` where the key
  is in `keys`.

  If `keys` contains keys that are not in `ord_map`, they're simply ignored.
  Respects the order of the `keys` list.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> Aja.OrdMap.take(ord_map, [:c, :e, :a])
      ord(%{c: "Cat", a: "Ant"})

  """
  @spec get(t(k, v), [k]) :: t(k, v) when k: key, v: value
  def take(ord_map, keys)

  def take(%__MODULE__{__ord_map__: map}, keys) when is_list(keys) do
    do_take(map, keys, [], %{}, 0)
  end

  defp do_take(_map, _keys = [], kvs, map_acc, _index) do
    vector = kvs |> :lists.reverse() |> RawVector.from_list()
    %__MODULE__{__ord_map__: map_acc, __ord_vector__: vector}
  end

  defp do_take(map, [key | keys], kvs, map_acc, index) do
    case map do
      %{^key => [_index | value]} ->
        case map_acc do
          %{^key => _} ->
            do_take(map, keys, kvs, map_acc, index)

          _ ->
            new_kvs = [{key, value} | kvs]
            new_map_acc = Map.put(map_acc, key, [index | value])
            do_take(map, keys, new_kvs, new_map_acc, index + 1)
        end

      _ ->
        do_take(map, keys, kvs, map_acc, index)
    end
  end

  @doc """
  Gets the value for a specific `key` in `ord_map`.

  If `key` is present in `ord_map` then its value `value` is
  returned. Otherwise, `default` is returned.

  If `default` is not provided, `nil` is used.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> Aja.OrdMap.get(ord_map, :a)
      "Ant"
      iex> Aja.OrdMap.get(ord_map, :z)
      nil
      iex> Aja.OrdMap.get(ord_map, :z, "Zebra")
      "Zebra"

  """
  @spec get(t(k, v), k, v) :: v | nil when k: key, v: value
  def get(ord_map, key, default \\ nil)

  def get(%__MODULE__{__ord_map__: map}, key, default) do
    case map do
      %{^key => [_index | value]} ->
        value

      _ ->
        default
    end
  end

  @doc """
  Gets the value for a specific `key` in `ord_map`.

  If `key` is present in `ord_map` then its value `value` is
  returned. Otherwise, `fun` is evaluated and its result is returned.

  This is useful if the default value is very expensive to calculate or
  generally difficult to setup and teardown again.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> expensive_fun = fn -> "Zebra" end
      iex> Aja.OrdMap.get_lazy(ord_map, :a, expensive_fun)
      "Ant"
      iex> Aja.OrdMap.get_lazy(ord_map, :z, expensive_fun)
      "Zebra"

  """
  @spec get_lazy(t(k, v), k, v) :: v | nil when k: key, v: value
  def get_lazy(ord_map, key, fun)

  def get_lazy(%__MODULE__{__ord_map__: map}, key, fun) when is_function(fun, 0) do
    case map do
      %{^key => [_index | value]} ->
        value

      _ ->
        fun.()
    end
  end

  @doc """
  Puts the given `value` under `key` in `ord_map`.

  If the `key` does exist, it overwrites the existing value without
  changing its current location.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> Aja.OrdMap.put(ord_map, :b, "Buffalo")
      ord(%{a: "Ant", b: "Buffalo", c: "Cat"})
      iex> Aja.OrdMap.put(ord_map, :d, "Dinosaur")
      ord(%{a: "Ant", b: "Bat", c: "Cat", d: "Dinosaur"})

  """
  @spec put(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def put(ord_map, key, value)

  def put(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector},
        key,
        value
      ) do
    case map do
      %{^key => [index | _value]} ->
        do_add_existing(map, vector, index, key, value)

      _ ->
        do_add_new(map, vector, key, value)
    end
  end

  @doc """
  Deletes the entry in `ord_map` for a specific `key`.

  If the `key` does not exist, returns `ord_map` unchanged.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> Aja.OrdMap.delete(ord_map, :b)
      #Aja.OrdMap<%{a: "Ant", c: "Cat"}, sparse?: true>
      iex> Aja.OrdMap.delete(ord_map, :z)
      ord(%{a: "Ant", b: "Bat", c: "Cat"})

  """
  @spec delete(t(k, v), k) :: t(k, v) when k: key, v: value
  def delete(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector} = ord_map,
        key
      ) do
    case :maps.take(key, map) do
      {[index | _value], new_map} ->
        do_delete_existing(new_map, vector, index)

      :error ->
        ord_map
    end
  end

  @doc """
  Merges a map or an ordered map into an `ord_map`.

  All keys in `map_or_ord_map` will be added to `ord_map`, overriding any existing one
  (i.e., the keys in `map_or_ord_map` "have precedence" over the ones in `ord_map`).

  ## Examples

      iex> Aja.OrdMap.merge(Aja.OrdMap.new(%{a: 1, b: 2}), Aja.OrdMap.new(%{a: 3, d: 4}))
      ord(%{a: 3, b: 2, d: 4})
      iex> Aja.OrdMap.merge(Aja.OrdMap.new(%{a: 1, b: 2}), %{a: 3, d: 4})
      ord(%{a: 3, b: 2, d: 4})

  """
  @spec merge(t(k, v), t(k, v) | %{optional(k) => v}) :: t(k, v) when k: key, v: value
  def merge(ord_map, map_or_ord_map)

  def merge(%__MODULE__{} = ord_map1, %__MODULE__{} = ord_map2) do
    merge_list(ord_map1, to_list(ord_map2))
  end

  def merge(%__MODULE__{}, %_{}) do
    raise ArgumentError, "Cannot merge arbitrary structs"
  end

  def merge(%__MODULE__{} = ord_map1, %{} = map2) do
    merge_list(ord_map1, Map.to_list(map2))
  end

  @doc """
  Puts a value under `key` only if the `key` already exists in `ord_map`.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> Aja.OrdMap.update(ord_map, :b, "N/A", &String.upcase/1)
      ord(%{a: "Ant", b: "BAT", c: "Cat"})
      iex> Aja.OrdMap.update(ord_map, :z, "N/A", &String.upcase/1)
      ord(%{a: "Ant", b: "Bat", c: "Cat", z: "N/A"})

  """
  @spec update(t(k, v), k, v, (k -> v)) :: t(k, v) when k: key, v: value
  def update(ord_map, key, default, fun)

  def update(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector},
        key,
        default,
        fun
      )
      when is_function(fun, 1) do
    case map do
      %{^key => [index | value]} ->
        do_add_existing(map, vector, index, key, fun.(value))

      _ ->
        do_add_new(map, vector, key, default)
    end
  end

  @doc ~S"""
  Returns the value for `key` and the updated ordered map without `key`.

  If `key` is present in the ordered map with a value `value`,
  `{value, new_ord_map}` is returned.
  If `key` is not present in the ordered map, `{default, ord_map}` is returned.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> {"Bat", updated} = Aja.OrdMap.pop(ord_map, :b)
      iex> updated
      #Aja.OrdMap<%{a: "Ant", c: "Cat"}, sparse?: true>
      iex> {nil, updated} = Aja.OrdMap.pop(ord_map, :z)
      iex> updated
      ord(%{a: "Ant", b: "Bat", c: "Cat"})
      iex> {"Z", updated} = Aja.OrdMap.pop(ord_map, :z, "Z")
      iex> updated
      ord(%{a: "Ant", b: "Bat", c: "Cat"})
  """
  @impl Access
  @spec pop(t(k, v), k, v) :: {v, t(k, v)} when k: key, v: value
  def pop(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector} = ord_map,
        key,
        default \\ nil
      ) do
    case :maps.take(key, map) do
      {[index | value], new_map} ->
        {value, do_delete_existing(new_map, vector, index)}

      :error ->
        {default, ord_map}
    end
  end

  @doc ~S"""
  Returns the value for `key` and the updated ordered map without `key`.

  Behaves the same as `pop/3` but raises if `key` is not present in `ord_map`.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> {"Bat", updated} = Aja.OrdMap.pop!(ord_map, :b)
      iex> updated
      #Aja.OrdMap<%{a: "Ant", c: "Cat"}, sparse?: true>
      iex> Aja.OrdMap.pop!(ord_map, :z)
      ** (KeyError) key :z not found in: ord(%{a: "Ant", b: "Bat", c: "Cat"})
  """
  @spec pop!(t(k, v), k) :: {v, t(k, v)} when k: key, v: value
  def pop!(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector} = ord_map,
        key
      ) do
    case :maps.take(key, map) do
      {[index | value], new_map} ->
        {value, do_delete_existing(new_map, vector, index)}

      :error ->
        raise KeyError, key: key, term: ord_map
    end
  end

  @doc """
  Lazily returns and removes the value associated with `key` in `ord_map`.

  If `key` is present in `ord_map`, it returns `{value, new_map}` where `value` is the value of
  the key and `new_map` is the result of removing `key` from `ord_map`. If `key`
  is not present in `ord_map`, `{fun_result, ord_map}` is returned, where `fun_result`
  is the result of applying `fun`.

  This is useful if the default value is very expensive to calculate or
  generally difficult to setup and teardown again.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(b: "Bat", a: "Ant", c: "Cat")
      iex> expensive_fun = fn -> "Zebra" end
      iex> {"Ant", updated} = Aja.OrdMap.pop_lazy(ord_map, :a, expensive_fun)
      iex> updated
      #Aja.OrdMap<%{b: "Bat", c: "Cat"}, sparse?: true>
      iex> {"Zebra", not_updated} = Aja.OrdMap.pop_lazy(ord_map, :z, expensive_fun)
      iex> not_updated
      ord(%{b: "Bat", a: "Ant", c: "Cat"})

  """
  @spec pop_lazy(t(k, v), k, (() -> v)) :: {v, t(k, v)} when k: key, v: value
  def pop_lazy(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector} = ord_map,
        key,
        fun
      )
      when is_function(fun, 0) do
    case :maps.take(key, map) do
      {[index | value], new_map} ->
        {value, do_delete_existing(new_map, vector, index)}

      :error ->
        {fun.(), ord_map}
    end
  end

  @doc """
  Drops the given `keys` from `ord_map`.

  If `keys` contains keys that are not in `ord_map`, they're simply ignored.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> Aja.OrdMap.drop(ord_map, [:b, :d])
      #Aja.OrdMap<%{a: "Ant", c: "Cat"}, sparse?: true>

  """
  @spec drop(t(k, v), [k]) :: t(k, v) when k: key, v: value
  def drop(%__MODULE__{__ord_map__: map, __ord_vector__: vector} = ord_map, keys)
      when is_list(keys) do
    case Map.take(map, keys) do
      empty when empty == %{} ->
        ord_map

      dropped ->
        dropped_keys = Map.keys(dropped)

        dropped
        |> Map.values()
        |> Enum.map(fn [index | _value] -> index end)
        |> Enum.sort(:desc)
        |> do_drop(map, vector, dropped_keys)
    end
  end

  @doc """
  Puts a value under `key` only if the `key` already exists in `ord_map`.

  If `key` is not present in `ord_map`, a `KeyError` exception is raised.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> Aja.OrdMap.update!(ord_map, :b,  &String.upcase/1)
      ord(%{a: "Ant", b: "BAT", c: "Cat"})
      iex> Aja.OrdMap.update!(ord_map, :d, &String.upcase/1)
      ** (KeyError) key :d not found in: ord(%{a: \"Ant\", b: \"Bat\", c: \"Cat\"})

  """
  @spec update!(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def update!(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector} = ord_map,
        key,
        fun
      )
      when is_function(fun, 1) do
    case map do
      %{^key => [index | value]} ->
        do_add_existing(map, vector, index, key, fun.(value))

      _ ->
        raise KeyError, key: key, term: ord_map
    end
  end

  @doc ~S"""
  Gets the value from `key` and updates it, all in one pass.

  Mirrors `Map.get_and_update/3`, see its documentation.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> {"bat", updated} = Aja.OrdMap.get_and_update(ord_map, :b, fn current_value ->
      ...>   {current_value && String.downcase(current_value), "Buffalo"}
      ...> end)
      iex> updated
      ord(%{a: "Ant", b: "Buffalo", c: "Cat"})
      iex> {nil, updated} = Aja.OrdMap.get_and_update(ord_map, :z, fn current_value ->
      ...>   {current_value && String.downcase(current_value), "Zebra"}
      ...> end)
      iex> updated
      ord(%{a: "Ant", b: "Bat", c: "Cat", z: "Zebra"})
      iex> {"Bat", updated} = Aja.OrdMap.get_and_update(ord_map, :b, fn _ -> :pop end)
      iex> updated
      #Aja.OrdMap<%{a: "Ant", c: "Cat"}, sparse?: true>
      iex> {nil, updated} = Aja.OrdMap.get_and_update(ord_map, :z, fn _ -> :pop end)
      iex> updated
      ord(%{a: "Ant", b: "Bat", c: "Cat"})
  """
  @impl Access
  @spec get_and_update(t(k, v), k, (v -> {returned, v} | :pop)) :: {returned, t(k, v)}
        when k: key, v: value, returned: term
  def get_and_update(%__MODULE__{} = ord_map, key, fun) when is_function(fun, 1) do
    current = get(ord_map, key)

    do_get_and_update(ord_map, key, fun, current)
  end

  @doc ~S"""
  Gets the value from `key` and updates it, all in one pass.

  Mirrors `Map.get_and_update!/3`, see its documentation.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> {"bat", updated} = Aja.OrdMap.get_and_update!(ord_map, :b, fn current_value ->
      ...>   {current_value && String.downcase(current_value), "Buffalo"}
      ...> end)
      iex> updated
      ord(%{a: "Ant", b: "Buffalo", c: "Cat"})
      iex> Aja.OrdMap.get_and_update!(ord_map, :z, fn current_value ->
      ...>   {current_value && String.downcase(current_value), "Zebra"}
      ...> end)
      ** (KeyError) key :z not found in: ord(%{a: "Ant", b: "Bat", c: "Cat"})
  """
  @spec get_and_update!(t(k, v), k, (v -> {returned, v} | :pop)) :: {returned, t(k, v)}
        when k: key, v: value, returned: term
  def get_and_update!(%__MODULE__{} = ord_map, key, fun) when is_function(fun, 1) do
    current = fetch!(ord_map, key)

    do_get_and_update(ord_map, key, fun, current)
  end

  defp do_get_and_update(ord_map, key, fun, current) do
    case fun.(current) do
      {get, update} ->
        {get, put(ord_map, key, update)}

      :pop ->
        {current, delete(ord_map, key)}

      other ->
        raise "the given function must return a two-element tuple or :pop, got: #{inspect(other)}"
    end
  end

  # TODO remove when dropping support for Elixir < 1.14
  struct_fields_available? = Version.compare(System.version(), "1.14.0") != :lt

  @doc """
  Converts a `struct` to an ordered map.

  It accepts the struct module or a struct itself and
  simply removes the `__struct__` field from the given struct
  or from a new struct generated from the given module.

  Respects the field order in Elixir >= 1.14.

  ## Example

      defmodule User do
        defstruct [:name, :age]
      end

      Aja.OrdMap.from_struct(User)
      ord(%{name: nil, age: nil})

      Aja.OrdMap.from_struct(%User{name: "john", age: 44})
      ord(%{name: "john", age: 44})

  """
  @spec from_struct(module | struct) :: t
  if struct_fields_available? do
    def from_struct(struct) when is_atom(struct) do
      struct.__struct__() |> from_struct()
    end

    def from_struct(%module{} = struct) do
      :struct
      |> module.__info__()
      |> new(fn %{field: field} -> {field, Map.fetch!(struct, field)} end)
    end
  else
    def from_struct(struct) do
      struct |> Map.from_struct() |> new()
    end
  end

  @doc """
  Checks if two ordered maps are equal, meaning they have the same key-value pairs
  in the same order.

  ## Examples

      iex> Aja.OrdMap.equal?(Aja.OrdMap.new(a: 1, b: 2), Aja.OrdMap.new(a: 1, b: 2))
      true
      iex> Aja.OrdMap.equal?(Aja.OrdMap.new(a: 1, b: 2), Aja.OrdMap.new(b: 2, a: 1))
      false
      iex> Aja.OrdMap.equal?(Aja.OrdMap.new(a: 1, b: 2), Aja.OrdMap.new(a: 3, b: 2))
      false

  """
  @spec equal?(t, t) :: boolean
  def equal?(ord_map1, ord_map2)

  def equal?(%Aja.OrdMap{__ord_map__: map1} = ord_map1, %Aja.OrdMap{__ord_map__: map2} = ord_map2) do
    case {map_size(map1), map_size(map2)} do
      {size, size} ->
        case {RawVector.size(ord_map1.__ord_vector__), RawVector.size(ord_map2.__ord_vector__)} do
          {^size, ^size} ->
            # both are dense, maps can be compared safely
            map1 === map2

          {_, _} ->
            # one of them is sparse, inefficient comparison
            RawVector.sparse_to_list(ord_map1.__ord_vector__) ===
              RawVector.sparse_to_list(ord_map2.__ord_vector__)
        end

      {_, _} ->
        # size mismatch: cannot be equal
        false
    end
  end

  @doc """
  Returns a new ordered map containing only those pairs from `ord_map` for which `fun` returns a truthy value.

  `fun` receives the key and value of each of the elements in `ord_map` as a key-value pair.
  Preserves the order of `ord_map`.

  Mirrors `Map.filter/2`.
  See also `reject/2` which discards all elements where the function returns a truthy value.

  ## Examples

      iex> ord_map = Aja.OrdMap.new([three: 3, two: 2, one: 1, zero: 0])
      iex> Aja.OrdMap.filter(ord_map, fn {_key, val} -> rem(val, 2) == 1 end)
      ord(%{three: 3, one: 1})

  """
  @spec filter(t(k, v), ({k, v} -> as_boolean(term))) :: t(k, v) when k: key, v: value
  def filter(%__MODULE__{__ord_vector__: vector} = ord_map, fun) when is_function(fun, 1) do
    case ord_map do
      dense when is_dense(dense) -> RawVector.filter_to_list(vector, fun)
      _sparse -> RawVector.sparse_to_list(vector) |> Enum.filter(fun)
    end
    |> from_list()
  end

  @doc """
  Returns a new ordered map excluding the pairs from `ord_map` for which `fun` returns a truthy value.
  Preserves the order of `ord_map`.

  Mirrors `Map.reject/2`.
  See also `filter/2`.

  ## Examples

      iex> ord_map = Aja.OrdMap.new([zero: 0, one: 1, two: 2, three: 3])
      iex> Aja.OrdMap.reject(ord_map, fn {_key, val} -> rem(val, 2) == 1 end)
      ord(%{zero: 0, two: 2})

  """
  @spec reject(t(k, v), ({k, v} -> as_boolean(term))) :: t(k, v) when k: key, v: value
  def reject(%__MODULE__{__ord_vector__: vector} = ord_map, fun) when is_function(fun, 1) do
    case ord_map do
      dense when is_dense(dense) -> RawVector.reject_to_list(vector, fun)
      _sparse -> RawVector.sparse_to_list(vector) |> Enum.reject(fun)
    end
    |> from_list()
  end

  @doc """
  Builds an ordered map from the given `keys` list and the fixed `value`.

  Preserves the order of `keys`.

  ## Examples

      iex> Aja.OrdMap.from_keys([:c, :a, :d, :b], 0)
      ord(%{c: 0, a: 0, d: 0, b: 0})

  """
  @spec from_keys([k], v) :: t(k, v) when k: key, v: value
  def from_keys(keys, value) when is_list(keys) do
    new(keys, &{&1, value})
  end

  # Extra specific functions

  @doc """
  Finds the fist `{key, value}` pair in `ord_map`.

  Returns a `{key, value}` entry if `ord_map` is non-empty, or `nil` else.

  ## Examples

      iex> Aja.OrdMap.new([b: "B", d: "D", a: "A", c: "C"]) |> Aja.OrdMap.first()
      {:b, "B"}
      iex> Aja.OrdMap.new([]) |> Aja.OrdMap.first()
      nil
      iex> Aja.OrdMap.new([]) |> Aja.OrdMap.first(:error)
      :error

  """
  @spec first(t(k, v), default) :: {k, v} | default when k: key, v: value, default: term
  def first(ord_map, default \\ nil)

  def first(%Aja.OrdMap{__ord_vector__: vector} = ord_map, default) when is_dense(ord_map) do
    case vector do
      RawVector.first_pattern(first) -> first
      _ -> default
    end
  end

  def first(%Aja.OrdMap{__ord_vector__: vector}, default) do
    RawVector.find(vector, default, fn value -> value end)
  end

  @doc """
  Finds the last `{key, value}` pair in `ord_map`.

  Returns a `{key, value}` entry if `ord_map` is non-empty, or `nil` else.
  Can be accessed efficiently due to the underlying vector.

  ## Examples

      iex> Aja.OrdMap.new([b: "B", d: "D", a: "A", c: "C"]) |> Aja.OrdMap.last()
      {:c, "C"}
      iex> Aja.OrdMap.new([]) |> Aja.OrdMap.last()
      nil
      iex> Aja.OrdMap.new([]) |> Aja.OrdMap.last(:error)
      :error

  """
  @spec last(t(k, v), default) :: {k, v} | default when k: key, v: value, default: term
  def last(ord_map, default \\ nil)

  def last(%Aja.OrdMap{__ord_vector__: vector} = ord_map, default) when is_dense(ord_map) do
    case vector do
      RawVector.last_pattern(last) -> last
      _ -> default
    end
  end

  def last(%Aja.OrdMap{__ord_vector__: vector}, default) do
    try do
      RawVector.foldr(vector, nil, fn value, _acc ->
        if value, do: throw(value)
      end)

      default
    catch
      value ->
        value
    end
  end

  @doc """
  Folds (reduces) the given `ord_map` from the left with the function `fun`.
  Requires an accumulator `acc`.

  ## Examples

      iex> ord_map = Aja.OrdMap.new([b: "Bat", c: "Cat", a: "Ant"])
      iex> Aja.OrdMap.foldl(ord_map, "", fn {_key, value}, acc -> value <> acc end)
      "AntCatBat"
      iex> Aja.OrdMap.foldl(ord_map, [], fn {key, value}, acc -> [{key, value <> "man"} | acc] end)
      [a: "Antman", c: "Catman", b: "Batman"]

  """
  @spec foldl(t(k, v), acc, ({k, v}, acc -> acc)) :: acc when k: key, v: value, acc: term
  def foldl(ord_map, acc, fun)

  def foldl(%__MODULE__{__ord_vector__: vector} = ord_map, acc, fun) when is_function(fun, 2) do
    case ord_map do
      dense when is_dense(dense) -> RawVector.foldl(vector, acc, fun)
      _sparse -> RawVector.sparse_to_list(vector) |> List.foldl(acc, fun)
    end
  end

  @doc """
  Folds (reduces) the given `ord_map` from the right with the function `fun`.
  Requires an accumulator `acc`.

  Unlike linked lists, this is as efficient as `foldl/3`. This can typically save a call
  to `Enum.reverse/1` on the result when building a list.

  ## Examples

      iex> ord_map = Aja.OrdMap.new([b: "Bat", c: "Cat", a: "Ant"])
      iex> Aja.OrdMap.foldr(ord_map, "", fn {_key, value}, acc -> value <> acc end)
      "BatCatAnt"
      iex> Aja.OrdMap.foldr(ord_map, [], fn {key, value}, acc -> [{key, value <> "man"} | acc] end)
      [b: "Batman", c: "Catman", a: "Antman"]

  """
  @spec foldr(t(k, v), acc, ({k, v}, acc -> acc)) :: acc when k: key, v: value, acc: term
  def foldr(ord_map, acc, fun)

  def foldr(%__MODULE__{__ord_vector__: vector} = ord_map, acc, fun) when is_function(fun, 2) do
    case ord_map do
      dense when is_dense(dense) -> RawVector.foldr(vector, acc, fun)
      _sparse -> RawVector.sparse_to_list(vector) |> List.foldr(acc, fun)
    end
  end

  @doc """
  Returns `true` if `ord_map` is dense; otherwise returns `false`.

  See the [section about sparse structures](#module-key-deletion-and-sparse-maps) for more information.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      ord(%{a: "Ant", b: "Bat", c: "Cat"})
      iex> Aja.OrdMap.dense?(ord_map)
      true
      iex> sparse = Aja.OrdMap.delete(ord_map, :b)
      #Aja.OrdMap<%{a: "Ant", c: "Cat"}, sparse?: true>
      iex> Aja.OrdMap.dense?(sparse)
      false

  """
  def dense?(%__MODULE__{} = ord_map) do
    is_dense(ord_map)
  end

  @doc """
  Returns `true` if `ord_map` is sparse; otherwise returns `false`.

  See the [section about sparse structures](#module-key-deletion-and-sparse-maps) for more information.

  ## Examples

      iex> ord_map = Aja.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      ord(%{a: "Ant", b: "Bat", c: "Cat"})
      iex> Aja.OrdMap.sparse?(ord_map)
      false
      iex> sparse = Aja.OrdMap.delete(ord_map, :b)
      #Aja.OrdMap<%{a: "Ant", c: "Cat"}, sparse?: true>
      iex> Aja.OrdMap.sparse?(sparse)
      true

  """
  def sparse?(%__MODULE__{} = ord_map) do
    !is_dense(ord_map)
  end

  # Exposed "private" functions

  @doc false
  def merge_list(%__MODULE__{__ord_map__: map, __ord_vector__: vector}, new_kvs) do
    {new_map, reversed_kvs, duplicates} =
      do_add_optimistic(new_kvs, map, [], RawVector.size(vector))

    new_vector =
      vector
      |> RawVector.concat_list(:lists.reverse(reversed_kvs))
      |> do_fix_vector_duplicates(new_map, duplicates)

    %__MODULE__{__ord_map__: new_map, __ord_vector__: new_vector}
  end

  @doc false
  def replace_many!(
        %__MODULE__{__ord_map__: map, __ord_vector__: vector} = ord_map,
        key_values
      ) do
    case do_replace_many(key_values, map, vector) do
      {:error, key} ->
        raise KeyError, key: key, term: ord_map

      {:ok, map, vector} ->
        %__MODULE__{__ord_map__: map, __ord_vector__: vector}
    end
  end

  # Private functions

  defp do_add_new(map, vector, key, value) do
    index = RawVector.size(vector)
    new_vector = RawVector.append(vector, {key, value})
    new_map = Map.put(map, key, [index | value])

    %__MODULE__{__ord_map__: new_map, __ord_vector__: new_vector}
  end

  defp do_add_existing(map, vector, index, key, value) do
    new_vector = RawVector.replace_positive!(vector, index, {key, value})
    new_map = Map.put(map, key, [index | value])

    %__MODULE__{__ord_map__: new_map, __ord_vector__: new_vector}
  end

  defp do_delete_existing(new_map, _vector, _index) when new_map === %{} do
    # always return the same empty ord map, and reset the index to avoid considering it as sparse
    %__MODULE__{}
  end

  defp do_delete_existing(new_map, vector, index) do
    new_vector = vector_delete_at(vector, index)
    periodic_rebuild(new_map, new_vector)
  end

  defp periodic_rebuild(map, vector) when RawVector.size(vector) >= 2 * map_size(map) do
    vector
    |> RawVector.sparse_to_list()
    |> from_list()
  end

  defp periodic_rebuild(map, vector) do
    %__MODULE__{__ord_map__: map, __ord_vector__: vector}
  end

  defp do_drop(_indexes = [], map, vector, dropped_keys) do
    periodic_rebuild_drop_keys(map, vector, dropped_keys)
  end

  defp do_drop([index | indexes], map, vector, dropped_keys) do
    new_vector = vector_delete_at(vector, index)
    do_drop(indexes, map, new_vector, dropped_keys)
  end

  defp periodic_rebuild_drop_keys(map, vector, dropped_keys)
       when RawVector.size(vector) >= 2 * (map_size(map) - length(dropped_keys)) do
    vector
    |> RawVector.sparse_to_list()
    |> from_list()
  end

  defp periodic_rebuild_drop_keys(map, vector, dropped_keys) do
    new_map = Map.drop(map, dropped_keys)
    %__MODULE__{__ord_map__: new_map, __ord_vector__: vector}
  end

  defp vector_delete_at(vector, index) when index + 1 == RawVector.size(vector) do
    RawVector.delete_last(vector)
  end

  defp vector_delete_at(vector, index) do
    RawVector.replace_positive!(vector, index, nil)
  end

  defp do_fix_vector_duplicates(vector, _map, _duplicates = nil) do
    vector
  end

  defp do_fix_vector_duplicates(vector, map, duplicates) do
    Enum.reduce(duplicates, vector, fn {key, value}, acc ->
      %{^key => [index | _value]} = map
      RawVector.replace_positive!(acc, index, {key, value})
    end)
  end

  defp do_replace_many([], map, vector) do
    {:ok, map, vector}
  end

  defp do_replace_many([{key, value} | rest], map, vector) do
    case map do
      %{^key => [index | _value]} ->
        new_map = Map.replace!(map, key, [index | value])
        new_vector = RawVector.replace_positive!(vector, index, {key, value})
        do_replace_many(rest, new_map, new_vector)

      _ ->
        {:error, key}
    end
  end

  defp from_list([]) do
    new()
  end

  defp from_list(list) do
    {map, key_values} =
      case do_add_optimistic(list, %{}, [], 0) do
        {map, reversed_kvs, nil} ->
          {map, :lists.reverse(reversed_kvs)}

        {map, reversed_kvs, duplicates} ->
          {map, do_reverse_and_update_duplicates(reversed_kvs, duplicates, [])}
      end

    vector = RawVector.from_list(key_values)
    %__MODULE__{__ord_map__: map, __ord_vector__: vector}
  end

  @doc false
  def from_list_ast([], _env) do
    quote do
      unquote(__MODULE__).new()
    end
  end

  def from_list_ast(kvs_ast, env) do
    cond do
      Macro.quoted_literal?(kvs_ast) -> from_list_ast_constant_keys(kvs_ast, env)
      literal_keys?(kvs_ast) -> from_non_literal_values(kvs_ast, env)
      true -> quote do: unquote(__MODULE__).new(unquote(kvs_ast))
    end
  end

  defp literal_keys?(kvs_ast) do
    Enum.all?(kvs_ast, fn {key_ast, _} ->
      Macro.quoted_literal?(key_ast)
    end)
  end

  defp from_non_literal_values(kvs_ast, env) do
    vars = Macro.generate_arguments(length(kvs_ast), nil)

    {safe_kvs_ast, assigns} =
      kvs_ast
      |> Enum.zip(vars)
      |> Enum.map_reduce([], fn {{key_ast, value_ast}, var}, acc ->
        assign =
          quote do
            unquote(var) = unquote(value_ast)
          end

        {{key_ast, var}, [assign | acc]}
      end)

    instructions = Enum.reverse([from_list_ast_constant_keys(safe_kvs_ast, env) | assigns])
    {:__block__, [], instructions}
  end

  defp from_list_ast_constant_keys(kvs_ast, env) do
    {map, key_values} =
      case do_add_optimistic(kvs_ast, %{}, [], 0) do
        {map, reversed_kvs, nil} ->
          {map, :lists.reverse(reversed_kvs)}

        {map, reversed_kvs, duplicates} ->
          for {key, _} <- duplicates do
            IO.warn(
              "key #{inspect(key)} will be overridden in ord map",
              Macro.Env.stacktrace(env)
            )
          end

          {map, do_reverse_and_update_duplicates(reversed_kvs, duplicates, [])}
      end

    vector_ast = RawVector.from_list_ast(key_values)
    map_ast = {:%{}, [], Enum.map(map, fn {k, [i | v]} -> {k, [{:|, [], [i, v]}]} end)}

    quote do
      %unquote(__MODULE__){__ord_map__: unquote(map_ast), __ord_vector__: unquote(vector_ast)}
    end
  end

  @compile {:inline, do_add_optimistic: 4}

  defp do_add_optimistic([], map, key_values, _next_index) do
    {map, key_values, nil}
  end

  defp do_add_optimistic([{key, value} | rest], map, key_values, next_index) do
    case map do
      %{^key => [index | _value]} ->
        duplicates = %{key => value}
        new_map = Map.put(map, key, [index | value])
        do_add_with_duplicates(rest, new_map, key_values, duplicates, next_index)

      _ ->
        new_map = Map.put(map, key, [next_index | value])
        new_kvs = [{key, value} | key_values]
        do_add_optimistic(rest, new_map, new_kvs, next_index + 1)
    end
  end

  defp do_add_with_duplicates([], map, key_values, duplicates, _next_index) do
    {map, key_values, duplicates}
  end

  defp do_add_with_duplicates([{key, value} | rest], map, key_values, duplicates, next_index) do
    case map do
      %{^key => [index | _value]} ->
        new_duplicates = Map.put(duplicates, key, value)
        new_map = Map.put(map, key, [index | value])
        do_add_with_duplicates(rest, new_map, key_values, new_duplicates, next_index)

      _ ->
        new_map = Map.put(map, key, [next_index | value])
        new_kvs = [{key, value} | key_values]
        do_add_with_duplicates(rest, new_map, new_kvs, duplicates, next_index + 1)
    end
  end

  defp do_reverse_and_update_duplicates([], _duplicates, acc), do: acc

  defp do_reverse_and_update_duplicates([{key, value} | rest], duplicates, acc) do
    value =
      case duplicates do
        %{^key => new_value} -> new_value
        _ -> value
      end

    do_reverse_and_update_duplicates(rest, duplicates, [{key, value} | acc])
  end

  defimpl Enumerable do
    def count(ord_map) do
      {:ok, Aja.OrdMap.size(ord_map)}
    end

    def member?(ord_map, key_value) do
      with {key, value} <- key_value,
           {:ok, ^value} <- Aja.OrdMap.fetch(ord_map, key) do
        {:ok, true}
      else
        _ -> {:ok, false}
      end
    end

    def slice(ord_map) do
      ord_map
      |> Aja.EnumHelper.to_vec_or_list()
      |> Enumerable.slice()
    end

    def reduce(ord_map, acc, fun) do
      ord_map
      |> Aja.OrdMap.to_list()
      |> Enumerable.List.reduce(acc, fun)
    end
  end

  defimpl Collectable do
    def into(map) do
      fun = fn
        map_acc, {:cont, {key, value}} ->
          Aja.OrdMap.put(map_acc, key, value)

        map_acc, :done ->
          map_acc

        _map_acc, :halt ->
          :ok
      end

      {map, fun}
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(ord_map, opts) do
      {open_mark, close_mark} = open_close_marks(ord_map)

      open = color(open_mark, :map, opts)
      close = color(close_mark, :map, opts)
      sep = color(",", :map, opts)

      as_list = Aja.OrdMap.to_list(ord_map)

      container_doc(open, as_list, close, opts, traverse_fun(as_list, opts),
        separator: sep,
        break: :strict
      )
    end

    defp traverse_fun(list, opts) do
      if Inspect.List.keyword?(list) do
        &Inspect.List.keyword/2
      else
        sep = color(" => ", :map, opts)
        &to_map(&1, &2, sep)
      end
    end

    defp to_map({key, value}, opts, sep) do
      concat(concat(to_doc(key, opts), sep), to_doc(value, opts))
    end

    defp open_close_marks(ord_map) do
      if Aja.OrdMap.sparse?(ord_map) do
        {"#Aja.OrdMap<%{", "}, sparse?: true>"}
      else
        {"ord(%{", "})"}
      end
    end
  end

  if Code.ensure_loaded?(Jason.Encoder) do
    defimpl Jason.Encoder do
      def encode(map, opts) do
        map |> Aja.OrdMap.to_list() |> Jason.Encode.keyword(opts)
      end
    end
  end
end
