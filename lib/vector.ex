defmodule A.Vector do
  # TODO remove doc hack when stop supporting 1.10
  plusplusplus_doc = ~S"""
  ## Convenience [`+++/2`](`A.+++/2`) operator

  The `A.+++/2` operator can make appending to a vector more compact by aliasing `A.Vector.concat/2`:

      iex> import A
      iex> vec([1, 2, 3]) +++ vec([4, 5])
      vec([1, 2, 3, 4, 5])
  """

  @moduledoc ~s"""
  Fast persistent vector with efficient appends and random access.

  Persistent vectors have been introduced by Clojure as an efficient alternative to lists.
  Many operations for `A.Vector` run in effective constant time (length, random access, appends...),
  unlike linked lists for which most operations run in linear time.
  Functions that need to go through the whole collection like `map/2` or `foldl/3` are as often fast as
  their list equivalents, or sometimes even slightly faster.

  Vectors also use less memory than lists for "big" collections (see the [Memory usage section](#module-memory-usage)).

  Make sure to read the [Efficiency guide section](#module-efficiency-guide) to get the best performance
  out of vectors.

  Erlang's [`:array`](http://erlang.org/doc/man/array.html) module offer similar functionalities.
  However `A.Vector`:
  - is a better Elixir citizen: pipe-friendliness, `Access` behaviour, `Enum` / `Inspect` / `Collectable` protocols
  - is heavily optimized and should offer higher performance in most use cases, especially "loops" like `map/2` / `to_list/1` / `foldl/3`
  - mirrors most of the `Enum` module API (together with `A.Enum`) with highly optimized versions for vectors (`A.Enum.join/1`, `A.Enum.sum/1`, `A.Enum.random/1`...)
  - supports negative indexing (e.g. `-1` corresponds to the last element)
  - optionally implements the `Jason.Encoder` protocol if `Jason` is installed

  Note: most of the design is inspired by
  [this series of blog posts](https://hypirion.com/musings/understanding-persistent-vector-pt-1) describing
  the Clojure implementation, but a branching factor of `16 = 2 ^ 4` has been picked instead of `32 = 2 ^ 5`.
  This choice was made following performance benchmarking that showed better overall performance
  for this particular implementation.

  ## Examples

      iex> vector = A.Vector.new(1..10)
      vec([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
      iex> A.Vector.append(vector, :foo)
      vec([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, :foo])
      iex> vector[3]
      4
      iex> A.Vector.replace_at(vector, -1, :bar)
      vec([1, 2, 3, 4, 5, 6, 7, 8, 9, :bar])
      iex> 3 in vector
      true

  ## Access behaviour

  `A.Vector` implements the `Access` behaviour.

      iex> vector = A.Vector.new(1..10)
      iex> vector[3]
      4
      iex> put_in(vector[5], :foo)
      vec([1, 2, 3, 4, 5, :foo, 7, 8, 9, 10])
      iex> {9, updated} = pop_in(vector[8]); updated
      vec([1, 2, 3, 4, 5, 6, 7, 8, 10])

  ## Convenience [`vec/1`](`A.vec/1`) and [`vec_size/1`](`A.vec_size/1`) macros

  The `A.Vector` module can be used without any macro.

  The `A.vec/1` macro does however provide some syntactic sugar to make
  it more convenient to work with vectors of known size, namely:
  - pattern match on elements for vectors of known size
  - construct new vectors of known size faster, by generating the AST at compile time

  Examples:

      iex> import A
      iex> vec([1, 2, 3])
      vec([1, 2, 3])
      iex> vec([1, 2, var, _, _, _]) = A.Vector.new(1..6); var
      3
      iex> vec(first ||| last) = A.Vector.new(0..99_999); {first, last}
      {0, 99999}

  The `A.vec_size/1` macro can be used in guards:

      iex> import A
      iex> match?(v when vec_size(v) > 99, A.Vector.new(1..100))
      true

  #{if Version.compare(System.version(), "1.11.0") != :lt do
    plusplusplus_doc
  end}


  ## Pattern-matching and opaque type

  An `A.Vector` is represented internally using the `%A.Vector{}` struct. This struct
  can be used whenever there's a need to pattern match on something being an `A.Vector`:
      iex> match?(%A.Vector{}, A.Vector.new())
      true

  Note, however, than `A.Vector` is an [opaque type](https://hexdocs.pm/elixir/typespecs.html#user-defined-types):
  its struct internal fields must not be accessed directly.

  As discussed in the previous section, [`vec/1`](`A.vec/1`) makes it
  possible to pattern match on size and elements as well as checking the type.

  ## Memory usage

  Vectors have a small overhead over lists for smaller collections, but are using
  far less memory for bigger collections:

      iex> memory_for = fn n -> [Enum.to_list(1..n), A.Vector.new(1..n)] |> Enum.map(&:erts_debug.size/1) end
      iex> memory_for.(1)
      [2, 32]
      iex> memory_for.(10)
      [20, 32]
      iex> memory_for.(100)
      [200, 151]
      iex> memory_for.(10_000)
      [20000, 11371]

  If you need to work with vectors containing mostly the same value, `A.Vector.duplicate/2`
  is highly efficient both in time and memory (logarithmic).
  It minimizes the number of actual copies and reuses the same nested structures under the hood:

      iex> A.Vector.duplicate(0, 10_000) |> :erts_debug.size()
      117
      iex> A.Vector.duplicate(0, 10_000) |> :erts_debug.flat_size()  # when shared over processes / ETS
      11371

  Even a 1B x 1B matrix of the same element costs virtually nothing!

      big_n = 1_000_000_000
      0 |> A.Vector.duplicate(big_n) |> A.Vector.duplicate(big_n) |> :erts_debug.size()
      539


  ## Efficiency guide

  If you are using vectors and not lists, chances are that you care about
  performance. Here are a couple notes about how to use vectors in an optimal
  way. Most functions from this module are highly efficient, those that are not
  will indicate it in their documentation.

  But remember the golden rule: **in case of doubt, always benchmark**.

  ### Avoid prepending

  Appending is very efficient, but prepending is highly inefficient since the
  whole array needs to be reconstructed.

  **DON'T**

      A.Vector.prepend(vector, :foo)

  **DO**

      [:foo | list]  # use lists
      A.Vector.append(vector, :foo)

  ### Avoid deletions

  This implementation of persistent vectors has many advantages, but it does
  not support efficient deletion, with the exception of the last element that
  can be popped very efficiently (`A.Vector.pop_last/1`, `A.Vector.delete_last/1`).

  Deleting close to the end of the vector using `A.Vector.delete_at/2` or
  `A.Vector.pop_at/3` is still fairly fast, but deleting near the beginning needs
  to reconstruct most of the vector.

  If you need to be able to delete arbitrary indexes, chances are you should consider
  an alternative data structure.
  Another possibility could be to use sparse arrays, defining `nil` as a deleted value
  (but then the indexing and size won't reflect this).

  **DON'T**

      A.Vector.pop_at(vector, 3)
      A.Vector.delete_at(vector, 3)
      pop_in(vector[3])

  **DO**

      A.Vector.pop_last(vector)
      A.Vector.delete_last(vector)
      A.Vector.delete_at(vector, -3)  # close to the end
      A.Vector.replace_at(vector, 3, nil)

  ### Successive appends

  If you just need to append all elements of an enumerable, it is more efficient to use
  `A.Vector.concat/2` or its alias `A.+++/2` than successive calls to `A.Vector.append/2`:

  **DON'T**

      Enum.reduce(enumerable, vector, fn val, acc -> A.Vector.append(acc, val) end)

  **DO**

      A.Vector.concat(vector, enumerable)
      #{if Version.compare(System.version(), "1.11.0") != :lt do
    "vector +++ enumerable"
  end}

  ### Prefer `A.Enum` and `A.Vector` to `Enum` for vectors

  The `A.Enum` module reimplements (nearly) all functions from the `Enum` module to offer
  optimal performance when operating on vectors, and should be used over `Enum` functions whenever possible
  (even if `A.Vector` implements the `Enumerable` and `Collectable` protocols for convienience):

  **DON'T**

      Enum.sum(vector)
      Enum.to_list(vector)
      Enum.reduce(vector, [], fun)
      Enum.into(enumerable, %A.Vector.new())
      Enum.into(enumerable, vector)

  **DO**

      A.Enum.sum(vector)
      A.Enum.to_list(vector)  # or A.Vector.to_list(vector)
      A.Enum.reduce(vector, [], fun)  # or A.Vector.foldl(vector, [], fun)
      A.Vector.new(enumerable)
      A.Enum.into(enumerable, vector)
      # or A.Vector.concat(vector, enumerable)
      # or vector +++ enumerable

  Although it depends on the function, you can expect a ~10x speed difference.

  `for` comprehensions are actually using `Enumerable` as well, so
  the same advice holds:

  **DON'T**

      for value <- vector do
        do_stuff()
      end

  If using it in EEx templates, you might want to cast it to a list:

      for value <- A.Vector.to_list(vector) do
        do_stuff()
      end

  ### Exceptions: `Enum` optimized functions

  `Enum.member?/2` is implemented in an efficient way, so `in/2` is optimal:

  **DO**

      33 in vector

  ### Slicing optimization

  Slicing any subset on the left on the vector using methods from `A.Vector` is
  extremely efficient as the vector internals can be reused:

  **DO**

      A.Vector.take(vector, 10)  # take a positive amount
      A.Vector.drop(vector, -20)  # drop a negative amount
      A.Vector.slice(vector, 0, 10)  # slicing from 0
      A.Vector.slice(vector, 0..-5)  # slicing from 0

  ### `A.Vector` and `A.Enum`

  - `A.Enum` mirrors `Enum` and should return identical results, therefore many functions would return lists
  - `A.Vector` mirrors `Enum` functions that are returning lists, but returns vectors instead

      iex> vector = A.Vector.new(1..10)
      iex> A.Enum.reverse(vector)
      [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
      iex> A.Vector.reverse(vector)
      vec([10, 9, 8, 7, 6, 5, 4, 3, 2, 1])
      iex> A.Enum.map(vector, & (&1 * 7))
      [7, 14, 21, 28, 35, 42, 49, 56, 63, 70]
      iex> A.Vector.map(vector, & (&1 * 7))
      vec([7, 14, 21, 28, 35, 42, 49, 56, 63, 70])

  ### Additional notes

  * If you need to work with vectors containing mostly the same value,
    use `A.Vector.duplicate/2` (more details in the [Memory usage section](#module-memory-usage)).

  * If you work with functions returning vectors of known size, you can use
    the `A.vec/1` macro to defer the generation of the AST for the internal
    structure to compile time instead of runtime.

        A.Vector.new([%{foo: a}, %{foo: b}])  # structure created at runtime
        vec([%{foo: a}, %{foo: b}])  # structure AST defined at compile time

  """

  alias A.Vector.{EmptyError, IndexError, Raw}
  require Raw

  @behaviour Access

  @type index :: integer
  @type value :: term

  @opaque t(value) :: %__MODULE__{__vector__: Raw.t(value)}
  @enforce_keys [:__vector__]
  defstruct [:__vector__]

  @type t :: t(value)

  @empty_raw Raw.empty()

  defmacrop from_internal(internal) do
    quote do
      %__MODULE__{__vector__: unquote(internal)}
    end
  end

  @doc """
  Returns the number of elements in `vector`.

  Runs in constant time.

  ## Examples

      iex> A.Vector.new(10_000..20_000) |> A.Vector.size()
      10001
      iex> A.Vector.new() |> A.Vector.size()
      0

  """
  @compile {:inline, size: 1}
  @spec size(t()) :: non_neg_integer
  def size(%__MODULE__{__vector__: internal}) do
    Raw.size(internal)
  end

  @doc """
  Returns a new empty vector.

  ## Examples

      iex> A.Vector.new()
      vec([])

  """
  @compile {:inline, new: 0}
  @spec new :: t()
  def new() do
    from_internal(@empty_raw)
  end

  @doc """
  Creates a vector from an `enumerable`.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(10..25)
      vec([10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25])

  """
  @spec new(Enumerable.t()) :: t()
  def new(%__MODULE__{} = vector) do
    vector
  end

  def new(enumerable) do
    case A.EnumHelper.to_raw_vec_or_list(enumerable) do
      list when is_list(list) -> from_list(list)
      raw -> from_internal(raw)
    end
  end

  @doc """
  Creates a vector from an `enumerable` via the given `transform` function.

  ## Examples

      iex> A.Vector.new(1..10, &(&1 * &1))
      vec([1, 4, 9, 16, 25, 36, 49, 64, 81, 100])

  """
  @spec new(Enumerable.t(), (v1 -> v2)) :: t(v2) when v1: value, v2: value
  def new(enumerable, fun) when is_function(fun, 1) do
    case A.EnumHelper.to_raw_vec_or_list(enumerable) do
      list when is_list(list) -> Raw.from_mapped_list(list, fun) |> from_internal()
      raw -> Raw.map(raw, fun) |> from_internal()
    end
  end

  @doc """
  Duplicates the given element `n` times in a vector.

  `n` is an integer greater than or equal to `0`.
  If `n` is `0`, an empty list is returned.

  Runs in logarithmic time regarding `n`. It is very fast and memory efficient
  (see [Memory usage](#module-memory-usage)).

  ## Examples

      iex> A.Vector.duplicate(nil, 10)
      vec([nil, nil, nil, nil, nil, nil, nil, nil, nil, nil])
      iex> A.Vector.duplicate(:foo, 0)
      vec([])

  """
  @spec duplicate(val, non_neg_integer) :: t(val) when val: value
  def duplicate(value, n) when is_integer(n) and n >= 0 do
    Raw.duplicate(value, n) |> from_internal()
  end

  @doc """
  Populates a vector of size `n` by calling `generator_fun` repeatedly.

  ## Examples

      # Although not necessary, let's seed the random algorithm
      iex> :rand.seed(:exrop, {1, 2, 3})
      iex> A.Vector.repeat(&:rand.uniform/0, 3)
      vec([0.7498295129076106, 0.06161655489244533, 0.7924073127680873])

  """
  def repeat(generator_fun, n)
      when is_function(generator_fun, 0) and is_integer(n) and n >= 0 do
    A.List.repeat(generator_fun, n) |> from_list()
  end

  @doc false
  @deprecated "Use A.Vector.repeat/2 instead"
  defdelegate repeatedly(vector, enumerable), to: __MODULE__, as: :repeat

  @doc """
  Appends a `value` at the end of a `vector`.

  Runs in effective constant time.

  ## Examples

      iex> A.Vector.new() |> A.Vector.append(:foo)
      vec([:foo])
      iex> A.Vector.new(1..5) |> A.Vector.append(:foo)
      vec([1, 2, 3, 4, 5, :foo])

  """
  @spec append(t(val), val) :: t(val) when val: value
  def append(%__MODULE__{__vector__: internal}, value) do
    Raw.append(internal, value) |> from_internal()
  end

  @doc """
  Appends all values from an `enumerable` at the end of a `vector`.

  Runs in effective linear time in respect with the length of `enumerable`,
  disregarding the size of the `vector`.

  ## Examples

      iex> A.Vector.new(1..5) |> A.Vector.concat(10..15)
      vec([1, 2, 3, 4, 5, 10, 11, 12, 13, 14, 15])
      iex> A.Vector.new() |> A.Vector.concat(10..15)
      vec([10, 11, 12, 13, 14, 15])

  """
  @spec concat(t(val), Enumerable.t()) :: t(val) when val: value
  def concat(%__MODULE__{__vector__: internal}, enumerable) do
    case A.EnumHelper.to_raw_vec_or_list(enumerable) do
      list when is_list(list) -> Raw.concat_list(internal, list)
      vector when is_tuple(vector) -> Raw.concat_vector(internal, vector)
    end
    |> from_internal()
  end

  @doc false
  @deprecated "Use A.Vector.concat/2 instead"
  defdelegate append_many(vector, enumerable), to: __MODULE__, as: :concat

  @doc """
  (Inefficient) Prepends `value` at the beginning of the `vector`.

  Runs in linear time because the whole vector needs to be reconstructuded,
  and should be avoided.

  ## Examples

      iex> A.Vector.new() |> A.Vector.prepend(:foo)
      vec([:foo])
      iex> A.Vector.new(1..5) |> A.Vector.prepend(:foo)
      vec([:foo, 1, 2, 3, 4, 5])

  """
  @spec prepend(t(val), val) :: t(val) when val: value
  def prepend(%__MODULE__{__vector__: internal}, value) do
    Raw.prepend(internal, value) |> from_internal()
  end

  @doc """
  Returns the first element in the `vector` or `default` if `vector` is empty.

  Runs in actual constant time.

  ## Examples

      iex> A.Vector.new(1..10_000) |> A.Vector.first()
      1
      iex> A.Vector.new() |> A.Vector.first()
      nil

  """
  @spec first(t(val), default) :: val | default when val: value, default: term
  def first(vector, default \\ nil)

  def first(%__MODULE__{__vector__: internal}, default) do
    case internal do
      Raw.first_pattern(first) -> first
      _ -> default
    end
  end

  @doc """
  Returns the last element in the `vector` or `default` if `vector` is empty.

  Runs in constant time (actual, not effective).

  ## Examples

      iex> A.Vector.new(1..10_000) |> A.Vector.last()
      10_000
      iex> A.Vector.new() |> A.Vector.last()
      nil

  """
  @spec last(t(val), default) :: val | default when val: value, default: term
  def last(vector, default \\ nil)

  def last(%__MODULE__{__vector__: internal}, default) do
    case internal do
      Raw.last_pattern(last) -> last
      _ -> default
    end
  end

  @doc """
  Finds the element at the given `index` (zero-based), and returns it in a ok-entry.
  If the `index` does not exist, returns `:error`.

  Supports negative indexing from the end of the `vector`.

  Runs in effective constant time.

  ## Examples

      iex> A.Vector.new(1..1_000) |> A.Vector.fetch(555)
      {:ok, 556}
      iex> A.Vector.new(1..1_000) |> A.Vector.fetch(1_000)
      :error
      iex> A.Vector.new(1..1_000) |> A.Vector.fetch(-1)
      {:ok, 1000}

  """
  @impl Access
  @spec fetch(t(val), index) :: {:ok, val} | :error when val: value
  def fetch(vector, index)

  def fetch(%__MODULE__{__vector__: internal}, index) when is_integer(index) do
    size = Raw.size(internal)

    case Raw.actual_index(index, size) do
      nil ->
        :error

      actual_index ->
        found = Raw.fetch_positive!(internal, actual_index)
        {:ok, found}
    end
  end

  defdelegate fetch!(vector, index), to: __MODULE__, as: :at!

  @doc """
  Finds the element at the given `index` (zero-based).

  Returns `default` if `index` is out of bounds.
  Supports negative indexing from the end of the `vector`.

  Runs in effective constant time.

  ## Examples

      iex> A.Vector.new(1..1_000) |> A.Vector.at(555)
      556
      iex> A.Vector.new(1..1_000) |> A.Vector.at(1_000)
      nil

  """
  @spec at(t(val), index) :: val | nil when val: value
  def at(%__MODULE__{__vector__: internal}, index) when is_integer(index) do
    size = Raw.size(internal)

    case Raw.actual_index(index, size) do
      nil -> nil
      actual_index -> Raw.fetch_positive!(internal, actual_index)
    end
  end

  @spec at(t(val), index, default) :: val | default when val: value, default: term
  def at(%__MODULE__{__vector__: internal}, index, default) when is_integer(index) do
    size = Raw.size(internal)

    case Raw.actual_index(index, size) do
      nil -> default
      actual_index -> Raw.fetch_positive!(internal, actual_index)
    end
  end

  @doc """
  Finds the element at the given `index` (zero-based).

  Raises an `A.Vector.IndexError` if `index` is out of bounds.
  Supports negative indexing from the end of the `vector`.

  Runs in effective constant time.

  ## Examples

      iex> A.Vector.new(1..1_000) |> A.Vector.at!(555)
      556
      iex> A.Vector.new(1..1_000) |> A.Vector.at!(-10)
      991
      iex> A.Vector.new(1..1_000) |> A.Vector.at!(1_000)
      ** (A.Vector.IndexError) out of bound index: 1000 not in -1000..999

  """
  @spec at!(t(val), index) :: val when val: value
  def at!(%__MODULE__{__vector__: internal}, index) when is_integer(index) do
    size = Raw.size(internal)

    case Raw.actual_index(index, size) do
      nil -> raise IndexError, index: index, size: size
      actual_index -> Raw.fetch_positive!(internal, actual_index)
    end
  end

  @doc """
  Returns a copy of `vector` with a replaced `value` at the specified `index`.

  Returns the `vector` untouched if `index` is out of bounds.
  Supports negative indexing from the end of the `vector`.

  Runs in effective constant time.

  ## Examples

      iex> A.Vector.new(1..8) |> A.Vector.replace_at(5, :foo)
      vec([1, 2, 3, 4, 5, :foo, 7, 8])
      iex> A.Vector.new(1..8) |> A.Vector.replace_at(8, :foo)
      vec([1, 2, 3, 4, 5, 6, 7, 8])
      iex> A.Vector.new(1..8) |> A.Vector.replace_at(-2, :foo)
      vec([1, 2, 3, 4, 5, 6, :foo, 8])

  """
  @spec replace_at(t(val), index, val) :: t(val) when val: value
  def replace_at(%__MODULE__{__vector__: internal} = vector, index, value)
      when is_integer(index) do
    size = Raw.size(internal)

    case Raw.actual_index(index, size) do
      nil ->
        vector

      actual_index ->
        Raw.replace_positive!(internal, actual_index, value) |> from_internal()
    end
  end

  @doc """
  Returns a copy of `vector` with a replaced `value` at the specified `index`.

  Raises an `A.Vector.IndexError` if `index` is out of bounds.
  Supports negative indexing from the end of the `vector`.

  Runs in effective constant time.

  ## Examples

      iex> A.Vector.new(1..8) |> A.Vector.replace_at!(5, :foo)
      vec([1, 2, 3, 4, 5, :foo, 7, 8])
      iex> A.Vector.new(1..8) |> A.Vector.replace_at!(-2, :foo)
      vec([1, 2, 3, 4, 5, 6, :foo, 8])
      iex> A.Vector.new(1..8) |> A.Vector.replace_at!(8, :foo)
      ** (A.Vector.IndexError) out of bound index: 8 not in -8..7

  """
  @spec replace_at!(t(val), index, val) :: t(val) when val: value
  def replace_at!(%__MODULE__{__vector__: internal}, index, value)
      when is_integer(index) do
    size = Raw.size(internal)

    case Raw.actual_index(index, size) do
      nil ->
        raise IndexError, index: index, size: size

      actual_index ->
        Raw.replace_positive!(internal, actual_index, value) |> from_internal()
    end
  end

  @doc """
  Returns a copy of `vector` with an updated value at the specified `index`.

  Returns the `vector` untouched if `index` is out of bounds.
  Supports negative indexing from the end of the `vector`.

  Runs in effective constant time.

  ## Examples

      iex> A.Vector.new(1..8) |> A.Vector.update_at(2, &(&1 * 1000))
      vec([1, 2, 3000, 4, 5, 6, 7, 8])
      iex> A.Vector.new(1..8) |> A.Vector.update_at(8, &(&1 * 1000))
      vec([1, 2, 3, 4, 5, 6, 7, 8])
      iex> A.Vector.new(1..8) |> A.Vector.update_at(-1, &(&1 * 1000))
      vec([1, 2, 3, 4, 5, 6, 7, 8000])

  """
  @spec update_at(t(val), index, (val -> val)) :: t(val) when val: value
  def update_at(%__MODULE__{__vector__: internal} = vector, index, fun)
      when is_integer(index) and is_function(fun) do
    size = Raw.size(internal)

    case Raw.actual_index(index, size) do
      nil ->
        vector

      actual_index ->
        Raw.update_positive!(internal, actual_index, fun) |> from_internal()
    end
  end

  @doc """
  Returns a copy of `vector` with an updated value at the specified `index`.

  Raises an `A.Vector.IndexError` if `index` is out of bounds.
  Supports negative indexing from the end of the `vector`.

  Runs in effective constant time.

  ## Examples

      iex> A.Vector.new(1..8) |> A.Vector.update_at!(2, &(&1 * 1000))
      vec([1, 2, 3000, 4, 5, 6, 7, 8])
      iex> A.Vector.new(1..8) |> A.Vector.update_at!(-1, &(&1 * 1000))
      vec([1, 2, 3, 4, 5, 6, 7, 8000])
      iex> A.Vector.new(1..8) |> A.Vector.update_at!(-9, &(&1 * 1000))
      ** (A.Vector.IndexError) out of bound index: -9 not in -8..7

  """
  @spec update_at!(t(val), index, (val -> val)) :: t(val) when val: value
  def update_at!(%__MODULE__{__vector__: internal}, index, fun)
      when is_integer(index) and is_function(fun) do
    size = Raw.size(internal)

    case Raw.actual_index(index, size) do
      nil ->
        raise IndexError, index: index, size: size

      actual_index ->
        Raw.update_positive!(internal, actual_index, fun) |> from_internal()
    end
  end

  @doc """
  Removes the last value from the `vector` and returns both the value and the updated vector.

  Leaves the `vector` untouched if empty.

  Runs in effective constant time.

  ## Examples

      iex> vector = A.Vector.new(1..8)
      iex> {8, updated} = A.Vector.pop_last(vector); updated
      vec([1, 2, 3, 4, 5, 6, 7])
      iex> {nil, updated} = A.Vector.pop_last(A.Vector.new()); updated
      vec([])

  """
  @spec pop_last(t(val), default) :: {val | default, t(val)} when val: value, default: term
  def pop_last(vector, default \\ nil)

  def pop_last(%__MODULE__{__vector__: internal} = vector, default) do
    case Raw.pop_last(internal) do
      {value, new_internal} -> {value, from_internal(new_internal)}
      :error -> {default, vector}
    end
  end

  @doc """
  Removes the last value from the `vector` and returns both the value and the updated vector.

  Raises an `A.Vector.EmptyError` if empty.

  Runs in effective constant time.

  ## Examples

      iex> vector = A.Vector.new(1..8)
      iex> {8, updated} = A.Vector.pop_last!(vector); updated
      vec([1, 2, 3, 4, 5, 6, 7])
      iex> {nil, updated} = A.Vector.pop_last!(A.Vector.new()); updated
      ** (A.Vector.EmptyError) empty vector error

  """
  @spec pop_last!(t(val)) :: {val, t(val)} when val: value
  def pop_last!(vector)

  def pop_last!(%__MODULE__{__vector__: internal}) do
    case Raw.pop_last(internal) do
      {value, new_internal} -> {value, from_internal(new_internal)}
      :error -> raise EmptyError
    end
  end

  @doc """
  Removes the last value from the `vector` and returns the updated vector.

  Leaves the `vector` untouched if empty.

  Runs in effective constant time.

  ## Examples

      iex> vector = A.Vector.new(1..8)
      iex> A.Vector.delete_last(vector)
      vec([1, 2, 3, 4, 5, 6, 7])
      iex> A.Vector.delete_last(A.Vector.new())
      vec([])

  """
  @spec delete_last(t(val)) :: t(val) when val: value
  def delete_last(vector)

  def delete_last(%__MODULE__{__vector__: internal} = vector) do
    case Raw.pop_last(internal) do
      {_value, new_internal} -> from_internal(new_internal)
      :error -> vector
    end
  end

  @doc """
  Removes the last value from the `vector` and returns the updated vector.

  Raises an `A.Vector.EmptyError` if empty.

  Runs in effective constant time.

  ## Examples

      iex> vector = A.Vector.new(1..8)
      iex> A.Vector.delete_last!(vector)
      vec([1, 2, 3, 4, 5, 6, 7])
      iex> A.Vector.delete_last!(A.Vector.new())
      ** (A.Vector.EmptyError) empty vector error

  """
  @spec delete_last!(t(val)) :: t(val) when val: value
  def delete_last!(vector)

  def delete_last!(%__MODULE__{__vector__: internal}) do
    case Raw.pop_last(internal) do
      {_value, new_internal} -> from_internal(new_internal)
      :error -> raise EmptyError
    end
  end

  @doc """
  (Inefficient) Returns and removes the value at the specified `index` in the `vector`.

  Returns the `vector` untouched if `index` is out of bounds.
  Supports negative indexing from the end of the `vector`.

  Runs in linear time. Its usage is discouraged, see the
  [Efficiency guide](#module-efficiency-guide).

  ## Examples

      iex> vector = A.Vector.new(1..8)
      iex> {5, updated} = A.Vector.pop_at(vector, 4); updated
      vec([1, 2, 3, 4, 6, 7, 8])
      iex> {nil, updated} = A.Vector.pop_at(vector, -9); updated
      vec([1, 2, 3, 4, 5, 6, 7, 8])

  """
  @spec pop_at(t(val), index, default) :: {val | default, t(val)} when val: value, default: term
  def pop_at(vector, index, default \\ nil)

  def pop_at(%__MODULE__{__vector__: internal} = vector, index, default) when is_integer(index) do
    size = Raw.size(internal)

    case Raw.actual_index(index, size) do
      nil ->
        {default, vector}

      actual_index ->
        {value, new_internal} = Raw.pop_positive!(internal, actual_index, size)
        {value, from_internal(new_internal)}
    end
  end

  @doc """
  (Inefficient) Returns and removes the value at the specified `index` in the `vector`.

  Raises an `A.Vector.IndexError` if `index` is out of bounds.
  Supports negative indexing from the end of the `vector`.

  Runs in linear time. Its usage is discouraged, see the
  [Efficiency guide](#module-efficiency-guide).

  ## Examples

      iex> vector = A.Vector.new(1..8)
      iex> {5, updated} = A.Vector.pop_at!(vector, 4); updated
      vec([1, 2, 3, 4, 6, 7, 8])
      iex> A.Vector.pop_at!(vector, -9)
      ** (A.Vector.IndexError) out of bound index: -9 not in -8..7

  """
  @spec pop_at!(t(val), index) :: {val, t(val)} when val: value
  def pop_at!(vector, index)

  def pop_at!(%__MODULE__{__vector__: internal}, index) when is_integer(index) do
    size = Raw.size(internal)

    case Raw.actual_index(index, size) do
      nil ->
        raise IndexError, index: index, size: size

      actual_index ->
        {value, new_internal} = Raw.pop_positive!(internal, actual_index, size)
        {value, from_internal(new_internal)}
    end
  end

  @doc false
  @impl Access
  @spec pop(t(val), index) :: {val | nil, t(val)} when val: value
  defdelegate pop(vector, key), to: __MODULE__, as: :pop_at

  @doc """
  (Inefficient) Returns a copy of `vector` without the value at the specified `index`.

  Returns the `vector` untouched if `index` is out of bounds.
  Supports negative indexing from the end of the `vector`.

  Runs in linear time. Its usage is discouraged, see the
  [Efficiency guide](#module-efficiency-guide).

  ## Examples

      iex> vector = A.Vector.new(1..8)
      iex> A.Vector.delete_at(vector, 4)
      vec([1, 2, 3, 4, 6, 7, 8])
      iex> A.Vector.delete_at(vector, -9)
      vec([1, 2, 3, 4, 5, 6, 7, 8])

  """
  @spec delete_at(t(val), index) :: t(val) when val: value
  def delete_at(%__MODULE__{__vector__: internal} = vector, index) when is_integer(index) do
    size = Raw.size(internal)

    case Raw.actual_index(index, size) do
      nil ->
        vector

      actual_index ->
        Raw.delete_positive!(internal, actual_index, size) |> from_internal()
    end
  end

  @doc """
  (Inefficient) Returns a copy of `vector` without the value at the specified `index`.

  Raises an `A.Vector.IndexError` if `index` is out of bounds.
  Supports negative indexing from the end of the `vector`.

  Runs in linear time. Its usage is discouraged, see the
  [Efficiency guide](#module-efficiency-guide).

  ## Examples

      iex> vector = A.Vector.new(1..8)
      iex> A.Vector.delete_at!(vector, 4)
      vec([1, 2, 3, 4, 6, 7, 8])
      iex> A.Vector.delete_at!(vector, -9)
      ** (A.Vector.IndexError) out of bound index: -9 not in -8..7

  """
  @spec delete_at!(t(val), index) :: t(val) when val: value
  def delete_at!(vector, index)

  def delete_at!(%__MODULE__{__vector__: internal}, index) when is_integer(index) do
    size = Raw.size(internal)

    case Raw.actual_index(index, size) do
      nil ->
        raise IndexError, index: index, size: size

      actual_index ->
        Raw.delete_positive!(internal, actual_index, size) |> from_internal()
    end
  end

  @doc """
  Gets the value from key and updates it, all in one pass.

  See `Access.get_and_update/3` for more details.

  ## Examples

      iex> vector = A.Vector.new(1..8)
      iex> {6, updated} = A.Vector.get_and_update(vector, 5, fn current_value ->
      ...>   {current_value, current_value && current_value * 100}
      ...> end); updated
      vec([1, 2, 3, 4, 5, 600, 7, 8])
      iex> {nil, updated} = A.Vector.get_and_update(vector, 8, fn current_value ->
      ...>   {current_value, current_value && current_value * 100}
      ...> end); updated
      vec([1, 2, 3, 4, 5, 6, 7, 8])
      iex> {4, updated} = A.Vector.get_and_update(vector, 3, fn _ -> :pop end); updated
      vec([1, 2, 3, 5, 6, 7, 8])
      iex> {nil, updated} = A.Vector.get_and_update(vector, 8, fn _ -> :pop end); updated
      vec([1, 2, 3, 4, 5, 6, 7, 8])

  """
  @impl Access
  @spec get_and_update(t(v), index, (v -> {returned, v} | :pop)) :: {returned, t(v)}
        when v: value, returned: term
  def get_and_update(%__MODULE__{__vector__: internal}, index, fun)
      when is_integer(index) and is_function(fun, 1) do
    {returned, new_internal} = Raw.get_and_update(internal, index, fun)
    {returned, from_internal(new_internal)}
  end

  @doc """
  Converts the `vector` to a list.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(10..25) |> A.Vector.to_list()
      [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25]
      iex> A.Vector.new() |> A.Vector.to_list()
      []

  """
  @spec to_list(t(val)) :: [val] when val: value
  def to_list(%__MODULE__{__vector__: internal}) do
    Raw.to_list(internal)
  end

  @doc """
  Returns a new vector where each element is the result of invoking `fun`
  on each corresponding element of `vector`.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(1..10) |> A.Vector.map(&(&1 * &1))
      vec([1, 4, 9, 16, 25, 36, 49, 64, 81, 100])

  """
  @spec map(t(v1), (v1 -> v2)) :: t(v2) when v1: value, v2: value
  def map(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 1) do
    Raw.map(internal, fun) |> from_internal()
  end

  @doc """
  Filters the `vector`, i.e. return a new vector containing only elements
  for which `fun` returns a truthy (neither `false` nor `nil`) value.

  Runs in linear time.

  ## Examples

      iex> vector = A.Vector.new(1..100)
      iex> A.Vector.filter(vector, fn i -> rem(i, 13) == 0 end)
      vec([13, 26, 39, 52, 65, 78, 91])

  """
  @spec filter(t(val), (val -> as_boolean(term))) :: t(val) when val: value
  def filter(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 1) do
    Raw.filter_to_list(internal, fun) |> from_list()
  end

  @doc """
  Filters the `vector`, i.e. return a new vector containing only elements
  for which `fun` returns a falsy (either `false` or `nil`) value.

  Runs in linear time.

  ## Examples

      iex> vector = A.Vector.new(1..12)
      iex> A.Vector.reject(vector, fn i -> rem(i, 3) == 0 end)
      vec([1, 2, 4, 5, 7, 8, 10, 11])

  """
  @spec reject(t(val), (val -> as_boolean(term))) :: t(val) when val: value
  def reject(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 1) do
    Raw.reject_to_list(internal, fun) |> from_list()
  end

  @doc """
  Splits the `vector` in two vectors according to the given function `fun`.

  Returns a tuple with the first vector containing all the elements in `vector`
  for which applying `fun` returned a truthy value, and a second vector with all
  the elements for which applying `fun` returned a falsy value (`false` or `nil`).

  Returns the same result as `filter/2` and `reject/2` at once, but only walks the
  `vector` once and calls `fun` exactly once per element.

  Runs in linear time.

  ## Examples

      iex> vector = A.Vector.new(1..12)
      iex> {filtered, rejected} = A.Vector.split_with(vector, fn i -> rem(i, 3) == 0 end)
      iex> filtered
      vec([3, 6, 9, 12])
      iex> rejected
      vec([1, 2, 4, 5, 7, 8, 10, 11])

  """
  @spec split_with(t(val), (val -> as_boolean(term))) :: {t(val), t(val)} when val: value
  def split_with(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 1) do
    # note: unlike filter/2, optimization does not bring much benefit
    {filtered, rejected} = internal |> Raw.to_list() |> Enum.split_with(fun)

    {from_list(filtered), from_list(rejected)}
  end

  @doc """
  Sorts the `vector` in the same way as `Enum.sort/1`.

  ## Examples

      iex> A.Vector.new(9..1) |> A.Vector.sort()
      vec([1, 2, 3, 4, 5, 6, 7, 8, 9])

  """
  @spec sort(t(val)) :: t(val) when val: value
  def sort(%__MODULE__{__vector__: internal}) do
    internal
    |> Raw.to_list()
    |> Enum.sort()
    |> from_list()
  end

  @doc """
  Sorts the `vector` in the same way as `Enum.sort/2`.

  See `Enum.sort/2` documentation for detailled usage.

  ## Examples

      iex> A.Vector.new(1..9) |> A.Vector.sort(:desc)
      vec([9, 8, 7, 6, 5, 4, 3, 2, 1])

  """
  @spec sort(
          t(val),
          (val, val -> boolean)
          | :asc
          | :desc
          | module
          | {:asc | :desc, module}
        ) :: t(val)
        when val: value
  def sort(%__MODULE__{__vector__: internal}, fun) do
    internal
    |> Raw.to_list()
    |> Enum.sort(fun)
    |> from_list()
  end

  @doc """
  Sorts the `vector` in the same way as `Enum.sort_by/3`.

  See `Enum.sort_by/3` documentation for detailled usage.

  ## Examples

      iex> vector = A.Vector.new(["some", "kind", "of", "monster"])
      iex> A.Vector.sort_by(vector, &byte_size/1)
      vec(["of", "some", "kind", "monster"])
      iex> A.Vector.sort_by(vector, &{byte_size(&1), String.first(&1)})
      vec(["of", "kind", "some", "monster"])

  """
  @spec sort_by(
          t(val),
          (val -> mapped_val),
          (val, val -> boolean)
          | :asc
          | :desc
          | module
          | {:asc | :desc, module}
        ) :: t(val)
        when val: value, mapped_val: value
  def sort_by(%__MODULE__{__vector__: internal}, mapper, sorter \\ &<=/2) do
    internal
    |> Raw.to_list()
    |> Enum.sort_by(mapper, sorter)
    |> from_list()
  end

  @doc """
  Returns a copy of the vector without any duplicated element.

  The first occurrence of each element is kept.

  ## Examples

      iex> A.Vector.new([1, 1, 2, 1, 2, 3, 2]) |> A.Vector.uniq()
      vec([1, 2, 3])

  """
  @spec uniq(t(val)) :: t(val) when val: value
  def uniq(%__MODULE__{__vector__: internal}) do
    internal
    |> Raw.uniq_list()
    |> from_list()
  end

  @doc """
  Returns a copy of the vector without elements for which the function `fun` returned duplicate elements.

  The first occurrence of each element is kept.

  ## Examples

      iex> vector = A.Vector.new([x: 1, y: 2, z: 1])
      vec([x: 1, y: 2, z: 1])
      iex> A.Vector.uniq_by(vector, fn {_x, y} -> y end)
      vec([x: 1, y: 2])

  """
  @spec uniq_by(t(val), (val -> term)) :: t(val) when val: value
  def uniq_by(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 1) do
    internal
    |> Raw.uniq_by_list(fun)
    |> from_list()
  end

  @doc """
  Returns a copy of the `vector` where all consecutive duplicated elements are collapsed to a single element.

  Elements are compared using `===/2`.

  If you want to remove all duplicated elements, regardless of order, see `uniq/1`.

  ## Examples

      iex> A.Vector.new([1, 2, 3, 3, 2, 1]) |> A.Vector.dedup()
      vec([1, 2, 3, 2, 1])
      iex> A.Vector.new([1, 1, 2, 2.0, :three, :three]) |> A.Vector.dedup()
      vec([1, 2, 2.0, :three])

  """
  @spec dedup(t(val)) :: t(val) when val: value
  def dedup(%__MODULE__{__vector__: internal}) do
    internal
    |> Raw.dedup_list()
    |> from_list()
  end

  @doc """
  Returns a copy of the `vector` where all consecutive duplicated elements are collapsed to a single element.

  The function `fun` maps every element to a term which is used to determine if two elements are duplicates.

  ## Examples

      iex> vector = A.Vector.new([{1, :a}, {2, :b}, {2, :c}, {1, :a}])
      iex> A.Vector.dedup_by(vector, fn {x, _} -> x end)
      vec([{1, :a}, {2, :b}, {1, :a}])

      iex> vector = A.Vector.new([5, 1, 2, 3, 2, 1])
      iex> A.Vector.dedup_by(vector, fn x -> x > 2 end)
      vec([5, 1, 3, 2])


  """
  @spec dedup_by(t(val), (val -> term)) :: t(val) when val: value
  def dedup_by(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 1) do
    internal
    |> Raw.to_list()
    |> Enum.dedup_by(fun)
    |> from_list()
  end

  @doc """
  Intersperses `separator` between each element of the `vector`.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(1..6) |> A.Vector.intersperse(nil)
      vec([1, nil, 2, nil, 3, nil, 4, nil, 5, nil, 6])

  """
  @spec intersperse(
          t(val),
          separator
        ) :: t(val | separator)
        when val: value, separator: value
  def intersperse(%__MODULE__{__vector__: internal}, separator) do
    internal
    |> Raw.intersperse_to_list(separator)
    |> from_list()
  end

  @doc """
  Maps and intersperses the `vector` in one pass.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(1..6) |> A.Vector.map_intersperse(nil, &(&1 * 10))
      vec([10, nil, 20, nil, 30, nil, 40, nil, 50, nil, 60])

  """
  @spec map_intersperse(
          t(val),
          separator,
          (val -> mapped_val)
        ) :: t(mapped_val | separator)
        when val: value, separator: value, mapped_val: value
  def map_intersperse(%__MODULE__{__vector__: internal}, separator, mapper)
      when is_function(mapper, 1) do
    internal
    |> Raw.map_intersperse_to_list(separator, mapper)
    |> from_list()
  end

  @doc """
  Maps the given `fun` over `vector` and flattens the result.

  This function returns a new vector built by concatenating the results
  of invoking `fun` on each element of `vector` together.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(0..4) |> A.Vector.flat_map(fn i -> List.duplicate(i, i) end)
      vec([1, 2, 2, 3, 3, 3, 4, 4, 4, 4])

  """
  @spec flat_map(t(val), (val -> t(mapped_val))) :: t(mapped_val)
        when val: value, mapped_val: value
  def flat_map(%__MODULE__{} = vector, fun) when is_function(fun, 1) do
    vector
    |> A.EnumHelper.flat_map(fun)
    |> from_list()
  end

  @doc """
  Folds (reduces) the given `vector` from the left with the function `fun`.
  Requires an accumulator `acc`.

  Same as `reduce/3`.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(1..10) |> A.Vector.foldl(0, &+/2)
      55
      iex> A.Vector.new(1..10) |> A.Vector.foldl([], & [&1 | &2])
      [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]

  """
  @spec foldl(t(val), acc, (val, acc -> acc)) :: acc when val: value, acc: term
  def foldl(%__MODULE__{__vector__: internal}, acc, fun) when is_function(fun, 2) do
    Raw.foldl(internal, acc, fun)
  end

  @doc """
  Folds (reduces) the given `vector` from the right with the function `fun`.
  Requires an accumulator `acc`.

  Unlike linked lists, this is as efficient as `foldl/3`. This can typically save a call
  to `Enum.reverse/1` on the result when building a list.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(1..10) |> A.Vector.foldr(0, &+/2)
      55
      iex> A.Vector.new(1..10) |> A.Vector.foldr([], & [&1 | &2])
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

  """
  @spec foldr(t(val), acc, (val, acc -> acc)) :: acc when val: value, acc: term
  def foldr(%__MODULE__{__vector__: internal}, acc, fun) when is_function(fun, 2) do
    Raw.foldr(internal, acc, fun)
  end

  @doc false
  @deprecated "Use A.Enum.reduce/2 instead"
  @spec reduce(t(val), (val, val -> val)) :: val when val: value
  def reduce(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 2) do
    Raw.reduce(internal, fun)
  end

  @doc false
  @deprecated "Use A.Enum.reduce/3 instead"
  defdelegate reduce(vector, acc, fun), to: __MODULE__, as: :foldl

  @doc """
  Invokes the given `fun` to each element in the `vector` to reduce
  it to a single element, while keeping an accumulator.

  Returns a tuple where the first element is the mapped vector and
  the second one is the final accumulator.

  The function, `fun`, receives two arguments: the first one is the
  element, and the second one is the accumulator. `fun` must return
  a tuple with two elements in the form of `{result, accumulator}`.

  ## Examples

      iex> vector = A.Vector.new([1, 2, 3])
      iex> {new_vec, 6} = A.Vector.map_reduce(vector, 0, fn x, acc -> {x * 2, x + acc} end)
      iex> new_vec
      vec([2, 4, 6])

  For example, if `with_index/2` was not implemented, you could implement it as follows:

      iex> vector = A.Vector.new([1, 2, 3])
      iex> A.Vector.map_reduce(vector, 0, fn x, i -> {{x, i}, i + 1} end) |> elem(0)
      vec([{1, 0}, {2, 1}, {3, 2}])

  """
  @spec map_reduce(t(val), acc, (val, acc -> {mapped_val, acc})) :: {t(mapped_val), acc}
        when val: value, mapped_val: value, acc: any
  def map_reduce(%__MODULE__{__vector__: internal}, acc, fun) when is_function(fun, 2) do
    {new_raw, new_acc} = Raw.map_reduce(internal, acc, fun)
    {from_internal(new_raw), new_acc}
  end

  @doc """
  Applies the given function to each element in the `vector`, storing the result
  in a vector and passing it as the accumulator for the next computation.

  Uses the first element in the `vector` as the starting value.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(1..10) |> A.Vector.scan(&+/2)
      vec([1, 3, 6, 10, 15, 21, 28, 36, 45, 55])

  """
  @spec scan(t(val), (val, val -> val)) :: val when val: value
  def scan(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 2) do
    internal |> Raw.scan(fun) |> from_internal()
  end

  @doc """
  Applies the given function to each element in the `vector`, storing the result
  in a vector and passing it as the accumulator for the next computation.

  Uses the given `acc` as the starting value.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(1..10) |> A.Vector.scan(100, &+/2)
      vec([101, 103, 106, 110, 115, 121, 128, 136, 145, 155])

  """
  @spec scan(t(val), acc, (val, acc -> acc)) :: acc when val: value, acc: term
  def scan(%__MODULE__{__vector__: internal}, acc, fun) when is_function(fun, 2) do
    internal |> Raw.scan(acc, fun) |> from_internal()
  end

  @doc false
  @deprecated "Use A.Enum.each/2 instead"
  @spec each(t(val), (val -> term)) :: :ok when val: value
  def each(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 1) do
    Raw.each(internal, fun)
  end

  @doc false
  @deprecated "Use A.Enum.sum/1 instead"
  @spec sum(t(num)) :: num when num: number
  def sum(%__MODULE__{__vector__: internal}) do
    Raw.sum(internal)
  end

  @doc false
  @deprecated "Use A.Enum.product/1 instead"
  @spec product(t(num)) :: num when num: number
  def product(%__MODULE__{__vector__: internal}) do
    Raw.product(internal)
  end

  @doc false
  @deprecated "Use A.Enum.join/2 instead"
  @spec join(t(val), String.t()) :: String.t() when val: String.Chars.t()
  def join(%__MODULE__{__vector__: internal}, joiner \\ "") when is_binary(joiner) do
    Raw.join_as_iodata(internal, joiner) |> IO.iodata_to_binary()
  end

  @doc false
  @deprecated "Use A.Enum.map_join/3 instead"
  @spec map_join(t(val), String.t(), (val -> String.Chars.t())) :: String.t()
        when val: value
  def map_join(%__MODULE__{__vector__: internal}, joiner \\ "", mapper)
      when is_binary(joiner) and is_function(mapper, 1) do
    internal
    |> Raw.map(mapper)
    |> Raw.join_as_iodata(joiner)
    |> IO.iodata_to_binary()
  end

  @doc false
  @deprecated "Use A.Enum.max/3 instead"
  @spec max(t(val)) :: val when val: value
  def max(%__MODULE__{__vector__: internal}) do
    Raw.max(internal)
  end

  @doc false
  @deprecated "Use A.Enum.max/3 instead"
  @spec max(t(val), (val, val -> boolean) | module) :: val when val: value
  def max(%__MODULE__{__vector__: internal}, sorter) do
    Raw.custom_min_max(internal, max_sort_fun(sorter))
  end

  defp max_sort_fun(sorter) when is_function(sorter, 2), do: sorter
  defp max_sort_fun(module) when is_atom(module), do: &(module.compare(&1, &2) != :lt)

  @doc false
  @deprecated "Use A.Enum.min/3 instead"
  @spec min(t(val)) :: val when val: value
  def min(%__MODULE__{__vector__: internal}) do
    Raw.min(internal)
  end

  @doc false
  @deprecated "Use A.Enum.min/3 instead"
  @spec min(t(val), (val, val -> boolean) | module) :: val when val: value
  def min(%__MODULE__{__vector__: internal}, sorter) do
    Raw.custom_min_max(internal, min_sort_fun(sorter))
  end

  defp min_sort_fun(sorter) when is_function(sorter, 2), do: sorter
  defp min_sort_fun(module) when is_atom(module), do: &(module.compare(&1, &2) != :gt)

  @doc false
  @deprecated "Use A.Enum.min_by/4 instead"
  def min_by(%__MODULE__{__vector__: internal}, fun, sorter \\ &<=/2) when is_function(fun, 1) do
    Raw.custom_min_max_by(internal, fun, min_sort_fun(sorter))
  end

  @doc false
  @deprecated "Use A.Enum.max_by/4 instead"
  @spec max_by(t(val), (val -> key), (key, key -> boolean) | module) :: val
        when val: value, key: term
  def max_by(%__MODULE__{__vector__: internal}, fun, sorter \\ &>=/2) when is_function(fun, 1) do
    Raw.custom_min_max_by(internal, fun, max_sort_fun(sorter))
  end

  @doc false
  @deprecated "Use A.Enum.frequencies/1 instead"
  @spec frequencies(t(val)) :: %{optional(val) => non_neg_integer} when val: value
  def frequencies(%__MODULE__{__vector__: internal}) do
    Raw.frequencies(internal)
  end

  @doc false
  @deprecated "Use A.Enum.frequencies_by/2 instead"
  @spec frequencies_by(t(val), (val -> key)) :: %{optional(key) => non_neg_integer}
        when val: value, key: any
  def frequencies_by(%__MODULE__{__vector__: internal}, key_fun) when is_function(key_fun, 1) do
    Raw.frequencies_by(internal, key_fun)
  end

  @doc false
  @deprecated "Use A.Enum.group_by/3 instead"
  @spec group_by(t(val), (val -> key), (val -> mapped_val)) :: %{optional(key) => [mapped_val]}
        when val: value, key: any, mapped_val: any
  def group_by(%__MODULE__{__vector__: internal}, key_fun, value_fun \\ fn x -> x end)
      when is_function(key_fun, 1) and is_function(value_fun, 1) do
    Raw.group_by(internal, key_fun, value_fun)
  end

  @doc false
  @deprecated "Use A.Enum.any?/1 instead"
  @spec any?(t(val)) :: boolean when val: value
  def any?(%__MODULE__{__vector__: internal}) do
    Raw.any?(internal)
  end

  @doc false
  @deprecated "Use A.Enum.any?/2 instead"
  @spec any?(t(val), (val -> as_boolean(term))) :: boolean when val: value
  def any?(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 1) do
    Raw.any?(internal, fun)
  end

  @doc false
  @deprecated "Use A.Enum.all?/1 instead"
  @spec all?(t(val)) :: boolean when val: value
  def all?(%__MODULE__{__vector__: internal}) do
    Raw.all?(internal)
  end

  @doc false
  @deprecated "Use A.Enum.all?/2 instead"
  @spec all?(t(val), (val -> as_boolean(term))) :: boolean when val: value
  def all?(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 1) do
    Raw.all?(internal, fun)
  end

  @doc false
  @deprecated "Use A.Enum.find/3 instead"
  @spec find(t(val), default, (val -> as_boolean(term))) :: val | default
        when val: value, default: value
  def find(%__MODULE__{__vector__: internal}, default \\ nil, fun) when is_function(fun, 1) do
    Raw.find(internal, default, fun)
  end

  @doc false
  @deprecated "Use A.Enum.find_value/3 instead"
  @spec find_value(t(val), default, (val -> new_val)) :: new_val | default
        when val: value, new_val: value, default: value
  def find_value(%__MODULE__{__vector__: internal}, default \\ nil, fun)
      when is_function(fun, 1) do
    Raw.find_value(internal, fun) || default
  end

  @doc false
  @deprecated "Use A.Enum.find_index/2 instead"
  @spec find_index(t(val), (val -> as_boolean(term))) :: non_neg_integer | nil when val: value
  def find_index(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 1) do
    Raw.find_index(internal, fun)
  end

  @doc """
  Returns the `vector` in reverse order.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(1..12) |> A.Vector.reverse()
      vec([12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1])

  """
  @spec reverse(t(val)) :: t(val) when val: value
  def reverse(%__MODULE__{__vector__: internal}) do
    internal
    |> Raw.reverse_to_list([])
    |> from_list()
  end

  @doc """
  Returns the `vector` in reverse order, and concatenates the `tail` (enumerable).

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(1..5) |> A.Vector.reverse(100..105)
      vec([5, 4, 3, 2, 1, 100, 101, 102, 103, 104, 105])

  """
  @spec reverse(t(val), Enumerable.t()) :: t(val) when val: value
  def reverse(%__MODULE__{__vector__: internal}, tail) do
    internal
    |> Raw.reverse_to_list(A.EnumHelper.to_list(tail))
    |> from_list()
  end

  @doc """
  Returns a subset of the given `vector` by `index_range`.

  Works the same as `Enum.slice/2`, see its documentation for more details.

  Runs in linear time regarding the size of the returned subset.

  ## Examples

      iex> A.Vector.new(0..100) |> A.Vector.slice(80..90)
      vec([80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90])
      iex> A.Vector.new(0..100) |> A.Vector.slice(-40..-30)
      vec([61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71])
      iex> A.Vector.new([:only_one]) |> A.Vector.slice(0..1000)
      vec([:only_one])

  """
  @spec slice(t(val), Range.t()) :: t(val) when val: value
  def slice(%__MODULE__{} = vector, first..last = index_range) do
    case first do
      0 ->
        amount = last + 1

        if last < 0 do
          drop(vector, amount)
        else
          take(vector, amount)
        end

      _ ->
        vector
        |> Enum.slice(index_range)
        |> from_list()
    end
  end

  @doc """
  Returns a subset of the given `vector`, from `start_index` (zero-based)
  with `amount number` of elements if available.

  Works the same as `Enum.slice/3`, see its documentation for more details.

  Runs in linear time regarding the size of the returned subset.

  ## Examples

      iex> A.Vector.new(0..100) |> A.Vector.slice(80, 10)
      vec([80, 81, 82, 83, 84, 85, 86, 87, 88, 89])
      iex> A.Vector.new(0..100) |> A.Vector.slice(-40, 10)
      vec([61, 62, 63, 64, 65, 66, 67, 68, 69, 70])
      iex> A.Vector.new([:only_one]) |> A.Vector.slice(0, 1000)
      vec([:only_one])

  """
  @spec slice(t(val), index, non_neg_integer) :: t(val) when val: value
  def slice(%__MODULE__{__vector__: internal} = vector, start_index, amount)
      when is_integer(start_index) and is_integer(amount) and amount >= 0 do
    if start_index == 0 or start_index == -Raw.size(internal) do
      Raw.take(internal, amount) |> from_internal()
    else
      vector
      |> Enum.slice(start_index, amount)
      |> from_list()
    end
  end

  @doc """
  Takes an `amount` of elements from the beginning or the end of the `vector`.

  If a positive `amount` is given, it takes the amount elements from the beginning of the `vector`.

  If a negative `amount` is given, the amount of elements will be taken from the end.

  If amount is 0, it returns the empty vector.

  Time complexity is:
  - effective constant time when `amount` is positive, as the vector structure can be shared
  - linear when `amount` is negative, as the vector needs to be reconstructed.

  ## Examples

      iex> A.Vector.new(0..100) |> A.Vector.take(10)
      vec([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
      iex> A.Vector.new([:only_one]) |> A.Vector.take(1000)
      vec([:only_one])
      iex> A.Vector.new(0..10) |> A.Vector.take(-5)
      vec([6, 7, 8, 9, 10])

  """
  @spec take(t(val), integer) :: t(val) when val: value
  def take(%__MODULE__{__vector__: internal}, amount) when is_integer(amount) do
    do_take(internal, amount) |> from_internal()
  end

  defp do_take(internal, amount) when amount < 0 do
    size = Raw.size(internal)

    case size + amount do
      start when start > 0 ->
        internal
        |> Raw.slice(start, size - 1)
        |> Raw.from_list()

      _ ->
        internal
    end
  end

  defp do_take(internal, amount) do
    Raw.take(internal, amount)
  end

  @doc """
  Drops the amount of elements from the `vector`.

  If a negative `amount` is given, the amount of last values will be dropped.

  Time complexity is:
  - linear when `amount` is positive, as the vector needs to be reconstructed.
  - effective constant time when `amount` is negative, as the vector structure can be shared

  ## Examples

      iex> A.Vector.new(0..15) |> A.Vector.drop(10)
      vec([10, 11, 12, 13, 14, 15])
      iex> A.Vector.new(0..5) |> A.Vector.drop(0)
      vec([0, 1, 2, 3, 4, 5])
      iex> A.Vector.new(0..10) |> A.Vector.drop(-5)
      vec([0, 1, 2, 3, 4, 5])

  """
  @spec drop(t(val), integer) :: t(val) when val: value
  def drop(%__MODULE__{__vector__: internal}, amount) when is_integer(amount) do
    do_drop(internal, amount) |> from_internal()
  end

  defp do_drop(internal, _amount = 0) do
    internal
  end

  defp do_drop(internal, amount) when amount < 0 do
    size = Raw.size(internal)

    case size + amount do
      keep when keep > 0 -> Raw.take(internal, size + amount)
      _ -> @empty_raw
    end
  end

  defp do_drop(internal, amount) do
    size = Raw.size(internal)

    if amount >= size do
      @empty_raw
    else
      internal
      |> Raw.slice(amount, size - 1)
      |> Raw.from_list()
    end
  end

  @doc """
  Splits the `vector` into two vectors, leaving `amount` elements in the first one.

  If `amount` is a negative number, it starts counting from the back to the beginning of the `vector`.

  Runs in linear time.

  ## Examples

      iex> vector = A.Vector.new([1, 2, 3])
      iex> A.Vector.split(vector, 2) |> inspect()
      "{vec([1, 2]), vec([3])}"
      iex> A.Vector.split(vector, 10) |> inspect()
      "{vec([1, 2, 3]), vec([])}"
      iex> A.Vector.split(vector, 0) |> inspect()
      "{vec([]), vec([1, 2, 3])}"
      iex> A.Vector.split(vector, -1) |> inspect()
      "{vec([1, 2]), vec([3])}"
      iex> A.Vector.split(vector, -5) |> inspect()
      "{vec([]), vec([1, 2, 3])}"

  """
  @spec split(t(val), integer) :: {t(val), t(val)} when val: value
  def split(%__MODULE__{__vector__: internal} = vector, amount) when is_integer(amount) do
    size = Raw.size(internal)

    case Raw.actual_index(amount, size) do
      nil ->
        case amount do
          positive when positive > 0 -> {vector, new()}
          _ -> {new(), vector}
        end

      actual_amount ->
        taken = Raw.take(internal, actual_amount)
        dropped = do_drop(internal, actual_amount)
        {from_internal(taken), from_internal(dropped)}
    end
  end

  @doc """
  Takes the elements from the beginning of the `vector` while `fun` returns a truthy value.

  Runs in linear time regarding the size of the returned subset.

  ## Examples

      iex> A.Vector.new(1..100) |> A.Vector.take_while(fn x -> x < 7 end)
      vec([1, 2, 3, 4, 5, 6])
      iex> A.Vector.new([1, true, %{}, nil, "abc"]) |> A.Vector.take_while(fn x -> x end)
      vec([1, true, %{}])

  """
  @spec take_while(t(val), (val -> as_boolean(term()))) :: t(val) when val: value
  def take_while(%__MODULE__{__vector__: internal} = vector, fun) when is_function(fun, 1) do
    case Raw.find_falsy_index(internal, fun) do
      nil ->
        vector

      index ->
        Raw.take(internal, index) |> from_internal()
    end
  end

  @doc """
  Drops elements at the beginning of the `vector` while `fun` returns a truthy value.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(1..10) |> A.Vector.drop_while(fn x -> x < 7 end)
      vec([7, 8, 9, 10])
      iex> A.Vector.new([1, true, %{}, nil, "abc"]) |> A.Vector.drop_while(fn x -> x end)
      vec([nil, "abc"])

  """
  @spec drop_while(t(val), (val -> as_boolean(term()))) :: t(val) when val: value
  def drop_while(%__MODULE__{__vector__: internal} = vector, fun) when is_function(fun, 1) do
    case Raw.find_falsy_index(internal, fun) do
      nil ->
        new()

      0 ->
        vector

      index ->
        size = Raw.size(internal)

        internal
        |> Raw.slice(index, size - 1)
        |> from_list()
    end
  end

  @doc """
  Splits `vector` in two at the position of the element for which `fun` returns a falsy value
  (`false` or `nil`) for the first time.

  It returns a two-element tuple with two vectors of elements.
  The element that triggered the split is part of the second vector.

  Is basically performing `take_while/2` and `drop_while/2` at once.

  Runs in linear time.

  ## Examples

      iex> {taken, dropped} = A.Vector.new(1..10) |> A.Vector.split_while(fn x -> x < 7 end)
      iex> taken
      vec([1, 2, 3, 4, 5, 6])
      iex> dropped
      vec([7, 8, 9, 10])

  """
  @spec split_while(t(val), (val -> as_boolean(term()))) :: {t(val), t(val)} when val: value
  def split_while(%__MODULE__{__vector__: internal} = vector, fun) when is_function(fun, 1) do
    case Raw.find_falsy_index(internal, fun) do
      nil ->
        {vector, new()}

      0 ->
        {new(), vector}

      index ->
        size = Raw.size(internal)

        taken = Raw.take(internal, index) |> from_internal()

        dropped =
          internal
          |> Raw.slice(index, size - 1)
          |> from_list()

        {taken, dropped}
    end
  end

  @doc ~S"""
  Returns the `vector` with each element wrapped in a tuple alongside its index.

  May receive a function or an integer offset.

  If an integer `offset` is given, it will index from the given `offset` instead of from zero.

  If a `function` is given, it will index by invoking the function for each
  element and index (zero-based) of the `vector`.

  Runs in linear time.

  ## Examples

      iex> vector = A.Vector.new(["foo", "bar", "baz"])
      iex> A.Vector.with_index(vector)
      vec([{"foo", 0}, {"bar", 1}, {"baz", 2}])
      iex> A.Vector.with_index(vector, 100)
      vec([{"foo", 100}, {"bar", 101}, {"baz", 102}])
      iex> A.Vector.with_index(vector, fn element, index -> {index, element} end)
      vec([{0, "foo"}, {1, "bar"}, {2, "baz"}])

  """
  @spec with_index(t(val), index) :: t({val, index}) when val: value
  @spec with_index(t(val), (val, index -> mapped_val)) :: t(mapped_val)
        when val: value, mapped_val: value
  def with_index(vector, fun_or_offset \\ 0)

  def with_index(%__MODULE__{__vector__: internal}, offset) when is_integer(offset) do
    Raw.with_index(internal, offset) |> from_internal()
  end

  def with_index(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 2) do
    Raw.with_index(internal, 0, fun) |> from_internal()
  end

  @doc false
  @deprecated "Use A.Enum.random/1 instead"
  @spec random(t(val)) :: val when val: value
  def random(%__MODULE__{__vector__: internal}) do
    Raw.random(internal)
  end

  @doc """
  Takes `amount` random elements from `vector`.

  Note that, unless `amount` is `0` or `1`, this function will
  traverse the whole `vector` to get the random sub-vector.

  If `amount` is more than the `vector` size, this is equivalent to shuffling the `vector`:
  the returned vector cannot be bigger than the original one.

  See `Enum.random/1` for notes on implementation and random seed.

  Runs in linear time (except for `amount <= 1`, which is effective constant time).

  ## Examples

      # Although not necessary, let's seed the random algorithm
      iex> :rand.seed(:exrop, {1, 2, 3})
      iex> A.Vector.new(1..10) |> A.Vector.take_random(2)
      vec([7, 2])
      iex> A.Vector.new([:foo, :bar, :baz]) |> A.Vector.take_random(100)
      vec([:bar, :baz, :foo])

  """
  @spec take_random(t(val), non_neg_integer) :: t(val) when val: value
  def take_random(%__MODULE__{__vector__: internal}, amount)
      when is_integer(amount) and amount >= 0 do
    Raw.take_random(internal, amount) |> from_internal()
  end

  @doc """
  Returns a new vector with the elements of `vector` shuffled.

  See `Enum.shuffle/1` for notes on implementation and random seed.

  ## Examples

      # Although not necessary, let's seed the random algorithm
      iex> :rand.seed(:exrop, {1, 2, 3})
      iex> A.Vector.new([1, 2, 3]) |> A.Vector.shuffle()
      vec([3, 1, 2])
      iex> A.Vector.new([1, 2, 3]) |> A.Vector.shuffle()
      vec([1, 3, 2])

  """
  @spec shuffle(t(val)) :: t(val) when val: value
  def shuffle(%__MODULE__{__vector__: internal}) do
    # Note: benchmarks suggest that this is already fast without further optimization
    internal
    |> Raw.to_list()
    |> Enum.shuffle()
    |> from_list()
  end

  @doc """
  Zips corresponding elements from two vectors into one vector of tuples.

  The size of the returned vector is the one of the smallest of the input vectors.

  Runs in linear time.

      iex> A.Vector.zip(A.Vector.new([1, 2, 3]), A.Vector.new([:a, :b, :c]))
      vec([{1, :a}, {2, :b}, {3, :c}])
      iex> A.Vector.zip(A.Vector.new(0..100), A.Vector.new([:a, :b, :c]))
      vec([{0, :a}, {1, :b}, {2, :c}])

  """
  @spec zip(t(val1), t(val2)) :: t({val1, val2}) when val1: value, val2: value
  def zip(vector1, vector2)

  def zip(%__MODULE__{__vector__: internal1}, %__MODULE__{__vector__: internal2}) do
    Raw.zip(internal1, internal2) |> from_internal()
  end

  @doc """
  Zips corresponding elements from two vectors into a new vector,
  transforming them with the `zip_fun` function as it goes.

  The corresponding elements from each vector are passed to the
  provided 2-arity `zip_fun` function in turn.

  Runs in linear time.

      iex> A.Vector.zip_with(A.Vector.new([1, 2, 3]), A.Vector.new([:a, :b, :c]), &{&2, &1})
      vec([a: 1, b: 2, c: 3])
      iex> A.Vector.zip_with(A.Vector.new(0..100), A.Vector.new([:a, :b, :c]), &{&2, &1})
      vec([a: 0, b: 1, c: 2])

  """
  @spec zip_with(t(val1), t(val2), (val1, val2 -> val3)) :: t(val3)
        when val1: value, val2: value, val3: value
  def zip_with(vector1, vector2, zip_fun)

  def zip_with(%__MODULE__{__vector__: internal1}, %__MODULE__{__vector__: internal2}, zip_fun)
      when is_function(zip_fun, 2) do
    Raw.zip_with(internal1, internal2, zip_fun) |> from_internal()
  end

  @doc """
  Opposite of `zip/2`. Extracts two-element tuples from the given `vector` and groups them together.

  It takes a `vector` with elements being two-element tuples and returns a tuple with two vectors,
  each of which is formed by the first and second element of each tuple, respectively.

  This function fails unless `vector` only contains tuples with exactly two elements in each tuple.

  Runs in linear time.

      iex> {vector1, vector2} = A.Vector.new([{1, :a}, {2, :b}, {3, :c}]) |> A.Vector.unzip()
      iex> vector1
      vec([1, 2, 3])
      iex> vector2
      vec([:a, :b, :c])

  """
  @spec unzip(t({val1, val2})) :: {t(val1), t(val2)} when val1: value, val2: value
  def unzip(%__MODULE__{__vector__: internal}) do
    {internal1, internal2} = Raw.unzip(internal)

    {from_internal(internal1), from_internal(internal2)}
  end

  # Private functions

  defp from_list([]), do: from_internal(@empty_raw)
  defp from_list(list), do: Raw.from_list(list) |> from_internal()

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(vector, opts) do
      opts = %Inspect.Opts{opts | charlists: :as_lists}
      concat(["vec(", Inspect.List.inspect(A.Vector.to_list(vector), opts), ")"])
    end
  end

  defimpl Enumerable do
    def count(vector) do
      {:ok, A.Vector.size(vector)}
    end

    def member?(%A.Vector{__vector__: internal}, value) do
      {:ok, Raw.member?(internal, value)}
    end

    def slice(%A.Vector{__vector__: internal}) do
      size = A.Vector.Raw.size(internal)

      {:ok, size, fn start, length -> A.Vector.Raw.slice(internal, start, start + length - 1) end}
    end

    def reduce(%A.Vector{__vector__: internal}, acc, fun) do
      # TODO investigate best way to warn
      # flag it?
      # IO.warn(
      #   "Enum has sub-optimal performance for A.Vector, use A.Enum (see https://hexdocs.pm/aja/A.Enum.html)"
      # )

      internal
      |> A.Vector.Raw.to_list()
      |> Enumerable.List.reduce(acc, fun)
    end
  end

  defimpl Collectable do
    alias A.Vector.Raw

    def into(%A.Vector{__vector__: internal}) do
      {[],
       fn
         acc, {:cont, value} -> [value | acc]
         acc, :done -> done(internal, acc)
         _acc, :halt -> :ok
       end}
    end

    defp done(internal, acc) do
      new_internal = Raw.concat_list(internal, :lists.reverse(acc))
      %A.Vector{__vector__: new_internal}
    end
  end

  if Code.ensure_loaded?(Jason.Encoder) do
    defimpl Jason.Encoder do
      def encode(vector, opts) do
        vector |> A.Vector.to_list() |> Jason.Encode.list(opts)
      end
    end
  end
end
