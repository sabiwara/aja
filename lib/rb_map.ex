defmodule A.RBMap do
  @moduledoc false

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

  @spec size(t) :: non_neg_integer
  def size(rb_map)
  def size(%__MODULE__{size: size}), do: size

  @spec keys(t(k, value)) :: [k] when k: key
  def keys(rb_map)

  def keys(%__MODULE__{root: root}) do
    A.RBTree.Map.foldr(root, [], fn key, _value, acc -> [key | acc] end)
  end

  @spec values(t(key, v)) :: [v] when v: value
  def values(rb_map)

  def values(%__MODULE__{root: root}) do
    A.RBTree.Map.foldr(root, [], fn _key, value, acc -> [value | acc] end)
  end

  @spec to_list(t(k, v)) :: [{k, v}] when k: key, v: value
  def to_list(%__MODULE__{root: root}), do: A.RBTree.Map.to_list(root)

  @deprecated "Module A.RBMap will be removed"
  @spec new() :: t
  def new, do: %__MODULE__{}

  @deprecated "Module A.RBMap will be removed"
  @spec new(Enumerable.t()) :: t
  def new(enumerable) do
    {size, root} = A.RBTree.Map.empty() |> A.RBTree.Map.insert_many(enumerable)
    %__MODULE__{root: root, size: size}
  end

  @spec new(Enumerable.t(), (term -> {k, v})) :: t(k, v) when k: key, v: value
  def new(enumerable, transform) do
    enumerable
    |> Enum.map(transform)
    |> new()
  end

  @spec has_key?(t(k, value), k) :: boolean when k: key
  def has_key?(rb_map, key) do
    case fetch(rb_map, key) do
      {:ok, _} -> true
      :error -> false
    end
  end

  @impl Access
  @spec fetch(t(k, v), k) :: {:ok, v} | :error when k: key, v: value
  def fetch(rb_map, key)
  def fetch(%__MODULE__{root: root}, key), do: A.RBTree.Map.fetch(root, key)

  @spec fetch!(t(k, v), k) :: v when k: key, v: value
  def fetch!(%__MODULE__{} = rb_map, key) do
    case fetch(rb_map, key) do
      {:ok, value} ->
        value

      _ ->
        raise KeyError, key: key, term: rb_map
    end
  end

  @spec put_new(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def put_new(%__MODULE__{} = rb_map, key, value) do
    if has_key?(rb_map, key) do
      rb_map
    else
      put(rb_map, key, value)
    end
  end

  @spec replace(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def replace(%__MODULE__{} = rb_map, key, value) do
    if has_key?(rb_map, key) do
      put(rb_map, key, value)
    else
      rb_map
    end
  end

  @spec replace!(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def replace!(%__MODULE__{} = rb_map, key, value) do
    if has_key?(rb_map, key) do
      put(rb_map, key, value)
    else
      raise KeyError, key: key, term: rb_map
    end
  end

  @spec put_new_lazy(t(k, v), k, (() -> v)) :: t(k, v) when k: key, v: value
  def put_new_lazy(%__MODULE__{} = rb_map, key, fun) when is_function(fun, 0) do
    if has_key?(rb_map, key) do
      rb_map
    else
      put(rb_map, key, fun.())
    end
  end

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

  @spec get(t(k, v), k, v) :: v | nil when k: key, v: value
  def get(%__MODULE__{} = rb_map, key, default \\ nil) do
    case fetch(rb_map, key) do
      {:ok, value} ->
        value

      :error ->
        default
    end
  end

  @spec get_lazy(t(k, v), k, v) :: v | nil when k: key, v: value
  def get_lazy(%__MODULE__{} = rb_map, key, fun) when is_function(fun, 0) do
    case fetch(rb_map, key) do
      {:ok, value} ->
        value

      :error ->
        fun.()
    end
  end

  @spec put(t(k, v), k, v) :: v when k: key, v: value
  def put(rb_map, key, value)

  def put(%__MODULE__{root: root, size: size}, key, value) do
    {result, new_root} = A.RBTree.Map.insert(root, key, value)

    case result do
      :new -> %__MODULE__{root: new_root, size: size + 1}
      :overwrite -> %__MODULE__{root: new_root, size: size}
    end
  end

  @spec delete(t(k, v), k) :: t(k, v) when k: key, v: value
  def delete(%__MODULE__{} = rb_map, key) do
    case pop_existing(rb_map, key) do
      {_value, new_rb_map} -> new_rb_map
      :error -> rb_map
    end
  end

  @spec merge(t(k, v), t(k, v)) :: t(k, v) when k: key, v: value
  def merge(%__MODULE__{} = rb_map1, %__MODULE__{} = rb_map2) do
    # TODO optimize
    A.RBTree.Map.foldl(rb_map2.root, rb_map1, fn key, value, acc -> put(acc, key, value) end)
  end

  @spec update(t(k, v), k, v, (v -> v)) :: t(k, v) when k: key, v: value
  def update(%__MODULE__{} = rb_map, key, default, fun) when is_function(fun, 1) do
    case fetch(rb_map, key) do
      {:ok, value} ->
        put(rb_map, key, fun.(value))

      :error ->
        put(rb_map, key, default)
    end
  end

  @impl Access
  @spec pop(t(k, v), k, v) :: {v, t(k, v)} when k: key, v: value
  def pop(%__MODULE__{} = rb_map, key, default \\ nil) do
    case pop_existing(rb_map, key) do
      {value, new_rb_map} -> {value, new_rb_map}
      :error -> {default, rb_map}
    end
  end

  @spec pop!(t(k, v), k) :: {v, t(k, v)} when k: key, v: value
  def pop!(%__MODULE__{} = rb_map, key) do
    case pop_existing(rb_map, key) do
      {value, new_rb_map} -> {value, new_rb_map}
      :error -> raise KeyError, key: key, term: rb_map
    end
  end

  @spec pop_lazy(t(k, v), k, (() -> v)) :: {v, t(k, v)} when k: key, v: value
  def pop_lazy(%__MODULE__{} = rb_map, key, fun) when is_function(fun, 0) do
    case pop_existing(rb_map, key) do
      {value, new_rb_map} -> {value, new_rb_map}
      :error -> {fun.(), rb_map}
    end
  end

  @spec drop(t(k, v), [k]) :: t(k, v) when k: key, v: value
  def drop(%__MODULE__{} = rb_map, keys) when is_list(keys) do
    List.foldl(keys, rb_map, fn key, acc ->
      delete(acc, key)
    end)
  end

  @spec update!(t(k, v), k, v) :: t(k, v) when k: key, v: value
  def update!(%__MODULE__{} = rb_map, key, fun) when is_function(fun, 1) do
    case fetch(rb_map, key) do
      {:ok, value} ->
        put(rb_map, key, fun.(value))

      :error ->
        raise KeyError, key: key, term: rb_map
    end
  end

  @impl Access
  @spec get_and_update(t(k, v), k, (v -> {returned, v} | :pop)) :: {returned, t(k, v)}
        when k: key, v: value, returned: term
  def get_and_update(%__MODULE__{} = rb_map, key, fun) when is_function(fun, 1) do
    A.Helpers.CustomMaps.get_and_update(rb_map, key, fun)
  end

  @spec get_and_update!(t(k, v), k, (v -> {returned, v} | :pop)) :: {returned, t(k, v)}
        when k: key, v: value, returned: term
  def get_and_update!(%__MODULE__{} = rb_map, key, fun) when is_function(fun, 1) do
    A.Helpers.CustomMaps.get_and_update!(rb_map, key, fun)
  end

  @spec from_struct(atom | struct) :: t
  def from_struct(struct) do
    struct |> Map.from_struct() |> new()
  end

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

  @spec first(t(k, v), default) :: {k, v} | default when k: key, v: value, default: term
  def first(rb_map, default \\ nil)

  def first(%__MODULE__{root: root}, default) do
    A.RBTree.Map.min(root) || default
  end

  @spec last(t(k, v), default) :: {k, v} | default when k: key, v: value, default: term
  def last(rb_map, default \\ nil)

  def last(%__MODULE__{root: root}, default) do
    A.RBTree.Map.max(root) || default
  end

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

  def foldl(rb_map, acc, fun)

  def foldl(%__MODULE__{root: root}, acc, fun) when is_function(fun, 3) do
    A.RBTree.Map.foldl(root, acc, fun)
  end

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
