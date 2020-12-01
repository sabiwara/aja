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
  - `first/1` and `last/1` to efficiently retrieve the first / last key-value pair
  - `pop_first/1` and `pop_last/1` to efficiently pop the first / last key-value pair
  - `foldl/3` and `foldr/3` to efficiently fold (reduce) from left-to-right or right-to-left

  Examples:

      iex> ord_map = A.OrdMap.new(b: "Bat", a: "Ant", c: "Cat")
      iex> A.OrdMap.first(ord_map)
      {:b, "Bat"}
      iex> {:c, "Cat", updated} = A.OrdMap.pop_last(ord_map)
      iex> updated
      #A<ord(%{b: "Bat", a: "Ant"})>
      iex> A.OrdMap.foldr(ord_map, [], fn _key, value, acc -> [value <> "man" | acc] end)
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
  - construct new ordered maps without the clutter of a entry list
  - pattern match on key-values like regular maps
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

  ## Limitations: equality

  `A.OrdMap` comparisons based on `==/2`, `===/2` or the pin operator `^` are **UNRELIABLE**.

  In Elixir, pattern-matching and equality for structs work based on their internal representation.
  While this is a pragmatic design choice that simplifies the language, it means that we cannot
  rededine how they work for custom data structures.

  Two ordered maps that are semantically equal (same key-value pairs in the same order) might be considered
  non-equal when comparing their internals, because there is not a unique way of representing one same map.

  `A.OrdMap.equal?/2` should be used instead:

      iex> ord_map1 = A.OrdMap.new(a: "Ant", b: "Bat")
      #A<ord(%{a: "Ant", b: "Bat"})>
      iex> ord_map2 = A.OrdMap.new(c: "Cat", a: "Ant", b: "Bat") |> A.OrdMap.delete(:c)
      #A<ord(%{a: "Ant", b: "Bat"})>
      iex> ord_map1 == ord_map2
      false
      iex> A.OrdMap.equal?(ord_map1, ord_map2)
      true
      iex> match?(^ord_map1, ord_map2)
      false

  ## Pattern-matching and opaque type

  An `A.OrdMap` is represented internally using the `%A.OrdMap{}` struct. This struct
  can be used whenever there's a need to pattern match on something being an `A.OrdMap`:
      iex> match?(%A.OrdMap{}, A.OrdMap.new())
      true

  Note, however, than `A.OrdMap` is an [opaque type](https://hexdocs.pm/elixir/typespecs.html#user-defined-types):
  its struct internal fields must not be accessed directly.

  As discussed in the previous section, [`ord/1`](`A.ord/1`) makes it
  possible to pattern match on keys as well as checking the type.

  ## Memory overhead

  `A.OrdMap` takes roughly more memory 2.5~3x than a regular map depending on the type of data:

      iex> map_size = 1..100 |> Map.new(fn i -> {i, <<i>>} end) |> :erts_debug.size()
      658
      iex> ord_map_size = 1..100 |> A.OrdMap.new(fn i -> {i, <<i>>} end) |> :erts_debug.size()
      1668
      iex> div(100 * ord_map_size, map_size)
      253

  ## Difference with `A.RBMap`

  - `A.OrdMap` keeps track of key insertion order
  - `A.RBMap` keeps keys sorted in ascending order whatever the insertion order is

  """

  @behaviour Access

  # TODO: inline what is relevant
  @compile {:inline,
            new: 1,
            new_loop: 2,
            fetch: 2,
            fetch!: 2,
            has_key?: 2,
            get: 2,
            put: 3,
            delete: 2,
            replace: 3,
            replace!: 3,
            insert_new: 4,
            do_put: 5,
            delete_existing: 3,
            equal?: 2,
            equal_loop: 2,
            next_index: 1,
            replace_many!: 2}

  @type key :: term
  @type value :: term
  @typep index :: non_neg_integer
  @typep entry(key, value) :: {index, key, value}
  @opaque t(key, value) :: %__MODULE__{
            map: %{optional(key) => entry(key, value)},
            tree: A.RBTree.Map.tree(index, entry(key, value))
          }
  @opaque t :: t(key, value)
  defstruct map: %{}, tree: A.RBTree.Map.empty()

  @doc """
  Returns the number of keys in `ord_map`.

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
    A.RBTree.Map.foldr(tree, [], fn _i, {_index, key, _value}, acc ->
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

  def values(%__MODULE__{tree: tree}) do
    A.RBTree.Map.foldr(tree, [], fn _i, {_index, _key, value}, acc ->
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

  def to_list(%__MODULE__{tree: tree}) do
    A.RBTree.Map.foldr(tree, [], fn __i, {_index, key, value}, acc ->
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
    %__MODULE__{}
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
    acc = {0, %{}, A.RBTree.Map.empty()}
    {_i, map, tree} = Enum.reduce(enumerable, acc, &new_loop/2)
    %__MODULE__{map: map, tree: tree}
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
  Fetches the value for a specific `key` and returns it in a ok-entry.
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
      %{^key => {_index, _key, value}} ->
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
      %{^key => {_index, _key, value}} ->
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
  def put_new(%__MODULE__{map: map, tree: tree} = ord_map, key, value) do
    case map do
      %{^key => _value} ->
        ord_map

      _ ->
        insert_new(map, tree, key, value)
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
  def replace(%__MODULE__{map: map, tree: tree} = ord_map, key, value) do
    case map do
      %{^key => {index, _key, _value}} ->
        do_put(map, tree, index, key, value)

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
  def replace!(%__MODULE__{map: map, tree: tree} = ord_map, key, value) do
    case map do
      %{^key => {index, _key, _value}} ->
        do_put(map, tree, index, key, value)

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
  def put_new_lazy(%__MODULE__{map: map, tree: tree} = ord_map, key, fun)
      when is_function(fun, 0) do
    if has_key?(ord_map, key) do
      ord_map
    else
      insert_new(map, tree, key, fun.())
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
    |> List.foldl([], fn key, acc ->
      case map do
        %{^key => {_index, _key, value}} ->
          [{key, value} | acc]

        _ ->
          acc
      end
    end)
    |> :lists.reverse()
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
      %{^key => {_index, _key, value}} ->
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
      %{^key => {_index, _key, value}} ->
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
  def put(ord_map, key, value)

  def put(%__MODULE__{map: map, tree: tree}, key, value) do
    case map do
      %{^key => {index, _key, _value}} ->
        do_put(map, tree, index, key, value)

      _ ->
        insert_new(map, tree, key, value)
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
  def delete(%__MODULE__{map: map, tree: tree} = ord_map, key) do
    case :maps.take(key, map) do
      {{index, _key, _value}, new_map} ->
        delete_existing(new_map, tree, index)

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
    foldl(ord_map2, ord_map1, fn key, value, acc -> put(acc, key, value) end)
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
  def update(ord_map, key, default, fun)

  def update(%__MODULE__{map: map, tree: tree}, key, default, fun) when is_function(fun, 1) do
    case map do
      %{^key => {index, _key, value}} ->
        do_put(map, tree, index, key, fun.(value))

      _ ->
        insert_new(map, tree, key, default)
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
  def pop(%__MODULE__{map: map, tree: tree} = ord_map, key, default \\ nil) do
    case :maps.take(key, map) do
      {{index, _key, value}, new_map} ->
        {value, delete_existing(new_map, tree, index)}

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
  def pop!(%__MODULE__{map: map, tree: tree} = ord_map, key) do
    case :maps.take(key, map) do
      {{index, _key, value}, new_map} ->
        {value, delete_existing(new_map, tree, index)}

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
  def pop_lazy(%__MODULE__{map: map, tree: tree} = ord_map, key, fun) when is_function(fun, 0) do
    case :maps.take(key, map) do
      {{index, _key, value}, new_map} ->
        {value, delete_existing(new_map, tree, index)}

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
  def update!(%__MODULE__{map: map, tree: tree} = ord_map, key, fun) when is_function(fun, 1) do
    case map do
      %{^key => {index, _key, value}} ->
        do_put(map, tree, index, key, fun.(value))

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

  Returns a `{key, value}` entry if `ord_map` is non-empty, or `nil` else.

  ## Examples

      iex> A.OrdMap.new([b: "B", d: "D", a: "A", c: "C"]) |> A.OrdMap.first()
      {:b, "B"}
      iex> A.OrdMap.new([]) |> A.OrdMap.first()
      nil
      iex> A.OrdMap.new([]) |> A.OrdMap.first(:error)
      :error

  """
  @spec first(t(k, v), default) :: {k, v} | default when k: key, v: value, default: term
  def first(ord_map, default \\ nil)

  def first(%A.OrdMap{tree: tree}, default) do
    case A.RBTree.Map.min(tree) do
      {_i, {_index, key, value}} ->
        {key, value}

      nil ->
        default
    end
  end

  @doc """
  Finds the last `{key, value}` pair in `ord_map`.

  Returns a `{key, value}` entry if `ord_map` is non-empty, or `nil` else.
  Can be accessed efficiently due to the underlying tree.

  ## Examples

      iex> A.OrdMap.new([b: "B", d: "D", a: "A", c: "C"]) |> A.OrdMap.last()
      {:c, "C"}
      iex> A.OrdMap.new([]) |> A.OrdMap.last()
      nil
      iex> A.OrdMap.new([]) |> A.OrdMap.last(:error)
      :error

  """
  @spec last(t(k, v), default) :: {k, v} | default when k: key, v: value, default: term
  def last(ord_map, default \\ nil)

  def last(%A.OrdMap{tree: tree}, default) do
    case A.RBTree.Map.max(tree) do
      {_i, {_index, key, value}} ->
        {key, value}

      nil ->
        default
    end
  end

  @doc """
  Finds and pops the first `{key, value}` pair in `ord_map`.

  Returns a `{key, value, new_tree}` entry for non-empty maps, `nil` for empty maps

  ## Examples

      iex> ord_map = A.OrdMap.new([b: "B", d: "D", a: "A", c: "C"])
      #A<ord(%{b: "B", d: "D", a: "A", c: "C"})>
      iex> {:b, "B", updated} = A.OrdMap.pop_first(ord_map)
      iex> updated
      #A<ord(%{d: "D", a: "A", c: "C"})>
      iex> A.OrdMap.new() |> A.OrdMap.pop_first()
      nil

  """
  @spec pop_first(t(k, v)) :: {k, v, t(k, v)} | nil when k: key, v: value
  def pop_first(ord_map)

  def pop_first(%__MODULE__{map: map, tree: tree}) do
    case A.RBTree.Map.pop_min(tree) do
      {_i, {_index, key, value}, new_tree} ->
        {_index_value, new_map} = Map.pop!(map, key)
        new_ord_map = %__MODULE__{map: new_map, tree: new_tree}
        {key, value, new_ord_map}

      :error ->
        nil
    end
  end

  @doc """
  Finds and pops the last `{key, value}` pair in `ord_map`.

  Returns a `{key, value, new_tree}` entry for non-empty maps, `nil` for empty maps

  ## Examples

      iex> ord_map = A.OrdMap.new([b: "B", d: "D", a: "A", c: "C"])
      #A<ord(%{b: "B", d: "D", a: "A", c: "C"})>
      iex> {:c, "C", updated} = A.OrdMap.pop_last(ord_map)
      iex> updated
      #A<ord(%{b: "B", d: "D", a: "A"})>
      iex> A.OrdMap.new() |> A.OrdMap.pop_last()
      nil

  """
  @spec pop_last(t(k, v)) :: {k, v, t(k, v)} | nil when k: key, v: value
  def pop_last(ord_map)

  def pop_last(%__MODULE__{map: map, tree: tree}) do
    case A.RBTree.Map.pop_max(tree) do
      {_i, {_index, key, value}, new_tree} ->
        {_index_value, new_map} = Map.pop!(map, key)
        new_ord_map = %__MODULE__{map: new_map, tree: new_tree}
        {key, value, new_ord_map}

      :error ->
        nil
    end
  end

  @doc """
  Folds (reduces) the ordered map from the right with a function. Requires an accumulator.

  ## Examples

      iex> ord_map = A.OrdMap.new([b: "Bat", c: "Cat", a: "Ant"])
      iex> A.OrdMap.foldl(ord_map, "", fn _key, value, acc -> value <> acc end)
      "AntCatBat"
      iex> A.OrdMap.foldl(ord_map, [], fn key, value, acc -> [{key, value <> "man"} | acc] end)
      [a: "Antman", c: "Catman", b: "Batman"]

  """
  def foldl(ord_map, acc, fun)

  def foldl(%__MODULE__{tree: tree}, acc, fun) when is_function(fun, 3) do
    A.RBTree.Map.foldl(tree, acc, fn _i, {_index, key, value}, loop_acc ->
      fun.(key, value, loop_acc)
    end)
  end

  @doc """
  Folds (reduces) the ordered map from the right with a function. Requires an accumulator.

  Unlike linked lists, this is as efficient as `foldl/3`. This can typically save a call
  to `Enum.reverse/1` on the result when building a list.

  ## Examples

      iex> ord_map = A.OrdMap.new([b: "Bat", c: "Cat", a: "Ant"])
      iex> A.OrdMap.foldr(ord_map, "", fn _key, value, acc -> value <> acc end)
      "BatCatAnt"
      iex> A.OrdMap.foldr(ord_map, [], fn key, value, acc -> [{key, value <> "man"} | acc] end)
      [b: "Batman", c: "Catman", a: "Antman"]

  """
  def foldr(ord_map, acc, fun)

  def foldr(%__MODULE__{tree: tree}, acc, fun) when is_function(fun, 3) do
    A.RBTree.Map.foldr(tree, acc, fn _i, {_index, key, value}, loop_acc ->
      fun.(key, value, loop_acc)
    end)
  end

  # Private functions

  defp insert_new(map, tree, key, value) do
    new_index = next_index(tree)

    do_put(map, tree, new_index, key, value)
  end

  defp next_index(tree) do
    case A.RBTree.Map.max(tree) do
      {last_index, _} -> last_index + 1
      nil -> 0
    end
  end

  defp do_put(map, tree, index, key, value) do
    entry = {index, key, value}
    {_, new_tree} = A.RBTree.Map.insert(tree, index, entry)
    new_map = Map.put(map, key, entry)

    %__MODULE__{map: new_map, tree: new_tree}
  end

  defp delete_existing(new_map, tree, index) do
    {_, new_tree} = A.RBTree.Map.pop(tree, index)

    %__MODULE__{map: new_map, tree: new_tree}
  end

  defp new_loop({key, value}, _acc = {i, map, tree}) do
    case map do
      %{^key => {index, _key, _value}} ->
        entry = {index, key, value}
        new_map = Map.replace!(map, key, entry)
        {_result, new_tree} = A.RBTree.Map.insert(tree, index, entry)
        {i, new_map, new_tree}

      _ ->
        entry = {i, key, value}
        new_map = Map.put_new(map, key, entry)
        {_result, new_tree} = A.RBTree.Map.insert(tree, i, entry)
        {i + 1, new_map, new_tree}
    end
  end

  defp replace_many_loop(_i, map, tree, []) do
    %__MODULE__{map: map, tree: tree}
  end

  defp replace_many_loop(i, map, tree, [{key, value} | rest]) do
    case map do
      %{^key => {index, _key, _value}} ->
        entry = {index, key, value}
        new_map = Map.replace!(map, key, entry)
        {_result, new_tree} = A.RBTree.Map.insert(tree, index, entry)
        replace_many_loop(i, new_map, new_tree, rest)

      _ ->
        {:error, key}
    end
  end

  @doc false
  def iterator(%__MODULE__{tree: tree}) do
    A.RBTree.Map.iterator(tree)
  end

  @doc false
  def next(iterator) do
    case A.RBTree.Map.next(iterator) do
      {_i, {_index, key, value}, new_iterator} ->
        {key, value, new_iterator}

      nil ->
        nil
    end
  end

  @doc false
  def replace_many!(%__MODULE__{map: map, tree: tree} = ord_map, key_values) do
    case replace_many_loop(next_index(tree), map, tree, key_values) do
      {:error, key} -> raise KeyError, key: key, term: ord_map
      new_ord_map -> new_ord_map
    end
  end

  @doc false
  def reduce(%__MODULE__{tree: tree}, acc, fun) do
    A.RBTree.Map.reduce(tree, acc, fn {_i, {_index, key, value}}, acc ->
      fun.({key, value}, acc)
    end)
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

    defdelegate reduce(ord_map, acc, fun), to: A.OrdMap
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
    import A.Helpers.CustomMaps, only: [implement_inspect: 3]

    implement_inspect(A.OrdMap, "#A<ord(", ")>")
  end

  if Code.ensure_loaded?(Jason.Encoder) do
    defimpl Jason.Encoder do
      def encode(map, opts) do
        map |> Enum.to_list() |> Jason.Encode.keyword(opts)
      end
    end
  end
end
