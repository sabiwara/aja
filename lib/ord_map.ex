defmodule A.OrdMap do
  @moduledoc ~S"""
  A Map preserving key insertion order, with efficient lookups and updates.

  Works just like regular maps, except that the insertion order is preserved:

      iex> %{"one" => 1, "two" => 2, "three" => 3}
      %{"one" => 1, "three" => 3, "two" => 2}
      iex> A.OrdMap.new([{"one", 1}, {"two", 2}, {"three", 3}])
      #A<ord(%{"one" => 1, "two" => 2, "three" => 3})>

  There is an unavoidable overhead compared to natively implemented maps, so
  keep using regular maps when you do not care about the insertion order.

  `A.OrdMap`:
  - provides efficient (logarithmic) access: it is not a simple list of tuples
  - implements the `Access` behaviour, `Enum` / `Inspect` / `Collectable` protocols
  - optionally implements the `Jason.Encoder` protocol if `Jason` is installed

  ## Examples

  `A.OrdMap` offers the same API as `Map` :

      iex> ord_map = A.OrdMap.new([b: "Bat", a: "Ant", c: "Cat"])
      #A<ord(%{b: "Bat", a: "Ant", c: "Cat"})>
      iex> A.OrdMap.get(ord_map, :c)
      "Cat"
      iex> A.OrdMap.fetch(ord_map, :a)
      {:ok, "Ant"}
      iex> A.OrdMap.put(ord_map, :d, "Dinosaur")
      #A<ord(%{b: "Bat", a: "Ant", c: "Cat", d: "Dinosaur"})>
      iex> A.OrdMap.put(ord_map, :b, "Buffalo")
      #A<ord(%{b: "Buffalo", a: "Ant", c: "Cat"})>
      iex> A.OrdMap.delete(ord_map, :b)
      #A<ord(%{a: "Ant", c: "Cat"})>
      iex> Enum.to_list(ord_map)
      [b: "Bat", a: "Ant", c: "Cat"]
      iex> [d: "Dinosaur", b: "Buffalo", e: "Eel"] |> Enum.into(ord_map)
      #A<ord(%{b: "Buffalo", a: "Ant", c: "Cat", d: "Dinosaur", e: "Eel"})>

  ## Tree-specific functions

  Due to its sorted nature, `A.OrdMap` also offers some extra methods not present in `Map`, like:
  - `first/1` and `last/1` to efficiently retrieve the first / last key-value pairs
  - `foldl/3` and `foldr/3` to efficiently fold (reduce) from left-to-right or right-to-left

  Examples:

      iex> ord_map = A.OrdMap.new(b: "Bat", a: "Ant", c: "Cat")
      iex> A.OrdMap.first(ord_map)
      {:b, "Bat"}
      iex> A.OrdMap.foldr(ord_map, [], fn {_key, value}, acc -> [value <> "man" | acc] end)
      ["Batman", "Antman", "Catman"]

  ## Access behaviour

  `A.OrdMap` implements the `Access` behaviour.

      iex> ord_map = A.OrdMap.new([a: "Ant", b: "Bat", c: "Cat"])
      iex> ord_map[:a]
      "Ant"
      iex> put_in(ord_map[:b], "Buffalo")
      #A<ord(%{a: "Ant", b: "Buffalo", c: "Cat"})>
      iex> put_in(ord_map[:d], "Dinosaur")
      #A<ord(%{a: "Ant", b: "Bat", c: "Cat", d: "Dinosaur"})>
      iex> {"Cat", updated} = pop_in(ord_map[:c])
      iex> updated
      #A<ord(%{a: "Ant", b: "Bat"})>

  ## Convenience [`ord/1`](`A.ord/1`) macro

  The `A.OrdMap` module can be used without any macro.
  The `A.ord/1` macro does however provide some syntactic sugar to make
  it more convenient to work with ordered maps, namely:
  - construct new ordered maps
  - pattern match on ordered maps like one would do on regular maps
  - update some existing keys

  Examples:

      iex> import A
      iex> ord_map = ord(%{"一" => 1, "二" => 2, "三" => 3})
      #A<ord(%{"一" => 1, "二" => 2, "三" => 3})>
      iex> ord(%{"三" => three, "一" => one}) = ord_map
      iex> {one, three}
      {1, 3}
      iex> ord(%{ord_map | "二" => "NI!"})
      #A<ord(%{"一" => 1, "二" => "NI!", "三" => 3})>

  Note: pattern-matching on keys doesn't care about the insertion order.

  ## With `Jason`

      iex> A.OrdMap.new([{"un", 1}, {"deux", 2}, {"trois", 3}]) |> Jason.encode!()
      "{\"un\":1,\"deux\":2,\"trois\":3}"

  It also preserves the insertion order. Comparing with a regular map:

      iex> Map.new([{"un", 1}, {"deux", 2}, {"trois", 3}]) |> Jason.encode!()
      "{\"deux\":2,\"trois\":3,\"un\":1}"

  There is no way as of now to decode JSON using `A.OrdMap`.

  ## Pattern-match and opaque type

  An `A.OrdMap` is represented internally using the `%A.OrdMap{}` struct. This struct
  can be used whenever there's a need to pattern match on something being a `A.OrdMap`:
      iex> match?(%A.OrdMap{}, A.OrdMap.new())
      true

  Note, however, than `A.OrdMap` is an [opaque type](https://hexdocs.pm/elixir/typespecs.html#user-defined-types):
  its struct internal fields must not be accessed directly.

  As discussed in the previous section, [`ord/1`](`A.ord/1`) also makes it
  possible to pattern match on keys as well as checking the type.

  Use the functions in this module to perform operations on ordered maps, or the `Enum` module.
  """

  @behaviour Access

  # TODO: inline what is relevant
  @compile {:inline,
            new: 1,
            fetch: 2,
            get: 2,
            put: 3,
            delete: 2,
            replace: 3,
            replace!: 3,
            insert_new: 3,
            replace_existing: 4,
            delete_existing: 3,
            equal?: 2,
            equal_loop: 2}

  @type key :: term
  @type value :: term
  @typep index :: non_neg_integer
  @opaque t(key, value) :: %__MODULE__{
            tree: A.RBTree.tree({index, key}),
            map: %{optional(key) => {index, value}}
          }
  @opaque t :: t(key, value)
  @enforce_keys [:tree, :map]
  defstruct [:tree, :map]

  @doc """
  Returns all keys from `ord_map`.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.OrdMap.size(ord_map)
      3
      iex> A.OrdMap.size(A.OrdMap.new())
      0

  """
  @spec size(t) :: non_neg_integer
  def size(ord_map)

  def size(%__MODULE__{map: map}) do
    map_size(map)
  end

  @doc """
  Returns all keys from `ord_map`.

  ## Examples

      iex> ord_map = A.OrdMap.new(b: "Bat", c: "Cat", a: "Ant")
      iex> A.OrdMap.keys(ord_map)
      [:b, :c, :a]

  """
  @spec keys(t(k, value)) :: [k] when k: key
  def keys(ord_map)

  def keys(%__MODULE__{tree: tree}) do
    A.RBTree.foldr(tree, [], fn {_index, key}, acc ->
      [key | acc]
    end)
  end

  @doc """
  Returns all values from `ord_map`.

  ## Examples

      iex> ord_map = A.OrdMap.new(b: "Bat", c: "Cat", a: "Ant")
      iex> A.OrdMap.values(ord_map)
      ["Bat", "Cat", "Ant"]

  """
  @spec values(t(key, v)) :: [v] when v: value
  def values(ord_map)

  def values(%__MODULE__{tree: tree, map: map}) do
    A.RBTree.foldr(tree, [], fn {_index, key}, acc ->
      %{^key => {_index, value}} = map
      [value | acc]
    end)
  end

  @doc """
  Returns all values from `ord_map`.

  ## Examples

      iex> ord_map = A.OrdMap.new(b: "Bat", c: "Cat", a: "Ant")
      iex> A.OrdMap.to_list(ord_map)
      [b: "Bat", c: "Cat", a: "Ant"]

  """
  @spec to_list(t(k, v)) :: [{k, v}] when k: key, v: value
  def to_list(ord_map)

  def to_list(%__MODULE__{tree: tree, map: map}) do
    A.RBTree.foldr(tree, [], fn {_index, key}, acc ->
      %{^key => {_index, value}} = map
      [{key, value} | acc]
    end)
  end

  @doc """
  Returns a new empty ordered map.

  ## Examples

      iex> A.OrdMap.new()
      #A<ord(%{})>

  """
  @spec new :: t
  def new() do
    %__MODULE__{tree: A.RBTree.empty(), map: %{}}
  end

  @doc """
  Creates an ordered map from an `enumerable`.

  Preserves the original order of keys.
  Duplicated keys are removed; the latest one prevails.

  ## Examples

      iex> A.OrdMap.new(b: "Bat", a: "Ant", c: "Cat")
      #A<ord(%{b: "Bat", a: "Ant", c: "Cat"})>
      iex> A.OrdMap.new(b: "Bat", a: "Ant", b: "Buffalo", a: "Antelope")
      #A<ord(%{b: "Buffalo", a: "Antelope"})>

  """
  @spec new(Enumerable.t()) :: t(key, value)
  def new(%__MODULE__{} = ord_map), do: ord_map

  def new(enumerable) do
    list = Enum.to_list(enumerable)
    new_loop(0, A.RBTree.empty(), %{}, list)
  end

  defp new_loop(_i, tree, map, []), do: %__MODULE__{tree: tree, map: map}

  defp new_loop(i, tree, map, [{key, value} | rest]) do
    case map do
      %{^key => {index, _value}} ->
        new_map = Map.replace!(map, key, {index, value})
        new_loop(i + 1, tree, new_map, rest)

      _ ->
        new_map = Map.put_new(map, key, {i, value})
        {_result, new_tree} = A.RBTree.map_insert(tree, i, key)
        new_loop(i + 1, new_tree, new_map, rest)
    end
  end

  @doc """
  Creates an ordered map from an `enumerable` via the given `transform` function.

  Preserves the original order of keys.
  Duplicated keys are removed; the latest one prevails.

  ## Examples

      iex> A.OrdMap.new([:a, :b], fn x -> {x, x} end)
      #A<ord(%{a: :a, b: :b})>

  """
  @spec new(Enumerable.t(), (term -> {k, v})) :: t(k, v) when k: key, v: value
  def new(enumerable, fun) do
    enumerable
    |> Enum.map(fun)
    |> new()
  end

  @doc """
  Returns whether the given `key` exists in `ord_map`.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.OrdMap.has_key?(ord_map, :a)
      true
      iex> A.OrdMap.has_key?(ord_map, :d)
      false

  """
  @spec has_key?(t(k, value), k) :: boolean when k: key
  def has_key?(ord_map, key)

  def has_key?(%__MODULE__{map: map}, key) do
    Map.has_key?(map, key)
  end

  @doc ~S"""
  Fetches the value for a specific `key` and returns it in a ok-tuple.
  If the key does not exist, returns :error.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "A", b: "B", c: "C")
      iex> A.OrdMap.fetch(ord_map, :c)
      {:ok, "C"}
      iex> A.OrdMap.fetch(ord_map, :z)
      :error

  """
  @impl Access
  @spec fetch(t(k, v), k) :: {:ok, v} | :error when k: key, v: value
  def fetch(ord_map, key)

  def fetch(%__MODULE__{map: map}, key) do
    case map do
      %{^key => {_index, value}} ->
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

      iex> ord_map = A.OrdMap.new(a: "A", b: "B", c: "C")
      iex> A.OrdMap.fetch!(ord_map, :c)
      "C"
      iex> A.OrdMap.fetch!(ord_map, :z)
      ** (KeyError) key :z not found in: #A<ord(%{a: "A", b: "B", c: "C"})>

  """
  @spec fetch!(t(k, v), k) :: v when k: key, v: value
  def fetch!(%__MODULE__{map: map} = ord_map, key) do
    case map do
      %{^key => {_index, value}} ->
        value

      _ ->
        raise KeyError, key: key, term: ord_map
    end
  end

  @doc """
  Puts the given `value` under `key` unless the entry `key`
  already exists in `ord_map`.

  ## Examples

      iex> ord_map = A.OrdMap.new(b: "Bat", c: "Cat")
      iex> A.OrdMap.put_new(ord_map, :a, "Ant")
      #A<ord(%{b: "Bat", c: "Cat", a: "Ant"})>
      iex> A.OrdMap.put_new(ord_map, :b, "Buffalo")
      #A<ord(%{b: "Bat", c: "Cat"})>

  """
  @spec put_new(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def put_new(%__MODULE__{map: map} = ord_map, key, value) do
    case map do
      %{^key => _value} ->
        ord_map

      _ ->
        put(ord_map, key, value)
    end
  end

  @doc """
  Puts a value under `key` only if the `key` already exists in `ord_map`.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.OrdMap.replace(ord_map, :b, "Buffalo")
      #A<ord(%{a: "Ant", b: "Buffalo", c: "Cat"})>
      iex> A.OrdMap.replace(ord_map, :d, "Dinosaur")
      #A<ord(%{a: "Ant", b: "Bat", c: "Cat"})>

  """
  @spec replace(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def replace(%__MODULE__{map: map} = ord_map, key, value) do
    case map do
      %{^key => {index, _value}} ->
        replace_existing(ord_map, index, key, value)

      _ ->
        ord_map
    end
  end

  @doc """
  Puts a value under `key` only if the `key` already exists in `ord_map`.

  If `key` is not present in `ord_map`, a `KeyError` exception is raised.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.OrdMap.replace!(ord_map, :b, "Buffalo")
      #A<ord(%{a: "Ant", b: "Buffalo", c: "Cat"})>
      iex> A.OrdMap.replace!(ord_map, :d, "Dinosaur")
      ** (KeyError) key :d not found in: #A<ord(%{a: \"Ant\", b: \"Bat\", c: \"Cat\"})>

  """
  @spec replace!(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def replace!(%__MODULE__{map: map} = ord_map, key, value) do
    case map do
      %{^key => {index, _value}} ->
        replace_existing(ord_map, index, key, value)

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

      iex> ord_map = A.OrdMap.new(b: "Bat", c: "Cat")
      iex> expensive_fun = fn -> "Ant" end
      iex> A.OrdMap.put_new_lazy(ord_map, :a, expensive_fun)
      #A<ord(%{b: "Bat", c: "Cat", a: "Ant"})>
      iex> A.OrdMap.put_new_lazy(ord_map, :b, expensive_fun)
      #A<ord(%{b: "Bat", c: "Cat"})>

  """
  @spec put_new_lazy(t(k, v), k, (() -> v)) :: t(k, v) when k: key, v: value
  def put_new_lazy(%__MODULE__{} = ord_map, key, fun) when is_function(fun, 0) do
    if has_key?(ord_map, key) do
      ord_map
    else
      put(ord_map, key, fun.())
    end
  end

  @doc """
  Returns a new ordered map with all the key-value pairs in `ord_map` where the key
  is in `keys`.

  If `keys` contains keys that are not in `ord_map`, they're simply ignored.
  Respects the order of the `keys` list.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.OrdMap.take(ord_map, [:c, :e, :a])
      #A<ord(%{c: "Cat", a: "Ant"})>

  """
  @spec get(t(k, v), [k]) :: t(k, v) when k: key, v: value
  def take(ord_map, keys)

  def take(%__MODULE__{map: map}, keys) when is_list(keys) do
    keys
    |> Enum.reduce([], fn key, acc ->
      case map do
        %{^key => {_index, value}} ->
          [{key, value} | acc]

        _ ->
          acc
      end
    end)
    |> Enum.reverse()
    |> new()
  end

  @doc """
  Gets the value for a specific `key` in `ord_map`.

  If `key` is present in `ord_map` then its value `value` is
  returned. Otherwise, `default` is returned.

  If `default` is not provided, `nil` is used.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.OrdMap.get(ord_map, :a)
      "Ant"
      iex> A.OrdMap.get(ord_map, :z)
      nil
      iex> A.OrdMap.get(ord_map, :z, "Zebra")
      "Zebra"

  """
  @spec get(t(k, v), k, v) :: v | nil when k: key, v: value
  def get(ord_map, key, default \\ nil)

  def get(%__MODULE__{map: map}, key, default) do
    case map do
      %{^key => {_index, value}} ->
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

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> expensive_fun = fn -> "Zebra" end
      iex> A.OrdMap.get_lazy(ord_map, :a, expensive_fun)
      "Ant"
      iex> A.OrdMap.get_lazy(ord_map, :z, expensive_fun)
      "Zebra"

  """
  @spec get_lazy(t(k, v), k, v) :: v | nil when k: key, v: value
  def get_lazy(ord_map, key, fun)

  def get_lazy(%__MODULE__{map: map}, key, fun) when is_function(fun, 0) do
    case map do
      %{^key => {_index, value}} ->
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

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.OrdMap.put(ord_map, :b, "Buffalo")
      #A<ord(%{a: "Ant", b: "Buffalo", c: "Cat"})>
      iex> A.OrdMap.put(ord_map, :d, "Dinosaur")
      #A<ord(%{a: "Ant", b: "Bat", c: "Cat", d: "Dinosaur"})>

  """
  @spec put(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def put(%__MODULE__{map: map} = ord_map, key, value) do
    case map do
      %{^key => {index, _value}} ->
        replace_existing(ord_map, index, key, value)

      _ ->
        insert_new(ord_map, key, value)
    end
  end

  @doc """
  Deletes the entry in `ord_map` for a specific `key`.

  If the `key` does not exist, returns `ord_map` unchanged.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.OrdMap.delete(ord_map, :b)
      #A<ord(%{a: "Ant", c: "Cat"})>
      iex> A.OrdMap.delete(ord_map, :z)
      #A<ord(%{a: "Ant", b: "Bat", c: "Cat"})>

  """
  @spec delete(t(k, v), k) :: t(k, v) when k: key, v: value
  def delete(%__MODULE__{map: map} = ord_map, key) do
    case :maps.take(key, map) do
      {{index, _value}, new_map} ->
        delete_existing(ord_map, new_map, index)

      :error ->
        ord_map
    end
  end

  @doc """
  Merges two ordered maps into one.

  All keys in `ord_map2` will be added to `ord_map1`, overriding any existing one
  (i.e., the keys in `ord_map2` "have precedence" over the ones in `ord_map1`).

  ## Examples

      iex> A.OrdMap.merge(A.OrdMap.new(%{a: 1, b: 2}), A.OrdMap.new(%{a: 3, d: 4}))
      #A<ord(%{a: 3, b: 2, d: 4})>

  """
  @spec merge(t(k, v), t(k, v)) :: t(k, v) when k: key, v: value
  def merge(%__MODULE__{} = ord_map1, %__MODULE__{} = ord_map2) do
    Enum.reduce(ord_map2, ord_map1, fn {key, value}, acc -> put(acc, key, value) end)
  end

  @doc """
  Puts a value under `key` only if the `key` already exists in `ord_map`.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.OrdMap.update(ord_map, :b, "N/A", &String.upcase/1)
      #A<ord(%{a: "Ant", b: "BAT", c: "Cat"})>
      iex> A.OrdMap.update(ord_map, :z, "N/A", &String.upcase/1)
      #A<ord(%{a: "Ant", b: "Bat", c: "Cat", z: "N/A"})>

  """
  @spec update(t(k, v), k, v, (k -> v)) :: t(k, v) when k: key, v: value
  def update(%__MODULE__{map: map} = ord_map, key, default, fun) when is_function(fun, 1) do
    case map do
      %{^key => {index, value}} ->
        replace_existing(ord_map, index, key, fun.(value))

      _ ->
        insert_new(ord_map, key, default)
    end
  end

  @doc ~S"""
  Returns the value for `key` and the updated ordered map without `key`.

  If `key` is present in the ordered map with a value `value`,
  `{value, new_ord_map}` is returned.
  If `key` is not present in the ordered map, `{default, ord_map}` is returned.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> {"Bat", updated} = A.OrdMap.pop(ord_map, :b)
      iex> updated
      #A<ord(%{a: "Ant", c: "Cat"})>
      iex> {nil, updated} = A.OrdMap.pop(ord_map, :z)
      iex> updated
      #A<ord(%{a: "Ant", b: "Bat", c: "Cat"})>
      iex> {"Z", updated} = A.OrdMap.pop(ord_map, :z, "Z")
      iex> updated
      #A<ord(%{a: "Ant", b: "Bat", c: "Cat"})>
  """
  @impl Access
  @spec pop(t(k, v), k, v) :: {v, t(k, v)} when k: key, v: value
  def pop(%__MODULE__{map: map} = ord_map, key, default \\ nil) do
    case :maps.take(key, map) do
      {{index, value}, new_map} ->
        {value, delete_existing(ord_map, new_map, index)}

      :error ->
        {default, ord_map}
    end
  end

  @doc ~S"""
  Returns the value for `key` and the updated ordered map without `key`.

  Behaves the same as `pop/3` but raises if `key` is not present in `ord_map`.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> {"Bat", updated} = A.OrdMap.pop!(ord_map, :b)
      iex> updated
      #A<ord(%{a: "Ant", c: "Cat"})>
      iex> A.OrdMap.pop!(ord_map, :z)
      ** (KeyError) key :z not found in: #A<ord(%{a: "Ant", b: "Bat", c: "Cat"})>
  """
  @spec pop!(t(k, v), k) :: {v, t(k, v)} when k: key, v: value
  def pop!(%__MODULE__{map: map} = ord_map, key) do
    case :maps.take(key, map) do
      {{index, value}, new_map} ->
        {value, delete_existing(ord_map, new_map, index)}

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

      iex> ord_map = A.OrdMap.new(b: "Bat", a: "Ant", c: "Cat")
      iex> expensive_fun = fn -> "Zebra" end
      iex> {"Ant", updated} = A.OrdMap.pop_lazy(ord_map, :a, expensive_fun)
      iex> updated
      #A<ord(%{b: "Bat", c: "Cat"})>
      iex> {"Zebra", not_updated} = A.OrdMap.pop_lazy(ord_map, :z, expensive_fun)
      iex> not_updated
      #A<ord(%{b: "Bat", a: "Ant", c: "Cat"})>

  """
  @spec pop_lazy(t(k, v), k, (() -> v)) :: {v, t(k, v)} when k: key, v: value
  def pop_lazy(%__MODULE__{map: map} = ord_map, key, fun) when is_function(fun, 0) do
    case :maps.take(key, map) do
      {{index, value}, new_map} ->
        {value, delete_existing(ord_map, new_map, index)}

      :error ->
        {fun.(), ord_map}
    end
  end

  @doc """
  Drops the given `keys` from `ord_map`.

  If `keys` contains keys that are not in `ord_map`, they're simply ignored.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.OrdMap.drop(ord_map, [:b, :d])
      #A<ord(%{a: "Ant", c: "Cat"})>

  """
  @spec drop(t(k, v), [k]) :: t(k, v) when k: key, v: value
  def drop(%__MODULE__{} = ord_map, keys) when is_list(keys) do
    Enum.reduce(keys, ord_map, fn key, acc ->
      delete(acc, key)
    end)
  end

  @doc """
  Puts a value under `key` only if the `key` already exists in `ord_map`.

  If `key` is not present in `ord_map`, a `KeyError` exception is raised.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.OrdMap.update!(ord_map, :b,  &String.upcase/1)
      #A<ord(%{a: "Ant", b: "BAT", c: "Cat"})>
      iex> A.OrdMap.update!(ord_map, :d, &String.upcase/1)
      ** (KeyError) key :d not found in: #A<ord(%{a: \"Ant\", b: \"Bat\", c: \"Cat\"})>

  """
  @spec update!(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def update!(%__MODULE__{map: map} = ord_map, key, fun) when is_function(fun, 1) do
    case map do
      %{^key => {index, value}} ->
        replace_existing(ord_map, index, key, fun.(value))

      _ ->
        raise KeyError, key: key, term: ord_map
    end
  end

  @doc ~S"""
  Gets the value from `key` and updates it, all in one pass.

  Mirrors `Map.get_and_update/3`, see its documentation.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> {"bat", updated} = A.OrdMap.get_and_update(ord_map, :b, fn current_value ->
      ...>   {current_value && String.downcase(current_value), "Buffalo"}
      ...> end)
      iex> updated
      #A<ord(%{a: "Ant", b: "Buffalo", c: "Cat"})>
      iex> {nil, updated} = A.OrdMap.get_and_update(ord_map, :z, fn current_value ->
      ...>   {current_value && String.downcase(current_value), "Zebra"}
      ...> end)
      iex> updated
      #A<ord(%{a: "Ant", b: "Bat", c: "Cat", z: "Zebra"})>
      iex> {"Bat", updated} = A.OrdMap.get_and_update(ord_map, :b, fn _ -> :pop end)
      iex> updated
      #A<ord(%{a: "Ant", c: "Cat"})>
      iex> {nil, updated} = A.OrdMap.get_and_update(ord_map, :z, fn _ -> :pop end)
      iex> updated
      #A<ord(%{a: "Ant", b: "Bat", c: "Cat"})>
  """
  @impl Access
  @spec get_and_update(t(k, v), k, (v -> {returned, v} | :pop)) :: {returned, t(k, v)}
        when k: key, v: value, returned: term
  def get_and_update(%__MODULE__{} = ord_map, key, fun) when is_function(fun, 1) do
    A.Helpers.CustomMaps.get_and_update(ord_map, key, fun)
  end

  @doc ~S"""
  Gets the value from `key` and updates it, all in one pass.

  Mirrors `Map.get_and_update!/3`, see its documentation.

  ## Examples

      iex> ord_map = A.OrdMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> {"bat", updated} = A.OrdMap.get_and_update!(ord_map, :b, fn current_value ->
      ...>   {current_value && String.downcase(current_value), "Buffalo"}
      ...> end)
      iex> updated
      #A<ord(%{a: "Ant", b: "Buffalo", c: "Cat"})>
      iex> A.OrdMap.get_and_update!(ord_map, :z, fn current_value ->
      ...>   {current_value && String.downcase(current_value), "Zebra"}
      ...> end)
      ** (KeyError) key :z not found in: #A<ord(%{a: "Ant", b: "Bat", c: "Cat"})>
  """
  @spec get_and_update!(t(k, v), k, (v -> {returned, v} | :pop)) :: {returned, t(k, v)}
        when k: key, v: value, returned: term
  def get_and_update!(%__MODULE__{} = ord_map, key, fun) when is_function(fun, 1) do
    A.Helpers.CustomMaps.get_and_update!(ord_map, key, fun)
  end

  @doc """
  Converts a `struct` to an ordered map.

  It accepts the struct module or a struct itself and
  simply removes the `__struct__` field from the given struct
  or from a new struct generated from the given module.

  ## Example

      defmodule User do
        defstruct [:name, :age]
      end

      A.OrdMap.from_struct(User)
      #A<ord(%{age: nil, name: nil})>

      A.OrdMap.from_struct(%User{name: "john", age: 44})
      #A<ord(%{age: 44, name: "john"})>

  """
  @spec from_struct(atom | struct) :: t
  def from_struct(struct) do
    struct |> Map.from_struct() |> new()
  end

  @doc """
  Checks if two ordered maps are equal, meaning they have the same key-value pairs
  in the same order.

  ## Examples

      iex> A.OrdMap.equal?(A.OrdMap.new(a: 1, b: 2), A.OrdMap.new(a: 1, b: 2))
      true
      iex> A.OrdMap.equal?(A.OrdMap.new(a: 1, b: 2), A.OrdMap.new(b: 2, a: 1))
      false
      iex> A.OrdMap.equal?(A.OrdMap.new(a: 1, b: 2), A.OrdMap.new(a: 3, b: 2))
      false

  """
  @spec equal?(t, t) :: boolean
  def equal?(%A.OrdMap{} = ord_map1, %A.OrdMap{} = ord_map2) do
    size(ord_map1) == size(ord_map2) && equal_loop(iterator(ord_map1), iterator(ord_map2))
  end

  defp equal_loop(iterator1, iterator2) do
    case {next(iterator1), next(iterator2)} do
      {nil, nil} ->
        true

      {{same_key, same_value, new_iterator1}, {same_key, same_value, new_iterator2}} ->
        equal_loop(new_iterator1, new_iterator2)

      _ ->
        false
    end
  end

  # Extra specific functions

  @doc """
  Finds the fist `{key, value}` pair in `ord_map`.

  Returns a `{key, value}` tuple if `ord_map` is non-empty, or `nil` else.

  ## Examples

      iex> A.OrdMap.new([b: "B", d: "D", a: "A", c: "C"]) |> A.OrdMap.first()
      {:b, "B"}
      iex> A.OrdMap.new([]) |> A.OrdMap.first()
      nil

  """
  @spec first(t(k, v)) :: {k, v} | nil when k: key, v: value
  def first(ord_map)

  def first(%A.OrdMap{map: map, tree: tree}) do
    case A.RBTree.min(tree) do
      {:ok, {_index, key}} ->
        %{^key => {_index, value}} = map
        {key, value}

      :error ->
        nil
    end
  end

  @doc """
  Finds the last `{key, value}` pair in `ord_map`.

  Returns a `{key, value}` tuple if `ord_map` is non-empty, or `nil` else.
  Can be accessed efficiently due to the underlying tree.

  ## Examples

      iex> A.OrdMap.new([b: "B", d: "D", a: "A", c: "C"]) |> A.OrdMap.last()
      {:c, "C"}
      iex> A.OrdMap.new([]) |> A.OrdMap.last()
      nil

  """
  @spec last(t(k, v)) :: {:ok, {k, v}} | :error when k: key, v: value
  def last(ord_map)

  def last(%A.OrdMap{map: map, tree: tree}) do
    case A.RBTree.max(tree) do
      {:ok, {_index, key}} ->
        %{^key => {_index, value}} = map
        {key, value}

      :error ->
        nil
    end
  end

  @doc """
  Folds (reduces) the ordered map from the right with a function. Requires an accumulator.

  ## Examples

      iex> ord_map = A.OrdMap.new([b: "Bat", c: "Cat", a: "Ant"])
      iex> A.OrdMap.foldl(ord_map, "", fn {_key, value}, acc -> value <> acc end)
      "AntCatBat"
      iex> A.OrdMap.foldl(ord_map, [], fn {key, value}, acc -> [{key, value <> "man"} | acc] end)
      [a: "Antman", c: "Catman", b: "Batman"]

  """
  def foldl(ord_map, acc, fun)

  def foldl(%__MODULE__{tree: tree, map: map}, acc, fun) when is_function(fun, 2) do
    A.RBTree.foldl(tree, acc, fn {_index, key}, loop_acc ->
      %{^key => {_index, value}} = map
      fun.({key, value}, loop_acc)
    end)
  end

  @doc """
  Folds (reduces) the ordered map from the right with a function. Requires an accumulator.

  Unlike linked lists, this is as efficient as `foldl/3`. This can typically save a call
  to `Enum.reverse/1` on the result when building a list.

  ## Examples

      iex> ord_map = A.OrdMap.new([b: "Bat", c: "Cat", a: "Ant"])
      iex> A.OrdMap.foldr(ord_map, "", fn {_key, value}, acc -> value <> acc end)
      "BatCatAnt"
      iex> A.OrdMap.foldr(ord_map, [], fn {key, value}, acc -> [{key, value <> "man"} | acc] end)
      [b: "Batman", c: "Catman", a: "Antman"]

  """
  def foldr(ord_map, acc, fun)

  def foldr(%__MODULE__{tree: tree, map: map}, acc, fun) when is_function(fun, 2) do
    A.RBTree.foldr(tree, acc, fn {_index, key}, loop_acc ->
      %{^key => {_index, value}} = map
      fun.({key, value}, loop_acc)
    end)
  end

  # Private functions

  defp insert_new(%__MODULE__{map: map, tree: tree} = ord_map, key, value) do
    # meant to be called ONLY when sure the key does NOT already exist

    new_index =
      case A.RBTree.max(tree) do
        {:ok, {last_index, _}} -> last_index + 1
        :error -> 0
      end

    {_, new_tree} = A.RBTree.map_insert(tree, new_index, key)

    # insert crashes if index exists, which should never happen here!
    %{
      ord_map
      | tree: new_tree,
        map: Map.put(map, key, {new_index, value})
    }
  end

  defp replace_existing(%__MODULE__{map: map} = ord_map, index, key, value) do
    %{ord_map | map: Map.put(map, key, {index, value})}
  end

  defp delete_existing(%__MODULE__{tree: tree} = ord_map, new_map, index) do
    {:ok, _, new_tree} = A.RBTree.map_pop(tree, index)

    %{
      ord_map
      | tree: new_tree,
        map: new_map
    }
  end

  @doc false
  def iterator(%__MODULE__{tree: tree, map: map}) do
    {A.RBTree.iterator(tree), map}
  end

  @doc false
  def next({iterator, map}) do
    case A.RBTree.next(iterator) do
      {{index, key}, new_iterator} ->
        %{^key => {^index, value}} = map
        {key, value, {new_iterator, map}}

      nil ->
        nil
    end
  end

  defimpl Enumerable do
    def count(ord_map) do
      {:ok, A.OrdMap.size(ord_map)}
    end

    def member?(ord_map, key_value) do
      with {key, value} <- key_value,
           {:ok, ^value} <- A.OrdMap.fetch(ord_map, key) do
        {:ok, true}
      else
        _ -> {:ok, false}
      end
    end

    def slice(_ord_map), do: {:error, __MODULE__}

    def reduce(ord_map, acc, fun) do
      iterator = A.OrdMap.iterator(ord_map)
      reduce_iterator(iterator, acc, fun)
    end

    defp reduce_iterator(_iterator, {:halt, acc}, _fun), do: {:halted, acc}

    defp reduce_iterator(iterator, {:suspend, acc}, fun),
      do: {:suspended, acc, &reduce_iterator(iterator, &1, fun)}

    defp reduce_iterator(iterator, {:cont, acc}, fun) do
      case A.OrdMap.next(iterator) do
        {key, value, new_iterator} ->
          reduce_iterator(new_iterator, fun.({key, value}, acc), fun)

        nil ->
          {:done, acc}
      end
    end
  end

  defimpl Collectable do
    def into(map) do
      fun = fn
        map_acc, {:cont, {key, value}} ->
          A.OrdMap.put(map_acc, key, value)

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
      open = color("#A<ord(%{", :map, opts)
      sep = color(",", :map, opts)
      close = color("})>", :map, opts)

      as_list = Enum.to_list(ord_map)

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
  end

  if Code.ensure_loaded?(Jason.Encoder) do
    defimpl Jason.Encoder do
      def encode(map, opts) do
        map |> Enum.to_list() |> Jason.Encode.keyword(opts)
      end
    end
  end
end
