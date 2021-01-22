defmodule A.RBMap do
  @moduledoc ~S"""
  A Red-Black tree implementation of a map. It keeps keys sorted in ascending order.

  Erlang's `:gb_trees` offer similar functionalities and performance.
  However `A.RBMap`:
  - is a better Elixir citizen: pipe-friendliness, `Access` behaviour, `Enum` / `Inspect` / `Collectable` protocols
  - is more convenient and safer to use: no unsafe functions like `:gb_trees.from_orddict/1`
  - keeps the tree balanced on deletion [unlike `:gb_trees`](`:gb_trees.balance/1`)
  - optionally implements the `Jason.Encoder` protocol if `Jason` is installed

  ## Examples

  `A.RBMap` offers the same API as `Map` :

      iex> rb_map = A.RBMap.new([b: "Bat", a: "Ant", c: "Cat"])
      #A.RBMap<%{a: "Ant", b: "Bat", c: "Cat"}>
      iex> A.RBMap.get(rb_map, :c)
      "Cat"
      iex> A.RBMap.put(rb_map, :d, "Dinosaur")
      #A.RBMap<%{a: "Ant", b: "Bat", c: "Cat", d: "Dinosaur"}>
      iex> A.RBMap.delete(rb_map, :b)
      #A.RBMap<%{a: "Ant", c: "Cat"}>
      iex> Enum.to_list(rb_map)
      [a: "Ant", b: "Bat", c: "Cat"]
      iex> [c: "Cat", b: "Buffalo"] |> Enum.into(A.RBMap.new([a: "Ant", b: "Bat", d: "Dinosaur"]))
      #A.RBMap<%{a: "Ant", b: "Buffalo", c: "Cat", d: "Dinosaur"}>

  ## Tree-specific functions

  Due to its sorted nature, `A.RBMap` also offers some extra methods not present in `Map`, like:
  - `first/1` and `last/1` to efficiently retrieve the first (smallest) / last (largest) key-value pair
  - `pop_first/1` and `pop_last/1` to efficiently pop the first (smallest) / last (largest) key-value pair
  - `foldl/3` and `foldr/3` to efficiently fold (reduce) from left-to-right or right-to-left

  Examples:

      iex> rb_map = A.RBMap.new(%{1 => "一", 2 => "二", 3 => "三"})
      iex> A.RBMap.first(rb_map)
      {1, "一"}
      iex> {3, "三", updated} = A.RBMap.pop_last(rb_map)
      iex> updated
      #A.RBMap<%{1 => "一", 2 => "二"}>
      iex> A.RBMap.foldr(rb_map, [], fn _key, value, acc -> [value | acc] end)
      ["一", "二", "三"]

  ## Access behaviour

  `A.RBMap` implements the `Access` behaviour.

      iex> rb_map = A.RBMap.new([b: "Bat", a: "Ant", c: "Cat"])
      iex> rb_map[:a]
      "Ant"
      iex> put_in(rb_map[:b], "Buffalo")
      #A.RBMap<%{a: "Ant", b: "Buffalo", c: "Cat"}>
      iex> put_in(rb_map[:d], "Dinosaur")
      #A.RBMap<%{a: "Ant", b: "Bat", c: "Cat", d: "Dinosaur"}>
      iex> {"Cat", updated} = pop_in(rb_map[:c])
      iex> updated
      #A.RBMap<%{a: "Ant", b: "Bat"}>

  ## With `Jason`

      iex> A.RBMap.new(%{1 => "一", 2 => "二", 11 => "十一"}) |> Jason.encode!()
      "{\"1\":\"一\",\"2\":\"二\",\"11\":\"十一\"}"

  It also preserves the key order.

  ## Limitations: pattern-matching and equality

  Like `:gb_trees`, `A.RBMap`s face two strong limitations:
  - pattern-matching on key-values like maps is **NOT POSSIBLE**
  - comparisons based on `==/2`, `===/2` or the pin operator `^` are **UNRELIABLE**

  In Elixir, pattern-matching and equality for structs work based on their internal representation.
  While this is a pragmatic design choice that simplifies the language, it means that we cannot
  rededine how they work for custom data structures.

  Tree-based maps that are semantically equal (same key-value pairs in the same order) might be considered
  non-equal when comparing their internals, because there is not a unique way of representing one same map.

  `A.RBMap.equal?/2` should be used instead:

      iex> rb_map1 = A.RBMap.new([a: "Ant", b: "Bat"])
      #A.RBMap<%{a: "Ant", b: "Bat"}>
      iex> rb_map2 = A.RBMap.new([b: "Bat", a: "Ant"])
      #A.RBMap<%{a: "Ant", b: "Bat"}>
      iex> rb_map1 == rb_map2
      false
      iex> A.RBMap.equal?(rb_map1, rb_map2)
      true
      iex> match?(^rb_map1, rb_map2)
      false

  An `A.RBMap` is represented internally using the `%A.RBMap{}` struct. This struct
  can be used whenever there's a need to pattern match on something being an `A.RBMap`:

      iex> match?(%A.RBMap{}, A.RBMap.new(a: "Ant"))
      true

  Note, however, than `A.RBMap` is an [opaque type](https://hexdocs.pm/elixir/typespecs.html#user-defined-types):
  its struct internal fields must not be accessed directly.

  ## Note about numbers

  Unlike regular maps, `A.RBMap`s only uses ordering for key comparisons,
  not strict comparisons. Integers and floats are indistiguinshable as keys.

      iex> %{1 => "一", 2 => "二"} |> Map.fetch(2.0)
      :error
      iex> A.RBMap.new(%{1 => "一", 2 => "二"}) |> A.RBMap.fetch(2.0)
      {:ok, "二"}

  Erlang's `:gb_trees` module works the same.

  ## Difference with `A.OrdMap`

  - `A.OrdMap` keeps track of key insertion order
  - `A.RBMap` keeps keys sorted in ascending order whatever the insertion order is

  ## Memory overhead

  `A.RBMap` takes roughly 1.4x more memory than a regular map depending on the type of data:

      iex> key_values = Enum.map(1..100, fn i -> {i, <<i>>} end)
      iex> map_size = Map.new(key_values) |> :erts_debug.size()
      658
      iex> rb_map_size = A.RBMap.new(key_values) |> :erts_debug.size()
      910
      iex> :gb_trees.from_orddict(key_values) |> :erts_debug.size()
      803
      iex> div(100 * rb_map_size, map_size)
      138

  """

  @behaviour Access

  # TODO: inline what is relevant
  # WARNING: be careful with non-tail recursive functions looping on the full tree!
  @compile {:inline,
            fetch: 2, fetch!: 2, put: 3, has_key?: 2, equal?: 2, equal_loop: 2, pop_existing: 2}

  @type key :: term
  @type value :: term
  @opaque t(key, value) :: %__MODULE__{
            root: A.RBTree.Map.tree(key, value),
            size: non_neg_integer
          }
  @opaque t :: t(key, value)
  @opaque iterator(key, value) :: A.RBTree.Map.iterator(key, value)

  defstruct root: A.RBTree.Map.empty(), size: 0

  @doc """
  Returns the number of keys in `rb_map`.

  ## Examples

      iex> A.RBMap.size(A.RBMap.new(a: 1, b: 2, c: 3))
      3
      iex> A.RBMap.size(A.RBMap.new(a: 1, a: 2, a: 3))
      1

  """
  @spec size(t) :: non_neg_integer
  def size(rb_map)
  def size(%__MODULE__{size: size}), do: size

  @doc """
  Returns all keys from `rb_map`.

  ## Examples

      iex> rb_map = A.RBMap.new(b: "Bat", c: "Cat", a: "Ant")
      iex> A.RBMap.keys(rb_map)
      [:a, :b, :c]

  """
  @spec keys(t(k, value)) :: [k] when k: key
  def keys(rb_map)

  def keys(%__MODULE__{root: root}) do
    A.RBTree.Map.foldr(root, [], fn key, _value, acc -> [key | acc] end)
  end

  @doc """
  Returns all values from `rb_map`.

  ## Examples

      iex> rb_map = A.RBMap.new(b: "Bat", c: "Cat", a: "Ant")
      iex> A.RBMap.values(rb_map)
      ["Ant", "Bat", "Cat"]

  """
  @spec values(t(key, v)) :: [v] when v: value
  def values(rb_map)

  def values(%__MODULE__{root: root}) do
    A.RBTree.Map.foldr(root, [], fn _key, value, acc -> [value | acc] end)
  end

  @doc """
  Returns all values from `rb_map`.

  ## Examples

      iex> rb_map = A.RBMap.new(b: "Bat", c: "Cat", a: "Ant")
      iex> A.RBMap.to_list(rb_map)
      [a: "Ant", b: "Bat", c: "Cat"]

  """
  @spec to_list(t(k, v)) :: [{k, v}] when k: key, v: value
  def to_list(%__MODULE__{root: root}), do: A.RBTree.Map.to_list(root)

  @doc """
  Returns a new empty map.

  ## Examples

      iex> A.RBMap.new()
      #A.RBMap<%{}>

  """
  @spec new() :: t
  def new, do: %__MODULE__{}

  @doc """
  Creates a map from an `enumerable`.

  Keys are sorted upon insertion, and duplicated keys are removed;
  the latest one prevails.

  ## Examples

      iex> A.RBMap.new(b: "Bat", a: "Ant", c: "Cat")
      #A.RBMap<%{a: "Ant", b: "Bat", c: "Cat"}>
      iex> A.RBMap.new(b: "Bat", a: "Ant", b: "Buffalo", a: "Antelope")
      #A.RBMap<%{a: "Antelope", b: "Buffalo"}>

  """
  @spec new(Enumerable.t()) :: t
  def new(enumerable) do
    {size, root} = A.RBTree.Map.empty() |> A.RBTree.Map.insert_many(enumerable)
    %__MODULE__{root: root, size: size}
  end

  @doc """
  Creates a map from an `enumerable` via the given `transform` function.

  Duplicated keys are removed; the latest one prevails.

  ## Examples

      iex>  A.RBMap.new([:a, :b], fn x -> {x, x} end)
      #A.RBMap<%{a: :a, b: :b}>

  """
  @spec new(Enumerable.t(), (term -> {k, v})) :: t(k, v) when k: key, v: value
  def new(enumerable, transform) do
    enumerable
    |> Enum.map(transform)
    |> new()
  end

  @doc """
  Returns whether the given `key` exists in `rb_map`.

  ## Examples

      iex> rb_map = A.RBMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.RBMap.has_key?(rb_map, :a)
      true
      iex> A.RBMap.has_key?(rb_map, :d)
      false
      iex> A.RBMap.has_key?(A.RBMap.new(%{1.0 => "uno"}), 1)
      true

  """
  @spec has_key?(t(k, value), k) :: boolean when k: key
  def has_key?(rb_map, key) do
    case fetch(rb_map, key) do
      {:ok, _} -> true
      :error -> false
    end
  end

  @doc ~S"""
  Fetches the value for a specific `key` and returns it in a ok-tuple.
  If the key does not exist, returns :error.

  ## Examples

      iex> rb_map = A.RBMap.new(a: "A", b: "B", c: "C")
      iex> A.RBMap.fetch(rb_map, :c)
      {:ok, "C"}
      iex> A.RBMap.fetch(rb_map, :z)
      :error

  """
  @impl Access
  @spec fetch(t(k, v), k) :: {:ok, v} | :error when k: key, v: value
  def fetch(rb_map, key)
  def fetch(%__MODULE__{root: root}, key), do: A.RBTree.Map.fetch(root, key)

  @doc ~S"""
  Fetches the value for a specific `key` and returns it in a ok-tuple.
  If the key does not exist, returns :error.

  ## Examples

      iex> rb_map = A.RBMap.new(a: "A", b: "B", c: "C")
      iex> A.RBMap.fetch!(rb_map, :c)
      "C"
      iex> A.RBMap.fetch!(rb_map, :z)
      ** (KeyError) key :z not found in: #A.RBMap<%{a: "A", b: "B", c: "C"}>

  """
  @spec fetch!(t(k, v), k) :: v when k: key, v: value
  def fetch!(%__MODULE__{} = rb_map, key) do
    case fetch(rb_map, key) do
      {:ok, value} ->
        value

      _ ->
        raise KeyError, key: key, term: rb_map
    end
  end

  @doc """
  Puts the given `value` under `key` unless the entry `key`
  already exists in `rb_map`.

  ## Examples

      iex> rb_map = A.RBMap.new(b: "Bat", c: "Cat")
      iex> A.RBMap.put_new(rb_map, :a, "Ant")
      #A.RBMap<%{a: "Ant", b: "Bat", c: "Cat"}>
      iex> A.RBMap.put_new(rb_map, :b, "Buffalo")
      #A.RBMap<%{b: "Bat", c: "Cat"}>

  """
  @spec put_new(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def put_new(%__MODULE__{} = rb_map, key, value) do
    if has_key?(rb_map, key) do
      rb_map
    else
      put(rb_map, key, value)
    end
  end

  @doc """
  Puts a value under `key` only if the `key` already exists in `rb_map`.

  ## Examples

      iex> rb_map = A.RBMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.RBMap.replace(rb_map, :b, "Buffalo")
      #A.RBMap<%{a: "Ant", b: "Buffalo", c: "Cat"}>
      iex> A.RBMap.replace(rb_map, :d, "Dinosaur")
      #A.RBMap<%{a: "Ant", b: "Bat", c: "Cat"}>

  """
  @spec replace(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def replace(%__MODULE__{} = rb_map, key, value) do
    if has_key?(rb_map, key) do
      put(rb_map, key, value)
    else
      rb_map
    end
  end

  @doc """
  Puts a value under `key` only if the `key` already exists in `rb_map`.

  If `key` is not present in `rb_map`, a `KeyError` exception is raised.

  ## Examples

      iex> rb_map = A.RBMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.RBMap.replace!(rb_map, :b, "Buffalo")
      #A.RBMap<%{a: "Ant", b: "Buffalo", c: "Cat"}>
      iex> A.RBMap.replace!(rb_map, :d, "Dinosaur")
      ** (KeyError) key :d not found in: #A.RBMap<%{a: \"Ant\", b: \"Bat\", c: \"Cat\"}>

  """
  @spec replace!(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def replace!(%__MODULE__{} = rb_map, key, value) do
    if has_key?(rb_map, key) do
      put(rb_map, key, value)
    else
      raise KeyError, key: key, term: rb_map
    end
  end

  @doc """
  Evaluates `fun` and puts the result under `key`
  in `rb_map` unless `key` is already present.

  This function is useful in case you want to compute the value to put under
  `key` only if `key` is not already present, as for example, when the value is expensive to
  calculate or generally difficult to setup and teardown again.

  ## Examples

      iex> rb_map = A.RBMap.new(a: "Ant", c: "Cat")
      iex> expensive_fun = fn -> "Buffalo" end
      iex> A.RBMap.put_new_lazy(rb_map, :b, expensive_fun)
      #A.RBMap<%{a: "Ant", b: "Buffalo", c: "Cat"}>
      iex> A.RBMap.put_new_lazy(rb_map, :a, expensive_fun)
      #A.RBMap<%{a: "Ant", c: "Cat"}>

  """
  @spec put_new_lazy(t(k, v), k, (() -> v)) :: t(k, v) when k: key, v: value
  def put_new_lazy(%__MODULE__{} = rb_map, key, fun) when is_function(fun, 0) do
    if has_key?(rb_map, key) do
      rb_map
    else
      put(rb_map, key, fun.())
    end
  end

  @doc """
  Returns a new map with all the key-value pairs in `rb_map` where the key
  is in `keys`.

  If `keys` contains keys that are not in `rb_map`, they're simply ignored.

  ## Examples

      iex> rb_map = A.RBMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.RBMap.take(rb_map, [:c, :e, :a])
      #A.RBMap<%{a: "Ant", c: "Cat"}>

  """
  @spec get(t(k, v), [k]) :: t(k, v) when k: key, v: value
  def take(rb_map, keys)

  def take(%__MODULE__{root: root}, keys) when is_list(keys) do
    keys
    |> List.foldl([], fn key, acc ->
      case A.RBTree.Map.fetch(root, key) do
        {:ok, value} ->
          [{key, value} | acc]

        :error ->
          acc
      end
    end)
    |> new()
  end

  @doc """
  Gets the value for a specific `key` in `rb_map`.

  If `key` is present in `rb_map` then its value `value` is
  returned. Otherwise, `default` is returned.

  If `default` is not provided, `nil` is used.

  ## Examples

      iex> rb_map = A.RBMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.RBMap.get(rb_map, :a)
      "Ant"
      iex> A.RBMap.get(rb_map, :z)
      nil
      iex> A.RBMap.get(rb_map, :z, "Zebra")
      "Zebra"

  """
  @spec get(t(k, v), k, v) :: v | nil when k: key, v: value
  def get(%__MODULE__{} = rb_map, key, default \\ nil) do
    case fetch(rb_map, key) do
      {:ok, value} ->
        value

      :error ->
        default
    end
  end

  @doc """
  Gets the value for a specific `key` in `rb_map`.

  If `key` is present in `rb_map` then its value `value` is
  returned. Otherwise, `fun` is evaluated and its result is returned.

  This is useful if the default value is very expensive to calculate or
  generally difficult to setup and teardown again.

  ## Examples

      iex> rb_map = A.RBMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> expensive_fun = fn -> "Zebra" end
      iex> A.RBMap.get_lazy(rb_map, :a, expensive_fun)
      "Ant"
      iex> A.RBMap.get_lazy(rb_map, :z, expensive_fun)
      "Zebra"

  """
  @spec get_lazy(t(k, v), k, v) :: v | nil when k: key, v: value
  def get_lazy(%__MODULE__{} = rb_map, key, fun) when is_function(fun, 0) do
    case fetch(rb_map, key) do
      {:ok, value} ->
        value

      :error ->
        fun.()
    end
  end

  @doc """
  Puts the given `value` under `key` in `rb_map`.

  If the `key` does exist, it overwrites the existing value.

  ## Examples

      iex> rb_map = A.RBMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.RBMap.put(rb_map, :b, "Buffalo")
      #A.RBMap<%{a: "Ant", b: "Buffalo", c: "Cat"}>
      iex> A.RBMap.put(rb_map, :d, "Dinosaur")
      #A.RBMap<%{a: "Ant", b: "Bat", c: "Cat", d: "Dinosaur"}>

  """
  @spec put(t(k, v), k, v) :: v when k: key, v: value
  def put(rb_map, key, value)

  def put(%__MODULE__{root: root, size: size}, key, value) do
    {result, new_root} = A.RBTree.Map.insert(root, key, value)

    case result do
      :new -> %__MODULE__{root: new_root, size: size + 1}
      :overwrite -> %__MODULE__{root: new_root, size: size}
    end
  end

  @doc """
  Deletes the entry in `rb_map` for a specific `key`.

  If the `key` does not exist, returns `rb_map` unchanged.

  ## Examples

      iex> rb_map = A.RBMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.RBMap.delete(rb_map, :b)
      #A.RBMap<%{a: "Ant", c: "Cat"}>
      iex> A.RBMap.delete(rb_map, :z)
      #A.RBMap<%{a: "Ant", b: "Bat", c: "Cat"}>

  """
  @spec delete(t(k, v), k) :: t(k, v) when k: key, v: value
  def delete(%__MODULE__{} = rb_map, key) do
    case pop_existing(rb_map, key) do
      {_value, new_rb_map} -> new_rb_map
      :error -> rb_map
    end
  end

  @doc """
  Merges two maps into one.

  All keys in `rb_map2` will be added to `rb_map1`, overriding any existing one
  (i.e., the keys in `rb_map2` "have precedence" over the ones in `rb_map1`).

  ## Examples

      iex> A.RBMap.merge(A.RBMap.new(%{a: 1, b: 2}), A.RBMap.new(%{a: 3, d: 4}))
      #A.RBMap<%{a: 3, b: 2, d: 4}>

  """
  @spec merge(t(k, v), t(k, v)) :: t(k, v) when k: key, v: value
  def merge(%__MODULE__{} = rb_map1, %__MODULE__{} = rb_map2) do
    # TODO optimize
    A.RBTree.Map.foldl(rb_map2.root, rb_map1, fn key, value, acc -> put(acc, key, value) end)
  end

  @doc """
  Updates the `key` in `rb_map` with the given function.

  If `key` is present in `rb_map` then the existing value is passed to `fun` and its result is
  used as the updated value of `key`. If `key` is
  not present in `rb_map`, `default` is inserted as the value of `key`. The default
  value will not be passed through the update function.

  ## Examples

      iex> rb_map = A.RBMap.new(b: "Bat", c: "Cat")
      iex>A.RBMap.update(rb_map, :b, "N/A", &String.upcase/1)
      #A.RBMap<%{b: "BAT", c: "Cat"}>
      iex>A.RBMap.update(rb_map, :a, "N/A", &String.upcase/1)
      #A.RBMap<%{a: "N/A", b: "Bat", c: "Cat"}>

  """
  @spec update(t(k, v), k, v, (v -> v)) :: t(k, v) when k: key, v: value
  def update(%__MODULE__{} = rb_map, key, default, fun) when is_function(fun, 1) do
    case fetch(rb_map, key) do
      {:ok, value} ->
        put(rb_map, key, fun.(value))

      :error ->
        put(rb_map, key, default)
    end
  end

  @doc ~S"""
  Returns the value for `key` and the updated map without `key`.

  If `key` is present in the map with a value `value`,
  `{value, new_rb_map}` is returned.
  If `key` is not present in the map, `{default, rb_map}` is returned.

  ## Examples

      iex> rb_map = A.RBMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> {"Bat", updated} = A.RBMap.pop(rb_map, :b)
      iex> updated
      #A.RBMap<%{a: "Ant", c: "Cat"}>
      iex> {nil, updated} = A.RBMap.pop(rb_map, :z)
      iex> updated
      #A.RBMap<%{a: "Ant", b: "Bat", c: "Cat"}>
      iex> {"Z", updated} = A.RBMap.pop(rb_map, :z, "Z")
      iex> updated
      #A.RBMap<%{a: "Ant", b: "Bat", c: "Cat"}>
  """
  @impl Access
  @spec pop(t(k, v), k, v) :: {v, t(k, v)} when k: key, v: value
  def pop(%__MODULE__{} = rb_map, key, default \\ nil) do
    case pop_existing(rb_map, key) do
      {value, new_rb_map} -> {value, new_rb_map}
      :error -> {default, rb_map}
    end
  end

  @doc ~S"""
  Returns the value for `key` and the updated map without `key`.

  Behaves the same as `pop/3` but raises if `key` is not present in `rb_map`.

  ## Examples

      iex> rb_map = A.RBMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> {"Bat", updated} = A.RBMap.pop!(rb_map, :b)
      iex> updated
      #A.RBMap<%{a: "Ant", c: "Cat"}>
      iex> A.RBMap.pop!(rb_map, :z)
      ** (KeyError) key :z not found in: #A.RBMap<%{a: "Ant", b: "Bat", c: "Cat"}>
  """
  @spec pop!(t(k, v), k) :: {v, t(k, v)} when k: key, v: value
  def pop!(%__MODULE__{} = rb_map, key) do
    case pop_existing(rb_map, key) do
      {value, new_rb_map} -> {value, new_rb_map}
      :error -> raise KeyError, key: key, term: rb_map
    end
  end

  @doc """
  Lazily returns and removes the value associated with `key` in `rb_map`.

  If `key` is present in `rb_map`, it returns `{value, new_map}` where `value` is the value of
  the key and `new_map` is the result of removing `key` from `rb_map`. If `key`
  is not present in `rb_map`, `{fun_result, rB_map}` is returned, where `fun_result`
  is the result of applying `fun`.

  This is useful if the default value is very expensive to calculate or
  generally difficult to setup and teardown again.

  ## Examples

      iex> rb_map = A.RBMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> expensive_fun = fn -> "Zebra" end
      iex> {"Ant", updated} = A.RBMap.pop_lazy(rb_map, :a, expensive_fun)
      iex> updated
      #A.RBMap<%{b: "Bat", c: "Cat"}>
      iex> {"Zebra", not_updated} = A.RBMap.pop_lazy(rb_map, :z, expensive_fun)
      iex> not_updated
      #A.RBMap<%{a: "Ant", b: "Bat", c: "Cat"}>

  """
  @spec pop_lazy(t(k, v), k, (() -> v)) :: {v, t(k, v)} when k: key, v: value
  def pop_lazy(%__MODULE__{} = rb_map, key, fun) when is_function(fun, 0) do
    case pop_existing(rb_map, key) do
      {value, new_rb_map} -> {value, new_rb_map}
      :error -> {fun.(), rb_map}
    end
  end

  @doc """
  Drops the given `keys` from `rb_map`.

  If `keys` contains keys that are not in `rb_map`, they're simply ignored.

  ## Examples

      iex> rb_map = A.RBMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.RBMap.drop(rb_map, [:b, :d])
      #A.RBMap<%{a: "Ant", c: "Cat"}>

  """
  @spec drop(t(k, v), [k]) :: t(k, v) when k: key, v: value
  def drop(%__MODULE__{} = rb_map, keys) when is_list(keys) do
    List.foldl(keys, rb_map, fn key, acc ->
      delete(acc, key)
    end)
  end

  @doc """
  Puts a value under `key` only if the `key` already exists in `rb_map`.

  If `key` is not present in `rb_map`, a `KeyError` exception is raised.

  ## Examples

      iex> rb_map = A.RBMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> A.RBMap.update!(rb_map, :b,  &String.upcase/1)
      #A.RBMap<%{a: "Ant", b: "BAT", c: "Cat"}>
      iex> A.RBMap.update!(rb_map, :d, &String.upcase/1)
      ** (KeyError) key :d not found in: #A.RBMap<%{a: \"Ant\", b: \"Bat\", c: \"Cat\"}>

  """
  @spec update!(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def update!(%__MODULE__{} = rb_map, key, fun) when is_function(fun, 1) do
    case fetch(rb_map, key) do
      {:ok, value} ->
        put(rb_map, key, fun.(value))

      :error ->
        raise KeyError, key: key, term: rb_map
    end
  end

  @doc ~S"""
  Gets the value from `key` and updates it, all in one pass.

  Mirrors `Map.get_and_update/3`, see its documentation.

  ## Examples

      iex> rb_map = A.RBMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> {"bat", updated} = A.RBMap.get_and_update(rb_map, :b, fn current_value ->
      ...>   {current_value && String.downcase(current_value), "Buffalo"}
      ...> end)
      iex> updated
      #A.RBMap<%{a: "Ant", b: "Buffalo", c: "Cat"}>
      iex> {nil, updated} = A.RBMap.get_and_update(rb_map, :z, fn current_value ->
      ...>   {current_value && String.downcase(current_value), "Zebra"}
      ...> end)
      iex> updated
      #A.RBMap<%{a: "Ant", b: "Bat", c: "Cat", z: "Zebra"}>
      iex> {"Bat", updated} = A.RBMap.get_and_update(rb_map, :b, fn _ -> :pop end)
      iex> updated
      #A.RBMap<%{a: "Ant", c: "Cat"}>
      iex> {nil, updated} = A.RBMap.get_and_update(rb_map, :z, fn _ -> :pop end)
      iex> updated
      #A.RBMap<%{a: "Ant", b: "Bat", c: "Cat"}>
  """
  @impl Access
  @spec get_and_update(t(k, v), k, (v -> {returned, v} | :pop)) :: {returned, t(k, v)}
        when k: key, v: value, returned: term
  def get_and_update(%__MODULE__{} = rb_map, key, fun) when is_function(fun, 1) do
    A.Helpers.CustomMaps.get_and_update(rb_map, key, fun)
  end

  @doc ~S"""
  Gets the value from `key` and updates it, all in one pass.

  Mirrors `Map.get_and_update!/3`, see its documentation.

  ## Examples

      iex> rb_map = A.RBMap.new(a: "Ant", b: "Bat", c: "Cat")
      iex> {"bat", updated} = A.RBMap.get_and_update!(rb_map, :b, fn current_value ->
      ...>   {current_value && String.downcase(current_value), "Buffalo"}
      ...> end)
      iex> updated
      #A.RBMap<%{a: "Ant", b: "Buffalo", c: "Cat"}>
      iex> A.RBMap.get_and_update!(rb_map, :z, fn current_value ->
      ...>   {current_value && String.downcase(current_value), "Zebra"}
      ...> end)
      ** (KeyError) key :z not found in: #A.RBMap<%{a: "Ant", b: "Bat", c: "Cat"}>

  """
  @spec get_and_update!(t(k, v), k, (v -> {returned, v} | :pop)) :: {returned, t(k, v)}
        when k: key, v: value, returned: term
  def get_and_update!(%__MODULE__{} = rb_map, key, fun) when is_function(fun, 1) do
    A.Helpers.CustomMaps.get_and_update!(rb_map, key, fun)
  end

  @doc """
  Converts a `struct` to a `A.RBMap`.

  It accepts the struct module or a struct itself and
  simply removes the `__struct__` field from the given struct
  or from a new struct generated from the given module.

  ## Example

      defmodule User do
        defstruct [:name, :age]
      end

      A.RBMap.from_struct(User)
      #A.RBMap<%{age: nil, name: nil}>

      A.RBMap.from_struct(%User{name: "john", age: 44})
      #A.RBMap<%{name: "john"}>

  """
  @spec from_struct(atom | struct) :: t
  def from_struct(struct) do
    struct |> Map.from_struct() |> new()
  end

  @doc """
  Checks if two maps are equal.

  The comparison between keys is done using `==/2`, the comparison between values with strict equality `===/2`.

  ## Examples

      iex> A.RBMap.equal?(A.RBMap.new(a: 1, b: 2), A.RBMap.new(b: 2, a: 1))
      true
      iex> A.RBMap.equal?(A.RBMap.new([{1, "一"}, {2, "二"}]), A.RBMap.new([{1, "一"}, {2, "二"}]))
      true
      iex> A.RBMap.equal?(A.RBMap.new(a: 1, b: 2), A.RBMap.new(a: 3, b: 2))
      false
      iex> A.RBMap.equal?(A.RBMap.new(a: 1, b: 2), A.RBMap.new(a: 1.0, b: 2.0))
      false

  """
  @spec equal?(t, t) :: boolean
  def equal?(%A.RBMap{} = rb_map1, %A.RBMap{} = rb_map2) do
    rb_map1.size == rb_map2.size &&
      equal_loop(A.RBTree.Map.iterator(rb_map1.root), A.RBTree.Map.iterator(rb_map2.root))
  end

  defp equal_loop(iterator1, iterator2) do
    case {A.RBTree.Map.next(iterator1), A.RBTree.Map.next(iterator2)} do
      {nil, nil} ->
        true

      {{key1, same_value, next_iter1}, {key2, same_value, next_iter2}} when key1 == key2 ->
        equal_loop(next_iter1, next_iter2)

      _ ->
        false
    end
  end

  # Extra tree methods

  @doc """
  Finds the `{key, value}` pair corresponding to the smallest `key` in `rb_map`.
  Returns `nil` for empty maps.

  This is very efficient and can be done in O(log(n)).
  It should be preferred over `Enum.min/3`.

  ## Examples

      iex> A.RBMap.new([b: "B", d: "D", a: "A", c: "C"]) |> A.RBMap.first()
      {:a, "A"}
      iex> A.RBMap.new([]) |> A.RBMap.first()
      nil
      iex> A.RBMap.new([]) |> A.RBMap.first(:error)
      :error

  """
  @spec first(t(k, v), default) :: {k, v} | default when k: key, v: value, default: term
  def first(rb_map, default \\ nil)

  def first(%__MODULE__{root: root}, default) do
    A.RBTree.Map.min(root) || default
  end

  @doc """
  Finds the `{key, value}` pair corresponding to the largest `key` in `rb_map`.
  Returns `nil` for empty maps.

  This is very efficient and can be done in O(log(n)).
  It should be preferred over `Enum.max/3`.

  ## Examples

      iex> A.RBMap.new([b: "B", d: "D", a: "A", c: "C"]) |> A.RBMap.last()
      {:d, "D"}
      iex> A.RBMap.new([]) |> A.RBMap.last()
      nil
      iex> A.RBMap.new([]) |> A.RBMap.last(:error)
      :error

  """
  @spec last(t(k, v), default) :: {k, v} | default when k: key, v: value, default: term
  def last(rb_map, default \\ nil)

  def last(%__MODULE__{root: root}, default) do
    A.RBTree.Map.max(root) || default
  end

  @doc """
  Finds and pops the `{key, value}` pair corresponding to the smallest `key` in `rb_map`.

  Returns a `{key, value, new_tree}` tuple for non-empty maps, `nil` for empty maps

  ## Examples

      iex> rb_map = A.RBMap.new([b: "B", d: "D", a: "A", c: "C"])
      #A.RBMap<%{a: "A", b: "B", c: "C", d: "D"}>
      iex> {:a, "A", updated} = A.RBMap.pop_first(rb_map)
      iex> updated
      #A.RBMap<%{b: "B", c: "C", d: "D"}>
      iex> A.RBMap.new() |> A.RBMap.pop_first()
      nil

  """
  @spec pop_first(t(k, v)) :: {k, v, t(k, v)} | nil when k: key, v: value
  def pop_first(rb_map)

  def pop_first(%__MODULE__{size: size, root: root}) do
    case A.RBTree.Map.pop_min(root) do
      {key, value, new_root} ->
        new_rb_map = %__MODULE__{root: new_root, size: size - 1}
        {key, value, new_rb_map}

      :error ->
        nil
    end
  end

  @doc """
  Finds and pops the `{key, value}` pair corresponding to the largest `key` in `rb_map`.

  Returns a `{key, value, new_tree}` tuple for non-empty maps, `nil` for empty maps

  ## Examples

      iex> rb_map = A.RBMap.new([b: "B", d: "D", a: "A", c: "C"])
      #A.RBMap<%{a: "A", b: "B", c: "C", d: "D"}>
      iex> {:d, "D", updated} = A.RBMap.pop_last(rb_map)
      iex> updated
      #A.RBMap<%{a: "A", b: "B", c: "C"}>
      iex> A.RBMap.new() |> A.RBMap.pop_last()
      nil

  """
  @spec pop_last(t(k, v)) :: {k, v, t(k, v)} | nil when k: key, v: value
  def pop_last(rb_map)

  def pop_last(%__MODULE__{size: size, root: root}) do
    case A.RBTree.Map.pop_max(root) do
      {key, value, new_root} ->
        new_rb_map = %__MODULE__{root: new_root, size: size - 1}
        {key, value, new_rb_map}

      :error ->
        nil
    end
  end

  @doc """
  Folds (reduces) the given `rb_map` from the left with the function `fun`.
  Requires an accumulator `acc`.

  ## Examples

      iex> rb_map = A.RBMap.new([b: 22, a: 11, c: 33])
      iex> A.RBMap.foldl(rb_map, 0, fn _key, value, acc -> value + acc end)
      66
      iex> A.RBMap.foldl(rb_map, [], fn key, value, acc -> [{key, value * 2} | acc] end)
      [c: 66, b: 44, a: 22]

  """
  def foldl(rb_map, acc, fun)

  def foldl(%__MODULE__{root: root}, acc, fun) when is_function(fun, 3) do
    A.RBTree.Map.foldl(root, acc, fun)
  end

  @doc """
  Folds (reduces) the given `rb_map` from the right with the function `fun`.
  Requires an accumulator `acc`.

  Unlike linked lists, this is as efficient as `foldl/3`. This can typically save a call
  to `Enum.reverse/1` on the result when building a list.

  ## Examples

      iex> rb_map = A.RBMap.new([b: 22, a: 11, c: 33])
      iex> A.RBMap.foldr(rb_map, 0, fn _key, value, acc -> value + acc end)
      66
      iex> A.RBMap.foldr(rb_map, [], fn key, value, acc -> [{key, value * 2} | acc] end)
      [a: 22, b: 44, c: 66]

  """
  def foldr(rb_map, acc, fun)

  def foldr(%__MODULE__{root: root}, acc, fun) when is_function(fun, 3) do
    A.RBTree.Map.foldr(root, acc, fun)
  end

  # Iterators

  # TODO document or doc false?

  @doc false
  @spec iterator(t(k, v)) :: iterator(k, v) when k: key, v: value
  def iterator(%__MODULE__{root: root}), do: A.RBTree.Map.iterator(root)

  @doc false
  @spec next(iterator(k, v)) :: {k, v, iterator(k, v)} | nil
        when k: key, v: value
  defdelegate next(iterator), to: A.RBTree.Map

  # Private functions

  defp pop_existing(%{root: root, size: size}, key) do
    case A.RBTree.Map.pop(root, key) do
      {value, new_root} -> {value, %__MODULE__{root: new_root, size: size - 1}}
      :error -> :error
    end
  end

  # Not private, but only exposed for protocols

  @doc false
  def reduce(%__MODULE__{root: root}, acc, fun), do: A.RBTree.Map.reduce(root, acc, fun)

  defimpl Enumerable do
    def count(rb_map) do
      {:ok, A.RBMap.size(rb_map)}
    end

    def member?(rb_map, key_value) do
      with {key, value} <- key_value,
           {:ok, ^value} <- A.RBMap.fetch(rb_map, key) do
        {:ok, true}
      else
        _ -> {:ok, false}
      end
    end

    def slice(_rb_map), do: {:error, __MODULE__}

    defdelegate reduce(rb_map, acc, fun), to: A.RBMap
  end

  defimpl Collectable do
    def into(rb_map) do
      fun = fn
        map_acc, {:cont, {key, value}} ->
          A.RBMap.put(map_acc, key, value)

        map_acc, :done ->
          map_acc

        _map_acc, :halt ->
          :ok
      end

      {rb_map, fun}
    end
  end

  defimpl Inspect do
    import A.Helpers.CustomMaps, only: [implement_inspect: 3]

    implement_inspect(A.RBMap, "#A.RBMap<", ">")
  end

  if Code.ensure_loaded?(Jason.Encoder) do
    defimpl Jason.Encoder do
      def encode(map, opts) do
        map |> A.RBMap.to_list() |> Jason.Encode.keyword(opts)
      end
    end
  end
end
