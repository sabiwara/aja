defmodule A.Vector do
  # TODO remove doc hack when stop supporting 1.10
  @plusplusplus_doc ~S"""
  ## Convenience [`+++/2`](`A.+++/2`) operator

  The `A.+++/2` operator can make appending to a vector more compact by aliasing `A.Vector.concat/2`:

      iex> import A
      iex> vec([1, 2, 3]) +++ vec([4, 5])
      #A<vec([1, 2, 3, 4, 5])>
  """

  @moduledoc ~s"""
  A Clojure-like persistent vector with efficient appends and random access.

  [Persistent vectors](https://hypirion.com/musings/understanding-persistent-vector-pt-1)
  are an efficient alternative to lists.
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
  - should have higher performance in most use cases, especially "loops" like `map/2` / `to_list/1` / `foldl/3`
  - mirrors the `Enum` module API, with highly optimized versions for vectors (`join/1`, `sum/1`, `random/1`...)
  - supports negative indexing (e.g. `-1` corresponds to the last element)
  - optionally implements the `Jason.Encoder` protocol if `Jason` is installed

  Note: most of the design is inspired by
  [this series of blog posts](https://hypirion.com/musings/understanding-persistent-vector-pt-1),
  but a branching factor of `16 = 2 ^ 4` has been picked instead of `32 = 2 ^ 5`.
  This choice was made following performance benchmarking that showed better overall performance
  for this particular implementation.

  ## Examples

      iex> vector = A.Vector.new(1..10)
      #A<vec([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])>
      iex> A.Vector.append(vector, :foo)
      #A<vec([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, :foo])>
      iex> vector[3]
      4
      iex> A.Vector.replace_at(vector, -1, :bar)
      #A<vec([1, 2, 3, 4, 5, 6, 7, 8, 9, :bar])>
      iex> 3 in vector
      true

  ## Access behaviour

  `A.Vector` implements the `Access` behaviour.

      iex> vector = A.Vector.new(1..10)
      iex> vector[3]
      4
      iex> put_in(vector[5], :foo)
      #A<vec([1, 2, 3, 4, 5, :foo, 7, 8, 9, 10])>
      iex> {9, updated} = pop_in(vector[8]); updated
      #A<vec([1, 2, 3, 4, 5, 6, 7, 8, 10])>

  ## Convenience [`vec/1`](`A.vec/1`) and [`vec_size/1`](`A.vec_size/1`) macros

  The `A.Vector` module can be used without any macro.

  The `A.vec/1` macro does however provide some syntactic sugar to make
  it more convenient to work with vectors of known size, namely:
  - pattern match on elements for vectors of known size
  - construct new vectors of known size faster, by generating the AST at compile time

  Examples:

      iex> import A
      iex> vec([1, 2, 3])
      #A<vec([1, 2, 3])>
      iex> vec([1, 2, var, _, _, _]) = A.Vector.new(1..6); var
      3

  The `A.vec_size/1` macro can be used in guards:

      iex> import A
      iex> match?(v when vec_size(v) > 99, A.Vector.new(1..100))
      true

  #{
    if Version.compare(System.version(), "1.11.0") != :lt do
      @plusplusplus_doc
    end
  }


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
      [2, 28]
      iex> memory_for.(10)
      [20, 28]
      iex> memory_for.(100)
      [200, 150]
      iex> memory_for.(10_000)
      [20000, 11370]

  If you need to work with vectors containing mostly the same value, `A.Vector.duplicate/2`
  is highly efficient both in time and memory (logarithmic).
  It minimizes the number of actual copies and reuses the same nested structures under the hood:

      iex> A.Vector.duplicate(0, 10_000) |> :erts_debug.size()
      116
      iex> A.Vector.duplicate(0, 10_000) |> :erts_debug.flat_size()  # when shared over processes / ETS
      11370

  Even a 1B x 1B matrix of the same element costs virtually nothing!

      big_n = 1_000_000_000
      0 |> A.Vector.duplicate(big_n) |> A.Vector.duplicate(big_n) |> :erts_debug.size()
      538


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

  Deleting close to the end of the vector is still fairly fast, but deleting near
  the beginning needs to reconstruct most of the vector.

  Deletion functionality is provided through functions like `A.Vector.pop_at/3`
  and `A.Vector.delete_at/2` for the sake of completion, but please note that they
  are inefficient and their usage is discouraged.

  If you need to be able to pop arbitrary indexes, chances are you should consider
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
      Enum.into(enumerable, vector)

  **DO**

      A.Vector.concat(vector, enumerable)
      #{
    if Version.compare(System.version(), "1.11.0") != :lt do
      "vector +++ enumerable"
    end
  }

  ### Prefer `A.Vector` to `Enum` for vectors

  Many functions provided in this module are very efficient and should be
  used over `Enum` functions whenever possible, even if `A.Vector` implements
  the `Enumerable` and `Collectable` protocols for convienience:

  **DON'T**

      Enum.sum(vector)
      Enum.to_list(vector)
      Enum.reduce(vector, [], fun)
      Enum.into(enumerable, %A.Vector.new())
      Enum.into(enumerable, vector)

  **DO**

      A.Vector.sum(vector)
      A.Vector.to_list(vector)
      A.Vector.foldl(vector, [], fun)
      A.Vector.new(enumerable)
      A.Vector.concat(vector, enumerable)

  `for` comprehensions are actually using `Enumerable` as well, so
  the same advice holds:

  **DON'T**

      for value <- vector do
        do_stuff()
      end

  **DO**

      for value <- A.Vector.to_list(vector) do
        do_stuff()
      end

  ### Exceptions: `Enum` optimized functions

  `Enum.member?/2` is implemented in an efficient way, so `in/2` is optimal:

  **DO**

      33 in vector

  `Enum.slice/2` and `Enum.slice/3` are optimized and their use is encouraged,
  other "slicing" functions like `Enum.take/2` or `Enum.drop/2` however are inefficient:

  **DON'T**

      Enum.take(vector, 10)
      Enum.drop(vector, 25)

  **DO**

      Enum.slice(vector, 0, 10)
      Enum.slice(vector, 0..10)
      Enum.slice(vector, 25..-1)

  ### Slicing optimization

  Slicing any subset on the left on the vector using methods from `A.Vector` is
  extremely efficient as the vector internals can be reused:

  **DO**

      A.Vector.take(vector, 10)  # take a positive amount
      A.Vector.drop(vector, -20)  # drop a negative amount
      A.Vector.slice(vector, 0, 10)  # slicing from 0
      A.Vector.slice(vector, 0..-5)  # slicing from 0

  ### `A.Vector` and `Enum` APIs

  Not all `Enum` functions have been mirrored in `A.Vector`, but
  you can try either to:
  - use `A.Vector.foldl/3` or `A.Vector.foldr/3` to implement it
    (the latter is better to build lists)
  - call `A.Vector.to_list/1` before using `Enum`

  Also, it is worth noting that several `A.Vector` functions return vectors,
  not lists like their `Enum` counterpart:

      iex> vector = A.Vector.new(1..10)
      iex> A.Vector.map(vector, & (&1 * 7))
      #A<vec([7, 14, 21, 28, 35, 42, 49, 56, 63, 70])>
      iex> A.Vector.reverse(vector)
      #A<vec([10, 9, 8, 7, 6, 5, 4, 3, 2, 1])>

  ### Additional notes

  * If you need to work with vectors containing mostly the same value,
    use `A.Vector.duplicate/2` (more details in the [Memory usage section](#module-memory-usage)).

  * If you work with functions returning vectors of known size, you can use
    the `A.vec/1` macro to defer the generation of the AST for the internal
    structure to compile time instead of runtime.

        A.Vector.new([a, 1, 2, 3, 4])  # structure created at runtime
        vec([a, 1, 2, 3, 4])  # structure AST defined at compile time

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
      #A<vec([])>

  """
  @compile {:inline, new: 0}
  @spec new :: t()
  def new() do
    %__MODULE__{__vector__: @empty_raw}
  end

  @doc """
  Creates a vector from an `enumerable`.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(10..25)
      #A<vec([10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25])>

  """
  @spec new(Enumerable.t()) :: t()
  def new(%__MODULE__{} = vector) do
    vector
  end

  def new(enumerable) do
    %__MODULE__{
      __vector__: enumerable |> A.FastEnum.to_list() |> Raw.from_list()
    }
  end

  @doc """
  Creates a vector from an `enumerable` via the given `transform` function.

  ## Examples

      iex> A.Vector.new(1..10, &(&1 * &1))
      #A<vec([1, 4, 9, 16, 25, 36, 49, 64, 81, 100])>

  """
  @spec new(Enumerable.t(), (v1 -> v2)) :: t(v2) when v1: value, v2: value
  def new(enumerable, fun) when is_function(fun, 1) do
    case enumerable do
      %__MODULE__{} ->
        map(enumerable, fun)

      _ ->
        %__MODULE__{
          __vector__: enumerable |> A.FastEnum.to_list() |> Raw.from_mapped_list(fun)
        }
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
      #A<vec([nil, nil, nil, nil, nil, nil, nil, nil, nil, nil])>
      iex> A.Vector.duplicate(:foo, 0)
      #A<vec([])>

  """
  @spec duplicate(val, non_neg_integer) :: t(val) when val: value
  def duplicate(value, n) when is_integer(n) and n >= 0 do
    %__MODULE__{
      __vector__: Raw.duplicate(value, n)
    }
  end

  @doc """
  Populates a vector of size `n` by calling `generator_fun` repeatedly.

  ## Examples

      # Although not necessary, let's seed the random algorithm
      iex> :rand.seed(:exsplus, {1, 2, 3})
      iex> A.Vector.repeatedly(&:rand.uniform/0, 3)
      #A<vec([0.40502929729990744, 0.45336720247823126, 0.04094511692041057])>

  """
  def repeatedly(generator_fun, n)
      when is_function(generator_fun, 0) and is_integer(n) and n >= 0 do
    %__MODULE__{
      __vector__: A.List.repeatedly(generator_fun, n) |> Raw.from_list()
    }
  end

  @doc """
  Appends a `value` at the end of a `vector`.

  Runs in effective constant time.

  ## Examples

      iex> A.Vector.new() |> A.Vector.append(:foo)
      #A<vec([:foo])>
      iex> A.Vector.new(1..5) |> A.Vector.append(:foo)
      #A<vec([1, 2, 3, 4, 5, :foo])>

  """
  @spec append(t(val), val) :: t(val) when val: value
  def append(%__MODULE__{__vector__: internal}, value) do
    %__MODULE__{
      __vector__: Raw.append(internal, value)
    }
  end

  @doc """
  Appends all values from an `enumerable` at the end of a `vector`.

  Runs in effective linear time in respect with the length of `enumerable`,
  disregarding the size of the `vector`.

  ## Examples

      iex> A.Vector.new(1..5) |> A.Vector.concat(10..15)
      #A<vec([1, 2, 3, 4, 5, 10, 11, 12, 13, 14, 15])>
      iex> A.Vector.new() |> A.Vector.concat(10..15)
      #A<vec([10, 11, 12, 13, 14, 15])>

  """
  @spec concat(t(val), Enumerable.t()) :: t(val) when val: value
  def concat(%__MODULE__{__vector__: internal}, enumerable) do
    list = A.FastEnum.to_list(enumerable)

    %__MODULE__{
      __vector__: Raw.concat(internal, list)
    }
  end

  @deprecated "Use A.Vector.concat/2 instead"
  defdelegate append_many(vector, enumerable), to: __MODULE__, as: :concat

  @doc """
  (Inefficient) Prepends `value` at the beginning of the `vector`.

  Runs in linear time because the whole vector needs to be reconstructuded,
  and should be avoided.

  ## Examples

      iex> A.Vector.new() |> A.Vector.prepend(:foo)
      #A<vec([:foo])>
      iex> A.Vector.new(1..5) |> A.Vector.prepend(:foo)
      #A<vec([:foo, 1, 2, 3, 4, 5])>

  """
  @spec prepend(t(val), val) :: t(val) when val: value
  def prepend(%__MODULE__{__vector__: internal}, value) do
    %__MODULE__{
      __vector__: Raw.prepend(internal, value)
    }
  end

  @doc """
  Returns the first element in the `vector` or `default` if `vector` is empty.

  Runs in effective constant time.

  ## Examples

      iex> A.Vector.new(1..10_000) |> A.Vector.first()
      1
      iex> A.Vector.new() |> A.Vector.first()
      nil

  """
  @spec first(t(val), default) :: val | default when val: value, default: term
  def first(vector, default \\ nil)

  def first(%__MODULE__{__vector__: internal}, default) do
    Raw.first(internal, default)
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
    Raw.last(internal, default)
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
      #A<vec([1, 2, 3, 4, 5, :foo, 7, 8])>
      iex> A.Vector.new(1..8) |> A.Vector.replace_at(8, :foo)
      #A<vec([1, 2, 3, 4, 5, 6, 7, 8])>
      iex> A.Vector.new(1..8) |> A.Vector.replace_at(-2, :foo)
      #A<vec([1, 2, 3, 4, 5, 6, :foo, 8])>

  """
  @spec replace_at(t(val), index, val) :: t(val) when val: value
  def replace_at(%__MODULE__{__vector__: internal} = vector, index, value)
      when is_integer(index) do
    size = Raw.size(internal)

    case Raw.actual_index(index, size) do
      nil ->
        vector

      actual_index ->
        new_internal = Raw.replace_positive!(internal, actual_index, value)
        %__MODULE__{__vector__: new_internal}
    end
  end

  @doc """
  Returns a copy of `vector` with a replaced `value` at the specified `index`.

  Raises an `A.Vector.IndexError` if `index` is out of bounds.
  Supports negative indexing from the end of the `vector`.

  Runs in effective constant time.

  ## Examples

      iex> A.Vector.new(1..8) |> A.Vector.replace_at!(5, :foo)
      #A<vec([1, 2, 3, 4, 5, :foo, 7, 8])>
      iex> A.Vector.new(1..8) |> A.Vector.replace_at!(-2, :foo)
      #A<vec([1, 2, 3, 4, 5, 6, :foo, 8])>
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
        new_internal = Raw.replace_positive!(internal, actual_index, value)
        %__MODULE__{__vector__: new_internal}
    end
  end

  @doc """
  Returns a copy of `vector` with an updated value at the specified `index`.

  Returns the `vector` untouched if `index` is out of bounds.
  Supports negative indexing from the end of the `vector`.

  Runs in effective constant time.

  ## Examples

      iex> A.Vector.new(1..8) |> A.Vector.update_at(2, &(&1 * 1000))
      #A<vec([1, 2, 3000, 4, 5, 6, 7, 8])>
      iex> A.Vector.new(1..8) |> A.Vector.update_at(8, &(&1 * 1000))
      #A<vec([1, 2, 3, 4, 5, 6, 7, 8])>
      iex> A.Vector.new(1..8) |> A.Vector.update_at(-1, &(&1 * 1000))
      #A<vec([1, 2, 3, 4, 5, 6, 7, 8000])>

  """
  @spec update_at(t(val), index, (val -> val)) :: t(val) when val: value
  def update_at(%__MODULE__{__vector__: internal} = vector, index, fun)
      when is_integer(index) and is_function(fun) do
    size = Raw.size(internal)

    case Raw.actual_index(index, size) do
      nil ->
        vector

      actual_index ->
        new_internal = Raw.update_positive!(internal, actual_index, fun)
        %__MODULE__{__vector__: new_internal}
    end
  end

  @doc """
  Returns a copy of `vector` with an updated value at the specified `index`.

  Raises an `A.Vector.IndexError` if `index` is out of bounds.
  Supports negative indexing from the end of the `vector`.

  Runs in effective constant time.

  ## Examples

      iex> A.Vector.new(1..8) |> A.Vector.update_at!(2, &(&1 * 1000))
      #A<vec([1, 2, 3000, 4, 5, 6, 7, 8])>
      iex> A.Vector.new(1..8) |> A.Vector.update_at!(-1, &(&1 * 1000))
      #A<vec([1, 2, 3, 4, 5, 6, 7, 8000])>
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
        new_internal = Raw.update_positive!(internal, actual_index, fun)
        %__MODULE__{__vector__: new_internal}
    end
  end

  @doc """
  Removes the last value from the `vector` and returns both the value and the updated vector.

  Leaves the `vector` untouched if empty.

  Runs in effective constant time.

  ## Examples

      iex> vector = A.Vector.new(1..8)
      iex> {8, updated} = A.Vector.pop_last(vector); updated
      #A<vec([1, 2, 3, 4, 5, 6, 7])>
      iex> {nil, updated} = A.Vector.pop_last(A.Vector.new()); updated
      #A<vec([])>

  """
  @spec pop_last(t(val), default) :: {val | default, t(val)} when val: value, default: term
  def pop_last(vector, default \\ nil)

  def pop_last(%__MODULE__{__vector__: internal} = vector, default) do
    case Raw.pop_last(internal) do
      {value, new_internal} -> {value, %__MODULE__{__vector__: new_internal}}
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
      #A<vec([1, 2, 3, 4, 5, 6, 7])>
      iex> {nil, updated} = A.Vector.pop_last!(A.Vector.new()); updated
      ** (A.Vector.EmptyError) empty vector error

  """
  @spec pop_last!(t(val)) :: {val, t(val)} when val: value
  def pop_last!(vector)

  def pop_last!(%__MODULE__{__vector__: internal}) do
    case Raw.pop_last(internal) do
      {value, new_internal} -> {value, %__MODULE__{__vector__: new_internal}}
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
      #A<vec([1, 2, 3, 4, 5, 6, 7])>
      iex> A.Vector.delete_last(A.Vector.new())
      #A<vec([])>

  """
  @spec delete_last(t(val)) :: t(val) when val: value
  def delete_last(vector)

  def delete_last(%__MODULE__{__vector__: internal} = vector) do
    case Raw.pop_last(internal) do
      {_value, new_internal} -> %__MODULE__{__vector__: new_internal}
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
      #A<vec([1, 2, 3, 4, 5, 6, 7])>
      iex> A.Vector.delete_last!(A.Vector.new())
      ** (A.Vector.EmptyError) empty vector error

  """
  @spec delete_last!(t(val)) :: t(val) when val: value
  def delete_last!(vector)

  def delete_last!(%__MODULE__{__vector__: internal}) do
    case Raw.pop_last(internal) do
      {_value, new_internal} -> %__MODULE__{__vector__: new_internal}
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
      #A<vec([1, 2, 3, 4, 6, 7, 8])>
      iex> {nil, updated} = A.Vector.pop_at(vector, -9); updated
      #A<vec([1, 2, 3, 4, 5, 6, 7, 8])>

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
        {value, %__MODULE__{__vector__: new_internal}}
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
      #A<vec([1, 2, 3, 4, 6, 7, 8])>
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
        {value, %__MODULE__{__vector__: new_internal}}
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
      #A<vec([1, 2, 3, 4, 6, 7, 8])>
      iex> A.Vector.delete_at(vector, -9)
      #A<vec([1, 2, 3, 4, 5, 6, 7, 8])>

  """
  @spec delete_at(t(val), index) :: t(val) when val: value
  def delete_at(%__MODULE__{__vector__: internal} = vector, index) when is_integer(index) do
    size = Raw.size(internal)

    case Raw.actual_index(index, size) do
      nil ->
        vector

      actual_index ->
        new_internal = Raw.delete_positive!(internal, actual_index, size)
        %__MODULE__{__vector__: new_internal}
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
      #A<vec([1, 2, 3, 4, 6, 7, 8])>
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
        new_internal = Raw.delete_positive!(internal, actual_index, size)
        %__MODULE__{__vector__: new_internal}
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
      #A<vec([1, 2, 3, 4, 5, 600, 7, 8])>
      iex> {nil, updated} = A.Vector.get_and_update(vector, 8, fn current_value ->
      ...>   {current_value, current_value && current_value * 100}
      ...> end); updated
      #A<vec([1, 2, 3, 4, 5, 6, 7, 8])>
      iex> {4, updated} = A.Vector.get_and_update(vector, 3, fn _ -> :pop end); updated
      #A<vec([1, 2, 3, 5, 6, 7, 8])>
      iex> {nil, updated} = A.Vector.get_and_update(vector, 8, fn _ -> :pop end); updated
      #A<vec([1, 2, 3, 4, 5, 6, 7, 8])>

  """
  @impl Access
  @spec get_and_update(t(v), index, (v -> {returned, v} | :pop)) :: {returned, t(v)}
        when v: value, returned: term
  def get_and_update(%__MODULE__{__vector__: internal}, index, fun)
      when is_integer(index) and is_function(fun, 1) do
    {returned, new_internal} = Raw.get_and_update(internal, index, fun)
    {returned, %__MODULE__{__vector__: new_internal}}
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
      #A<vec([1, 4, 9, 16, 25, 36, 49, 64, 81, 100])>

  """
  @spec map(t(v1), (v1 -> v2)) :: t(v2) when v1: value, v2: value
  def map(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 1) do
    %__MODULE__{
      __vector__: Raw.map(internal, fun)
    }
  end

  @doc """
  Filters the `vector`, i.e. return a new vector containing only elements
  for which `fun` returns a truthy (neither `false` nor `nil`) value.

  Runs in linear time.

  ## Examples

      iex> vector = A.Vector.new(1..100)
      iex> A.Vector.filter(vector, fn i -> rem(i, 13) == 0 end)
      #A<vec([13, 26, 39, 52, 65, 78, 91])>

  """
  @spec filter(t(val), (val -> boolean)) :: t(val) when val: value
  def filter(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 1) do
    %__MODULE__{
      __vector__: Raw.filter(internal, fun)
    }
  end

  @doc """
  Filters the `vector`, i.e. return a new vector containing only elements
  for which `fun` returns a falsy (either `false` or `nil`) value.

  Runs in linear time.

  ## Examples

      iex> vector = A.Vector.new(1..12)
      iex> A.Vector.reject(vector, fn i -> rem(i, 3) == 0 end)
      #A<vec([1, 2, 4, 5, 7, 8, 10, 11])>

  """
  @spec reject(t(val), (val -> boolean)) :: t(val) when val: value
  def reject(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 1) do
    %__MODULE__{
      __vector__: Raw.reject(internal, fun)
    }
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
      #A<vec([3, 6, 9, 12])>
      iex> rejected
      #A<vec([1, 2, 4, 5, 7, 8, 10, 11])>

  """
  @spec split_with(t(val), (val -> boolean)) :: {t(val), t(val)} when val: value
  def split_with(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 1) do
    # note: unlike filter/2, optimization does not bring much benefit
    {filtered, rejected} = internal |> Raw.to_list() |> Enum.split_with(fun)

    {
      %__MODULE__{__vector__: Raw.from_list(filtered)},
      %__MODULE__{__vector__: Raw.from_list(rejected)}
    }
  end

  @doc """
  Sorts the `vector` in the same way as `Enum.sort/1`.

  ## Examples

      iex> A.Vector.new(9..1) |> A.Vector.sort()
      #A<vec([1, 2, 3, 4, 5, 6, 7, 8, 9])>

  """
  @spec sort(t(val)) :: t(val) when val: value
  def sort(%__MODULE__{__vector__: internal}) do
    new_internal =
      internal
      |> Raw.to_list()
      |> Enum.sort()
      |> Raw.from_list()

    %__MODULE__{__vector__: new_internal}
  end

  @doc """
  Sorts the `vector` in the same way as `Enum.sort/2`.

  See `Enum.sort/2` documentation for detailled usage.

  ## Examples

      iex> A.Vector.new(1..9) |> A.Vector.sort(:desc)
      #A<vec([9, 8, 7, 6, 5, 4, 3, 2, 1])>

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
    new_internal =
      internal
      |> Raw.to_list()
      |> Enum.sort(fun)
      |> Raw.from_list()

    %__MODULE__{__vector__: new_internal}
  end

  @doc """
  Sorts the `vector` in the same way as `Enum.sort_by/3`.

  See `Enum.sort_by/3` documentation for detailled usage.

  ## Examples

      iex> vector = A.Vector.new(["some", "kind", "of", "monster"])
      iex> A.Vector.sort_by(vector, &byte_size/1)
      #A<vec(["of", "some", "kind", "monster"])>
      iex> A.Vector.sort_by(vector, &{byte_size(&1), String.first(&1)})
      #A<vec(["of", "kind", "some", "monster"])>

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
    new_internal =
      internal
      |> Raw.to_list()
      |> Enum.sort_by(mapper, sorter)
      |> Raw.from_list()

    %__MODULE__{__vector__: new_internal}
  end

  @doc """
  Returns a copy of the vector without any duplicated element.

  The first occurrence of each element is kept.

  ## Examples

      iex> A.Vector.new([1, 1, 2, 1, 2, 3, 2]) |> A.Vector.uniq()
      #A<vec([1, 2, 3])>

  """
  @spec uniq(t(val)) :: t(val) when val: value
  def uniq(%__MODULE__{__vector__: internal}) do
    new_internal =
      internal
      |> Raw.uniq_list()
      |> Raw.from_list()

    %__MODULE__{__vector__: new_internal}
  end

  @doc """
  Returns a copy of the vector without elements for which the function `fun` returned duplicate elements.

  The first occurrence of each element is kept.

  ## Examples

      iex> vector = A.Vector.new([x: 1, y: 2, z: 1])
      #A<vec([x: 1, y: 2, z: 1])>
      iex> A.Vector.uniq_by(vector, fn {_x, y} -> y end)
      #A<vec([x: 1, y: 2])>

  """
  @spec uniq_by(t(val), (val -> term)) :: t(val) when val: value
  def uniq_by(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 1) do
    new_internal =
      internal
      |> Raw.uniq_by_list(fun)
      |> Raw.from_list()

    %__MODULE__{__vector__: new_internal}
  end

  @doc """
  Returns a copy of the `vector` where all consecutive duplicated elements are collapsed to a single element.

  Elements are compared using `===/2`.

  If you want to remove all duplicated elements, regardless of order, see `uniq/1`.

  ## Examples

      iex> A.Vector.new([1, 2, 3, 3, 2, 1]) |> A.Vector.dedup()
      #A<vec([1, 2, 3, 2, 1])>
      iex> A.Vector.new([1, 1, 2, 2.0, :three, :three]) |> A.Vector.dedup()
      #A<vec([1, 2, 2.0, :three])>

  """
  @spec dedup(t(val)) :: t(val) when val: value
  def dedup(%__MODULE__{__vector__: internal}) do
    new_internal =
      internal
      |> Raw.dedup_list()
      |> Raw.from_list()

    %__MODULE__{__vector__: new_internal}
  end

  @doc """
  Returns a copy of the `vector` where all consecutive duplicated elements are collapsed to a single element.

  The function `fun` maps every element to a term which is used to determine if two elements are duplicates.

  ## Examples

      iex> vector = A.Vector.new([{1, :a}, {2, :b}, {2, :c}, {1, :a}])
      iex> Enum.dedup_by(vector, fn {x, _} -> x end)
      [{1, :a}, {2, :b}, {1, :a}]

      iex> vector = A.Vector.new([5, 1, 2, 3, 2, 1])
      iex> Enum.dedup_by(vector, fn x -> x > 2 end)
      [5, 1, 3, 2]


  """
  @spec dedup_by(t(val), (val -> term)) :: t(val) when val: value
  def dedup_by(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 1) do
    new_internal =
      internal
      |> Raw.to_list()
      |> Enum.dedup_by(fun)
      |> Raw.from_list()

    %__MODULE__{__vector__: new_internal}
  end

  @doc """
  Intersperses `separator` between each element of the `vector`.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(1..6) |> A.Vector.intersperse(nil)
      #A<vec([1, nil, 2, nil, 3, nil, 4, nil, 5, nil, 6])>

  """
  @spec intersperse(
          t(val),
          separator
        ) :: t(val | separator)
        when val: value, separator: value
  def intersperse(%__MODULE__{__vector__: internal}, separator) do
    new_internal =
      internal
      |> Raw.intersperse_list(separator)
      |> Raw.from_list()

    %__MODULE__{__vector__: new_internal}
  end

  @doc """
  Maps and intersperses the `vector` in one pass.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(1..6) |> A.Vector.map_intersperse(nil, &(&1 * 10))
      #A<vec([10, nil, 20, nil, 30, nil, 40, nil, 50, nil, 60])>

  """
  @spec map_intersperse(
          t(val),
          separator,
          (val -> mapped_val)
        ) :: t(mapped_val | separator)
        when val: value, separator: value, mapped_val: value
  def map_intersperse(%__MODULE__{__vector__: internal}, separator, mapper)
      when is_function(mapper, 1) do
    new_internal =
      internal
      |> Raw.map_intersperse_list(separator, mapper)
      |> Raw.from_list()

    %__MODULE__{__vector__: new_internal}
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

  @doc """
  Invokes `fun` for each element in the `vector` with the accumulator.

  Raises `A.Vector.EmptyError` if `vector` is empty.

  The first element of the `vector` is used as the initial value
  of the accumulator. Then the function is invoked with the next
  element and the accumulator. The result returned by the function
  is used as the accumulator for the next iteration, recursively.

  Since the first element of the `vector` is used as the initial
  value of the accumulator, `fun` will only be executed `n - 1` times
  where `n` is the size of the `vector`. This function won't call
  the specified function if `vector` only has one element.

  If you wish to use another value for the accumulator, use `reduce/3`.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new([1, 2, 3, 4, 5]) |> A.Vector.reduce(fn x, acc -> x * acc end)
      120
      iex> A.Vector.new([]) |> A.Vector.reduce(fn x, acc -> x * acc end)
      ** (A.Vector.EmptyError) empty vector error

  """
  @spec reduce(t(val), (val, val -> val)) :: val when val: value
  def reduce(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 2) do
    Raw.reduce(internal, fun)
  end

  @doc """
  Folds (reduces) the given `vector` from the left with the function `fun`.
  Requires an accumulator `acc`.

  Same as `foldl/3`.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(1..10) |> A.Vector.reduce(0, &+/2)
      55
      iex> A.Vector.new(1..10) |> A.Vector.reduce([], & [&1 | &2])
      [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]

  """
  defdelegate reduce(vector, acc, fun), to: __MODULE__, as: :foldl

  @doc """
  Invokes the given `fun` for each element in the `vector`.

  Returns `:ok`.

  Runs in linear time.

  ## Examples

      A.Vector.new(1..3) |> A.Vector.each(&IO.inspect/1)
      1
      2
      3
      :ok

  """
  @spec each(t(val), (val -> term)) :: :ok when val: value
  def each(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 1) do
    Raw.each(internal, fun)
    :ok
  end

  @doc """
  Returns the sum of all elements in the `vector`.

  Raises `ArithmeticError` if `vector` contains a non-numeric value.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(1..10) |> A.Vector.sum()
      55
      iex> A.Vector.new() |> A.Vector.sum()
      0

  """
  @spec sum(t(num)) :: num when num: number
  def sum(%__MODULE__{__vector__: internal}) do
    Raw.sum(internal)
  end

  @doc """
  Returns the product of all elements in the `vector`.

  Raises `ArithmeticError` if `vector` contains a non-numeric value.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(1..5) |> A.Vector.product()
      120
      iex> A.Vector.new() |> A.Vector.product()
      1

  """
  @spec product(t(num)) :: num when num: number
  def product(%__MODULE__{__vector__: internal}) do
    Raw.product(internal)
  end

  @doc """
  Joins the given `vector` into a string using `joiner` as a separator.

  If `joiner` is not passed at all, it defaults to an empty string.

  All elements in the `vector` must be convertible to a string, otherwise an error is raised.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(1..6) |> A.Vector.join()
      "123456"
      iex> A.Vector.new(1..6) |> A.Vector.join(" + ")
      "1 + 2 + 3 + 4 + 5 + 6"
      iex> A.Vector.new() |> A.Vector.join(" + ")
      ""

  """
  @spec join(t(val), String.t()) :: String.t() when val: String.Chars.t()
  def join(%__MODULE__{__vector__: internal}, joiner \\ "") when is_binary(joiner) do
    Raw.join_as_iodata(internal, joiner) |> IO.iodata_to_binary()
  end

  @doc """
  Maps and joins the given `vector` into a string using `joiner` as a separator.

  If `joiner` is not passed at all, it defaults to an empty string.

  `mapper` should only return values that are convertible to a string, otherwise an error is raised.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(1..6) |> A.Vector.map_join(fn x -> x * 10 end)
      "102030405060"
      iex> A.Vector.new(1..6) |> A.Vector.map_join(" + ", fn x -> x * 10 end)
      "10 + 20 + 30 + 40 + 50 + 60"
      iex> A.Vector.new() |> A.Vector.map_join(" + ", fn x -> x * 10 end)
      ""

  """
  @spec map_join(t(val), String.t(), (val -> String.Chars.t())) :: String.t()
        when val: value
  def map_join(%__MODULE__{__vector__: internal}, joiner \\ "", mapper)
      when is_binary(joiner) and is_function(mapper, 1) do
    internal
    |> Raw.map(mapper)
    |> Raw.join_as_iodata(joiner)
    |> IO.iodata_to_binary()
  end

  @doc """
  Returns the maximal element in the `vector` according to Erlang's term ordering.

  If multiple elements are considered maximal, the first one that was found is returned.

  Raises a `A.Vector.EmptyError` if empty.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(1..10) |> A.Vector.max()
      10
      iex> A.Vector.new() |> A.Vector.max()
      ** (A.Vector.EmptyError) empty vector error

  """
  @spec max(t(val)) :: val when val: value
  def max(%__MODULE__{__vector__: internal}) do
    Raw.max(internal)
  end

  @doc """
  Returns the maximal element in the `vector` using `sorter` to compare elements.

  `sorter` can either be an arity-2 function returning a boolean or a module
  implementing a `compare/2` function, such as `Date.compare/2`.

  See documentation for `Enum.max/3` for more explanations.

  Raises a `A.Vector.EmptyError` if empty.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new([~D[2017-03-31], ~D[2017-04-01]]) |> A.Vector.max()
      ~D[2017-03-31]
      iex> A.Vector.new([~D[2017-03-31], ~D[2017-04-01]]) |> A.Vector.max(Date)
      ~D[2017-04-01]
      iex> A.Vector.new() |> A.Vector.max(Date)
      ** (A.Vector.EmptyError) empty vector error

  """
  @spec max(t(val), (val, val -> boolean) | module) :: val when val: value
  def max(%__MODULE__{__vector__: internal}, sorter) do
    Raw.custom_min_max(internal, max_sort_fun(sorter))
  end

  defp max_sort_fun(sorter) when is_function(sorter, 2), do: sorter
  defp max_sort_fun(module) when is_atom(module), do: &(module.compare(&1, &2) != :lt)

  @doc """
  Returns the minimal element in the `vector` according to Erlang's term ordering.

  If multiple elements are considered minimal, the first one that was found is returned.

  Raises a `A.Vector.EmptyError` if empty.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(1..10) |> A.Vector.min()
      1
      iex> A.Vector.new() |> A.Vector.min()
      ** (A.Vector.EmptyError) empty vector error

  """
  @spec min(t(val)) :: val when val: value
  def min(%__MODULE__{__vector__: internal}) do
    Raw.min(internal)
  end

  @doc """
  Returns the minimal element in the `vector` using `sorter` to compare elements.

  `sorter` can either be an arity-2 function returning a boolean or a module
  implementing a `compare/2` function, such as `Date.compare/2`.

  See documentation for `Enum.min/3` for more explanations.

  Raises a `A.Vector.EmptyError` if empty.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new([~D[2017-03-31], ~D[2017-04-01]]) |> A.Vector.min()
      ~D[2017-04-01]
      iex> A.Vector.new([~D[2017-03-31], ~D[2017-04-01]]) |> A.Vector.min(Date)
      ~D[2017-03-31]
      iex> A.Vector.new() |> A.Vector.min(Date)
      ** (A.Vector.EmptyError) empty vector error

  """
  @spec min(t(val), (val, val -> boolean) | module) :: val when val: value
  def min(%__MODULE__{__vector__: internal}, sorter) do
    Raw.custom_min_max(internal, min_sort_fun(sorter))
  end

  defp min_sort_fun(sorter) when is_function(sorter, 2), do: sorter
  defp min_sort_fun(module) when is_atom(module), do: &(module.compare(&1, &2) != :gt)

  @doc """
  Returns the minimal element in the `vector` as calculated by the given `fun`.

  By default, the comparison is done with the `<=` sorter function.
  If multiple elements are considered minimal, the first one that
  was found is returned. If you want the last element considered
  minimal to be returned, the sorter function should not return `true`
  for equal elements.

  Raises a `A.Vector.EmptyError` if empty.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(["a", "aa", "aaa"]) |> A.Vector.min_by(&String.length/1)
      "a"
      iex> A.Vector.new(["a", "aa", "aaa", "b", "bbb"]) |> A.Vector.min_by(&String.length/1)
      "a"
      iex> A.Vector.new([]) |> A.Vector.min_by(&String.length/1)
      ** (ArgumentError) argument error

  The fact this function uses Erlang's term ordering means that the
  comparison is structural and not semantic. Therefore, if you want
  to compare structs, most structs provide a "compare" function, such as
  `Date.compare/2`, which receives two structs and returns `:lt` (less-than),
  `:eq` (equal to), and `:gt` (greater-than). If you pass a module as the
  sorting function, Elixir will automatically use the `compare/2` function
  of said module:

      iex> users = A.Vector.new([
      ...>   %{name: "Ellis", birthday: ~D[1943-05-11]},
      ...>   %{name: "Lovelace", birthday: ~D[1815-12-10]},
      ...>   %{name: "Turing", birthday: ~D[1912-06-23]}
      ...> ])
      iex> A.Vector.min_by(users, &(&1.birthday), Date)
      %{name: "Lovelace", birthday: ~D[1815-12-10]}

  """
  @spec min_by(t(val), (val -> key), (key, key -> boolean) | module) :: val
        when val: value, key: term
  def min_by(%__MODULE__{__vector__: internal}, fun, sorter \\ &<=/2) when is_function(fun, 1) do
    Raw.custom_min_max_by(internal, fun, min_sort_fun(sorter))
  end

  @doc """
  Returns the maximal element in the `vector` as calculated by the given `fun`.

  By default, the comparison is done with the `>=` sorter function.
  If multiple elements are considered maximal, the first one that
  was found is returned. If you want the last element considered
  maximal to be returned, the sorter function should not return `true`
  for equal elements.

  Raises a `A.Vector.EmptyError` if empty.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(["a", "aa", "aaa"]) |> A.Vector.max_by(&String.length/1)
      "aaa"
      iex> A.Vector.new(["a", "aa", "aaa", "b", "bbb"]) |> A.Vector.max_by(&String.length/1)
      "aaa"
      iex> A.Vector.new([]) |> A.Vector.max_by(&String.length/1)
      ** (ArgumentError) argument error

  The fact this function uses Erlang's term ordering means that the
  comparison is structural and not semantic. Therefore, if you want
  to compare structs, most structs provide a "compare" function, such as
  `Date.compare/2`, which receives two structs and returns `:lt` (less-than),
  `:eq` (equal to), and `:gt` (greater-than). If you pass a module as the
  sorting function, Elixir will automatically use the `compare/2` function
  of said module:

      iex> users = A.Vector.new([
      ...>   %{name: "Ellis", birthday: ~D[1943-05-11]},
      ...>   %{name: "Lovelace", birthday: ~D[1815-12-10]},
      ...>   %{name: "Turing", birthday: ~D[1912-06-23]}
      ...> ])
      iex> A.Vector.max_by(users, &(&1.birthday), Date)
      %{name: "Ellis", birthday: ~D[1943-05-11]}

  """
  @spec max_by(t(val), (val -> key), (key, key -> boolean) | module) :: val
        when val: value, key: term
  def max_by(%__MODULE__{__vector__: internal}, fun, sorter \\ &>=/2) when is_function(fun, 1) do
    Raw.custom_min_max_by(internal, fun, max_sort_fun(sorter))
  end

  @doc """
  Returns a map with keys as unique elements of `vector` and values
  as the count of every element.

  ## Examples

      iex> vector = A.Vector.new(~w{ant buffalo ant ant buffalo dingo})
      iex> A.Vector.frequencies(vector)
      %{"ant" => 3, "buffalo" => 2, "dingo" => 1}

  """
  @spec frequencies(t(val)) :: %{optional(val) => non_neg_integer} when val: value
  def frequencies(%__MODULE__{__vector__: internal}) do
    Raw.frequencies(internal)
  end

  @doc """
  Returns a map with keys as unique elements given by `key_fun` and values
  as the count of every element from the `vector`.

  ## Examples

      iex> vector = A.Vector.new(~w{aa aA bb cc})
      iex> A.Vector.frequencies_by(vector, &String.downcase/1)
      %{"aa" => 2, "bb" => 1, "cc" => 1}

      iex> vector = A.Vector.new(~w{aaa aA bbb cc c})
      iex> A.Vector.frequencies_by(vector, &String.length/1)
      %{3 => 2, 2 => 2, 1 => 1}

  """
  @spec frequencies_by(t(val), (val -> key)) :: %{optional(key) => non_neg_integer}
        when val: value, key: any
  def frequencies_by(%__MODULE__{__vector__: internal}, key_fun) when is_function(key_fun, 1) do
    Raw.frequencies_by(internal, key_fun)
  end

  @doc """
  Splits the `vector` into groups based on `key_fun`.

  The result is a map where each key is given by `key_fun`
  and each value is a list of elements given by `value_fun`.

  The order of elements within each list is preserved from the `vector`.
  However, like all maps, the resulting map is unordered.

  ## Examples

      iex> vector = A.Vector.new(~w{ant buffalo cat dingo})
      iex> A.Vector.group_by(vector, &String.length/1)
      %{3 => ["ant", "cat"], 5 => ["dingo"], 7 => ["buffalo"]}
      iex> A.Vector.group_by(vector, &String.length/1, &String.first/1)
      %{3 => ["a", "c"], 5 => ["d"], 7 => ["b"]}

  """
  @spec group_by(t(val), (val -> key), (val -> mapped_val)) :: %{optional(key) => [mapped_val]}
        when val: value, key: any, mapped_val: any
  def group_by(%__MODULE__{__vector__: internal}, key_fun, value_fun \\ fn x -> x end)
      when is_function(key_fun, 1) and is_function(value_fun, 1) do
    Raw.group_by(internal, key_fun, value_fun)
  end

  @doc """
  Returns `true` if at least one element in `enumerable` is truthy.

  Runs in linear time, but stops evaluating when finds the first truthy value.

  Iterates over the `enumerable`, and when it finds a truthy value
  (neither `false` nor `nil`), `true` is returned.
  In all other cases `false` is returned.

  ## Examples

      iex> A.Vector.new([false, false, true]) |> A.Vector.any?()
      true
      iex> A.Vector.new([false, nil]) |> A.Vector.any?()
      false
      iex> A.Vector.new() |> A.Vector.any?()
      false

  """
  @spec any?(t(val)) :: boolean when val: value
  def any?(%__MODULE__{__vector__: internal}) do
    Raw.any?(internal)
  end

  @doc """
  Returns `true` if `fun.(element)` is truthy for at least one element in `enumerable`.

  Runs in linear time, but stops evaluating when finds the first truthy value.

  Iterates over the `enumerable` and invokes `fun` on each element. When an invocation
  of `fun` returns a truthy value (neither `false` nor `nil`) iteration stops immediately
  and `true` is returned. In all other cases `false` is returned.

  ## Examples

      iex> vector = A.Vector.new(1..10)
      iex> A.Vector.any?(vector, fn i -> rem(i, 7) == 0 end)
      true
      iex> A.Vector.any?(vector, fn i -> rem(i, 13) == 0 end)
      false
      iex> A.Vector.new() |> A.Vector.any?(fn i -> rem(i, 7) == 0 end)
      false

  """
  @spec any?(t(val), (val -> as_boolean(term))) :: boolean when val: value
  def any?(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 1) do
    Raw.any?(internal, fun)
  end

  @doc """
  Returns `true` if all elements in `enumerable` are truthy.

  Runs in linear time, but stops evaluating when finds the first falsy value.

  Iterates over the `enumerable`, and when it finds a falsy value (`false` or `nil`),
  `false` is returned. In all other cases `true` is returned.

  ## Examples

      iex> A.Vector.new([true, true, false]) |> A.Vector.all?()
      false
      iex> A.Vector.new([true, [], %{}, 5]) |> A.Vector.all?()
      true
      iex> A.Vector.new() |> A.Vector.all?()
      true

  """
  @spec all?(t(val)) :: boolean when val: value
  def all?(%__MODULE__{__vector__: internal}) do
    Raw.all?(internal)
  end

  @doc """
  Returns `true` if `fun.(element)` is truthy for all elements in `enumerable`.

  Runs in linear time, but stops evaluating when finds the first falsy value.

  Iterates over the `enumerable` and invokes `fun` on each element. When an invocation
  of `fun` returns a falsy value (`false` or `nil`) iteration stops immediately and
  `false` is returned. In all other cases `true` is returned.

  ## Examples

      iex> vector = A.Vector.new(1..10)
      iex> A.Vector.all?(vector, fn i -> rem(i, 13) != 0 end)
      true
      iex> A.Vector.all?(vector, fn i -> rem(i, 7) != 0 end)
      false
      iex> A.Vector.new() |> A.Vector.all?(fn i -> rem(i, 7) != 0 end)
      true

  """
  @spec all?(t(val), (val -> as_boolean(term))) :: boolean when val: value
  def all?(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 1) do
    Raw.all?(internal, fun)
  end

  @doc """
  Returns the first element of `vector` for which `fun` returns a truthy value (neither `nil` nor `false`).

  If no such element is found, returns `default`.

  Runs in linear time, but stops evaluating when finds the first truthy value.

  ## Examples

      iex> vector = A.Vector.new(2..10)
      iex> A.Vector.find(vector, fn i -> rem(49, i) == 0 end)
      7
      iex> A.Vector.find(vector, fn i -> rem(13, i) == 0 end)
      nil

  """
  @spec find(t(val), default, (val -> as_boolean(term))) :: val | default
        when val: value, default: value
  def find(%__MODULE__{__vector__: internal}, default \\ nil, fun) when is_function(fun, 1) do
    case Raw.find(internal, fun) do
      {:ok, value} -> value
      nil -> default
    end
  end

  @doc """
  Similar to `find/3`, but returns the value of the function invocation instead of the element itself.

  The return value is considered to be found when the result is truthy (neither `nil` nor `false`).

  Runs in linear time, but stops evaluating when finds the first truthy value.

  ## Examples

      iex> vector = A.Vector.new(["Ant", "Bat", "Cat", "Dinosaur"])
      iex> A.Vector.find_value(vector, fn s -> String.at(s, 4) end)
      "s"
      iex> A.Vector.find_value(vector, fn s -> String.at(s, 10) end)
      nil

  """
  @spec find_value(t(val), default, (val -> new_val)) :: new_val | default
        when val: value, new_val: value, default: value
  def find_value(%__MODULE__{__vector__: internal}, default \\ nil, fun)
      when is_function(fun, 1) do
    Raw.find_value(internal, fun) || default
  end

  @doc """
  Similar to `find/3`, but returns the index (zero-based) of the element instead of the element itself.

  If no such element is found, returns `nil`.

  Runs in linear time, but stops evaluating when finds the first truthy value.

  ## Examples

      iex> vector = A.Vector.new(["Ant", "Bat", "Cat", "Dinosaur"])
      iex> A.Vector.find_index(vector, fn s -> String.first(s) == "C" end)
      2
      iex> A.Vector.find_index(vector, fn s -> String.first(s) == "Z" end)
      nil

  """
  @spec find_index(t(val), (val -> as_boolean(term))) :: non_neg_integer | nil when val: value
  def find_index(%__MODULE__{__vector__: internal}, fun) when is_function(fun, 1) do
    Raw.find_index(internal, fun)
  end

  @doc """
  Returns the `vector` in reverse order.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(1..12) |> A.Vector.reverse()
      #A<vec([12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1])>

  """
  @spec reverse(t(val)) :: t(val) when val: value
  def reverse(%__MODULE__{__vector__: internal}) do
    internal
    |> Raw.to_reverse_list()
    |> new()
  end

  @doc """
  Returns a subset of the given `vector` by `index_range`.

  Works the same as `Enum.slice/2`, see its documentation for more details.

  Runs in linear time regarding the size of the returned subset.

  ## Examples

      iex> A.Vector.new(0..100) |> A.Vector.slice(80..90)
      #A<vec([80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90])>
      iex> A.Vector.new(0..100) |> A.Vector.slice(-40..-30)
      #A<vec([61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71])>
      iex> A.Vector.new([:only_one]) |> A.Vector.slice(0..1000)
      #A<vec([:only_one])>

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
        |> new()
    end
  end

  @doc """
  Returns a subset of the given `vector`, from `start_index` (zero-based)
  with `amount number` of elements if available.

  Works the same as `Enum.slice/3`, see its documentation for more details.

  Runs in linear time regarding the size of the returned subset.

  ## Examples

      iex> A.Vector.new(0..100) |> A.Vector.slice(80, 10)
      #A<vec([80, 81, 82, 83, 84, 85, 86, 87, 88, 89])>
      iex> A.Vector.new(0..100) |> A.Vector.slice(-40, 10)
      #A<vec([61, 62, 63, 64, 65, 66, 67, 68, 69, 70])>
      iex> A.Vector.new([:only_one]) |> A.Vector.slice(0, 1000)
      #A<vec([:only_one])>

  """
  @spec slice(t(val), index, non_neg_integer) :: t(val) when val: value
  def slice(%__MODULE__{__vector__: internal} = vector, start_index, amount)
      when is_integer(start_index) and is_integer(amount) and amount >= 0 do
    if start_index == 0 or start_index == -Raw.size(internal) do
      new_internal = Raw.take(internal, amount)
      %__MODULE__{__vector__: new_internal}
    else
      vector
      |> Enum.slice(start_index, amount)
      |> new()
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
      #A<vec([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])>
      iex> A.Vector.new([:only_one]) |> A.Vector.take(1000)
      #A<vec([:only_one])>
      iex> A.Vector.new(0..10) |> A.Vector.take(-5)
      #A<vec([6, 7, 8, 9, 10])>

  """
  @spec take(t(val), integer) :: t(val) when val: value
  def take(%__MODULE__{__vector__: internal}, amount) when is_integer(amount) do
    new_internal = do_take(internal, amount)
    %__MODULE__{__vector__: new_internal}
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
      #A<vec([10, 11, 12, 13, 14, 15])>
      iex> A.Vector.new(0..5) |> A.Vector.drop(0)
      #A<vec([0, 1, 2, 3, 4, 5])>
      iex> A.Vector.new(0..10) |> A.Vector.drop(-5)
      #A<vec([0, 1, 2, 3, 4, 5])>

  """
  @spec drop(t(val), integer) :: t(val) when val: value
  def drop(%__MODULE__{__vector__: internal}, amount) when is_integer(amount) do
    new_internal = do_drop(internal, amount)
    %__MODULE__{__vector__: new_internal}
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
      "{#A<vec([1, 2])>, #A<vec([3])>}"
      iex> A.Vector.split(vector, 10) |> inspect()
      "{#A<vec([1, 2, 3])>, #A<vec([])>}"
      iex> A.Vector.split(vector, 0) |> inspect()
      "{#A<vec([])>, #A<vec([1, 2, 3])>}"
      iex> A.Vector.split(vector, -1) |> inspect()
      "{#A<vec([1, 2])>, #A<vec([3])>}"
      iex> A.Vector.split(vector, -5) |> inspect()
      "{#A<vec([])>, #A<vec([1, 2, 3])>}"

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
        {%__MODULE__{__vector__: taken}, %__MODULE__{__vector__: dropped}}
    end
  end

  @doc """
  Takes the elements from the beginning of the `vector` while `fun` returns a truthy value.

  Runs in linear time regarding the size of the returned subset.

  ## Examples

      iex> A.Vector.new(1..100) |> A.Vector.take_while(fn x -> x < 7 end)
      #A<vec([1, 2, 3, 4, 5, 6])>
      iex> A.Vector.new([1, true, %{}, nil, "abc"]) |> A.Vector.take_while(fn x -> x end)
      #A<vec([1, true, %{}])>

  """
  @spec take_while(t(val), (val -> as_boolean(term()))) :: t(val) when val: value
  def take_while(%__MODULE__{__vector__: internal} = vector, fun) when is_function(fun, 1) do
    case Raw.find_falsy_index(internal, fun) do
      nil ->
        vector

      index ->
        new_internal = Raw.take(internal, index)
        %__MODULE__{__vector__: new_internal}
    end
  end

  @doc """
  Drops elements at the beginning of the `vector` while `fun` returns a truthy value.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(1..10) |> A.Vector.drop_while(fn x -> x < 7 end)
      #A<vec([7, 8, 9, 10])>
      iex> A.Vector.new([1, true, %{}, nil, "abc"]) |> A.Vector.drop_while(fn x -> x end)
      #A<vec([nil, "abc"])>

  """
  @spec drop_while(t(val), (val -> as_boolean(term()))) :: t(val) when val: value
  def drop_while(%__MODULE__{__vector__: internal} = vector, fun) when is_function(fun, 1) do
    case Raw.find_falsy_index(internal, fun) do
      nil ->
        %__MODULE__{__vector__: @empty_raw}

      0 ->
        vector

      index ->
        size = Raw.size(internal)

        new_internal =
          internal
          |> Raw.slice(index, size - 1)
          |> Raw.from_list()

        %__MODULE__{__vector__: new_internal}
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
      #A<vec([1, 2, 3, 4, 5, 6])>
      iex> dropped
      #A<vec([7, 8, 9, 10])>

  """
  @spec split_while(t(val), (val -> as_boolean(term()))) :: {t(val), t(val)} when val: value
  def split_while(%__MODULE__{__vector__: internal} = vector, fun) when is_function(fun, 1) do
    case Raw.find_falsy_index(internal, fun) do
      nil ->
        {vector, %__MODULE__{__vector__: @empty_raw}}

      0 ->
        {%__MODULE__{__vector__: @empty_raw}, vector}

      index ->
        size = Raw.size(internal)

        taken = Raw.take(internal, index)

        dropped =
          internal
          |> Raw.slice(index, size - 1)
          |> Raw.from_list()

        {%__MODULE__{__vector__: taken}, %__MODULE__{__vector__: dropped}}
    end
  end

  @doc """
  Returns the `vector` with each element wrapped in a tuple alongside its index.

  If an `offset` is given, we will index from the given `offset` instead of from zero.

  Runs in linear time.

  ## Examples

      iex> A.Vector.new(["foo", "bar", "baz"]) |> A.Vector.with_index()
      #A<vec([{"foo", 0}, {"bar", 1}, {"baz", 2}])>
      iex> A.Vector.new() |> A.Vector.with_index()
      #A<vec([])>
      iex> A.Vector.new(["foo", "bar", "baz"]) |> A.Vector.with_index(100)
      #A<vec([{"foo", 100}, {"bar", 101}, {"baz", 102}])>

  """
  @spec with_index(t(val), index) :: t({val, index}) when val: value
  def with_index(%__MODULE__{__vector__: internal}, offset \\ 0) when is_integer(offset) do
    new_internal = Raw.with_index(internal, offset)
    %__MODULE__{__vector__: new_internal}
  end

  @doc """
  Returns a random element of a `vector`.

  Raises `Vector.EmptyError` if `vector` is empty.

  Like `Enum.random/1`, this function uses Erlang's [`:rand` module](http://www.erlang.org/doc/man/rand.html)
  to calculate the random value.
  Check its documentation for setting a different random algorithm or a different seed.

  Runs in effective constant time, and is therefore more efficient than `Enum.random/1` on lists.

  ## Examples

      # Although not necessary, let's seed the random algorithm
      iex>:rand.seed(:exrop, {101, 102, 103})
      iex> A.Vector.new([1, 2, 3]) |> A.Vector.random()
      3
      iex> A.Vector.new([1, 2, 3]) |> A.Vector.random()
      2
      iex> A.Vector.new(1..1_000) |> A.Vector.random()
      846
      iex> A.Vector.new([]) |> A.Vector.random()
      ** (A.Vector.EmptyError) empty vector error

  """
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
      #A<vec([7, 2])>
      iex> A.Vector.new([:foo, :bar, :baz]) |> A.Vector.take_random(100)
      #A<vec([:bar, :baz, :foo])>

  """
  @spec take_random(t(val), non_neg_integer) :: t(val) when val: value
  def take_random(%__MODULE__{__vector__: internal}, amount)
      when is_integer(amount) and amount >= 0 do
    new_internal = Raw.take_random(internal, amount)
    %__MODULE__{__vector__: new_internal}
  end

  @doc """
  Returns a new vector with the elements of `vector` shuffled.

  See `Enum.shuffle/1` for notes on implementation and random seed.

  ## Examples

      # Although not necessary, let's seed the random algorithm
      iex> :rand.seed(:exrop, {1, 2, 3})
      iex> A.Vector.new([1, 2, 3]) |> A.Vector.shuffle()
      #A<vec([3, 1, 2])>
      iex> A.Vector.new([1, 2, 3]) |> A.Vector.shuffle()
      #A<vec([1, 3, 2])>

  """
  @spec shuffle(t(val)) :: t(val) when val: value
  def shuffle(%__MODULE__{__vector__: internal}) do
    # Note: benchmarks suggest that this is already fast without further optimization
    new_internal =
      internal
      |> Raw.to_list()
      |> Enum.shuffle()
      |> Raw.from_list()

    %__MODULE__{__vector__: new_internal}
  end

  @doc """
  Zips corresponding elements from two vectors into one vector of tuples.

  The size of the returned vector is the one of the smallest of the input vectors.

  Runs in linear time.

      iex> A.Vector.zip(A.Vector.new([1, 2, 3]), A.Vector.new([:a, :b, :c]))
      #A<vec([{1, :a}, {2, :b}, {3, :c}])>
      iex> A.Vector.zip(A.Vector.new(0..100), A.Vector.new([:a, :b, :c]))
      #A<vec([{0, :a}, {1, :b}, {2, :c}])>

  """
  @spec zip(t(val1), t(val2)) :: t({val1, val2}) when val1: value, val2: value
  def zip(%__MODULE__{__vector__: internal1}, %__MODULE__{__vector__: internal2}) do
    new_internal = Raw.zip(internal1, internal2)

    %__MODULE__{__vector__: new_internal}
  end

  @doc """
  Opposite of `zip/2`. Extracts two-element tuples from the given `vector` and groups them together.

  It takes a `vector` with elements being two-element tuples and returns a tuple with two vectors,
  each of which is formed by the first and second element of each tuple, respectively.

  This function fails unless `vector` only contains tuples with exactly two elements in each tuple.

  Runs in linear time.

      iex> {vector1, vector2} = A.Vector.new([{1, :a}, {2, :b}, {3, :c}]) |> A.Vector.unzip()
      iex> vector1
      #A<vec([1, 2, 3])>
      iex> vector2
      #A<vec([:a, :b, :c])>

  """
  @spec unzip(t({val1, val2})) :: {t(val1), t(val2)} when val1: value, val2: value
  def unzip(%__MODULE__{__vector__: internal}) do
    {internal1, internal2} = Raw.unzip(internal)

    {%__MODULE__{__vector__: internal1}, %__MODULE__{__vector__: internal2}}
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(vector, opts) do
      opts = %Inspect.Opts{opts | charlists: :as_lists}
      concat(["#A<vec(", Inspect.List.inspect(A.Vector.to_list(vector), opts), ")>"])
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
      internal
      |> A.Vector.Raw.to_list()
      |> Enumerable.List.reduce(acc, fun)
    end
  end

  defimpl Collectable do
    alias A.Vector.Raw

    def into(%A.Vector{__vector__: internal}) do
      {{[], internal}, &collector_fun/2}
    end

    @compile {:inline, collector_fun: 2}
    defp collector_fun({acc, internal}, {:cont, value}), do: {[value | acc], internal}

    defp collector_fun({acc, internal}, :done) do
      new_internal = Raw.concat(internal, :lists.reverse(acc))
      %A.Vector{__vector__: new_internal}
    end

    defp collector_fun(_acc, :halt), do: :ok
  end

  if Code.ensure_loaded?(Jason.Encoder) do
    defimpl Jason.Encoder do
      def encode(vector, opts) do
        vector |> A.Vector.to_list() |> Jason.Encode.list(opts)
      end
    end
  end
end
