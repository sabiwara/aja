defmodule A.Array do
  @moduledoc ~S"""
  A wrapper of erlang's [`:array` module](http://erlang.org/doc/man/array.html) offering an
  elixir-friendly API and interoperability.

  [Arrays are data structures](https://en.wikipedia.org/wiki/Array_data_structure) able to, unlilke lists:
  - access the i-th element (get/set) in constant time
  - access the size in constant time

  Arrays are often the go-to data structure in imperative languages, they are however not so
  [easy to work with](https://learnyousomeerlang.com/a-short-visit-to-common-data-structures#arrays)
  in functional languages like Elixir.
  Arrays cannot be:
  - efficiently built recursively while staying immutable
  - pattern matched upon
  - easily compared...

  For these reasons, lists should still be the go-to data structure for most use cases.
  But some algorithms might justify the use of arrays.
  If you think you are in such a case, make sure to benchmark it first to confirm.

  `A.Array` aims at simplifying working with arrays from elixir over erlang's `:array`.
  It adds:
  - implementation of the `Inspect`, `Enumerable`, `Collectable` protocols
  - implementation of the `Access` behaviour
  - optionally implements the `Jason.Encoder` protocol if `Jason` is installed
  - an API more consistent with elixir standard library
  - pipe-operator friendliness
  - more user-friendly error messages
  - convenience functions to append: `A.Array.append/2` and `A.Array.append_many/2`

  An array can be constructed using `A.Array.new/0`:
      iex> A.Array.new()
      #A.Array<[]>

  Elements in an array don't have to be of the same type and they can be
  populated from an [enumerable](`t:Enumerable.t/0`) using `A.Array.new/1`:
      iex> A.Array.new([1, :two, {"three"}])
      #A.Array<[1, :two, {"three"}]>

  ## Dynamic size, resizing

  Arrays can be sparse and will automatically grow if needed:
      iex> A.Array.new(1..3) |> A.Array.set(7, 45)
      #A.Array<[1, 2, 3, nil, nil, nil, nil, 45]>

  They are populated by the default value (`nil` by default):
      iex> A.Array.new(1..3, default: 0) |> A.Array.set(7, 45)
      #A.Array<[1, 2, 3, 0, 0, 0, 0, 45], default: 0>
      iex> A.Array.new(1..3, default: 0) |> A.Array.default_value()
      0

  From the [original documentation](erlang.org/doc/man/array.html):
  > There is no difference between an unset entry and an entry which
    has been explicitly set to the same value as the default one.
    If you need to differentiate between unset and set entries,
    you must make sure that the default value cannot be confused with the
    values of set entries.

  ## Fixed-size arrays

  Arrays can be of fixed size to avoid growing or accessing out-of-bounds elements.
  They can be directly created with the `fixed?` option, or fixed later by invoking `A.Array.fix/1`.
      iex> fixed = A.Array.new(1..3, fixed?: true)
      #A.Array<[1, 2, 3], fixed?: true>
      iex> ^fixed = A.Array.new(1..3) |> A.Array.fix()
      #A.Array<[1, 2, 3], fixed?: true>
      iex> A.Array.fixed?(fixed)
      true

  For fixed-size arrays, read or write access through an index must always be below its `size`.
      iex> A.Array.new(1..3, fixed?: true) |> A.Array.set(7, 45)
      ** (ArgumentError) cannot access index above fixed size, expected index < 3, got: 7

  For read access as well:
      iex> A.Array.new(1..3, fixed?: true) |> A.Array.get(7)
      ** (ArgumentError) cannot access index above fixed size, expected index < 3, got: 7

  The opposite operation is `A.Array.relax/1`:

      iex> relaxed = A.Array.new(1..3, fixed?: true) |> A.Array.relax()
      #A.Array<[1, 2, 3]>
      iex> A.Array.fixed?(relaxed)
      false
      iex> A.Array.set(relaxed, 7, 45)
      #A.Array<[1, 2, 3, nil, nil, nil, nil, 45]>

  ## Access behaviour

  `A.Array` implements the `Access` behaviour.

      iex> array = A.Array.new(1..5)
      iex> array[1]
      2
      iex> put_in(array[2], "updated")
      #A.Array<[1, 2, "updated", 4, 5]>
      iex> {4, updated} = pop_in(array[3])
      iex> updated
      #A.Array<[1, 2, 3, nil, 5]>

  ## With `Jason`

      iex> A.Array.new(1..5) |> A.Array.set(9, 10) |> Jason.encode!()
      "[1,2,3,4,5,null,null,null,null,10]"

  ## Pattern-match and opaque type

  An `A.Array` is represented internally using the `%A.Array{}` struct. This struct
  can be used whenever there's a need to pattern match on something being a `A.Array`:
      iex> match?(%A.Array{}, A.Array.new())
      true

  Note, however, than `A.Array` is an [opaque type](https://hexdocs.pm/elixir/typespecs.html#user-defined-types):
  its struct internal fields must not be accessed directly.
  Use the functions in this module to perform operations on arrays, or the `Enum` module.
  """

  @behaviour Access

  @type index :: non_neg_integer
  @type value :: term

  @opaque t(value) :: %__MODULE__{internal: :array.array(value)}
  @type t :: t(term)

  defstruct internal: :array.new(default: nil)

  @doc ~S"""
  Returns a new empty array.

  ## Examples
      iex> A.Array.new()
      #A.Array<[]>

  """
  @spec new :: t
  def new(), do: %A.Array{}

  @doc ~S"""
  Creates an array from an enumerable.

  ## Examples
      iex> A.Array.new([:b, :a, 3])
      #A.Array<[:b, :a, 3]>
      iex> A.Array.new(1..7)
      #A.Array<[1, 2, 3, 4, 5, 6, 7]>
      iex> A.Array.new('hello', default: ?\s)
      #A.Array<[104, 101, 108, 108, 111], default: 32>
      iex> A.Array.new('hello', default: ?\s, fixed?: true)
      #A.Array<[104, 101, 108, 108, 111], default: 32, fixed?: true>

  ## Underlying erlang function: `:array.from_list/1`
      iex> :array.from_list([1, 2, 3, 5, 8])
      {:array, 5, 10, :undefined, {1, 2, 3, 5, 8, :undefined, :undefined, :undefined, :undefined, :undefined}}
      iex> :array.from_list(["abc", "def"], "")
      {:array, 2, 10, "", {"abc", "def", "", "", "", "", "", "", "", ""}}
  """
  @spec new(Enumerable.t(), keyword) :: t
  def new(enumerable)

  def new(%__MODULE__{} = array), do: array

  def new(enumerable, opts \\ []) do
    default = Keyword.get(opts, :default)

    internal =
      enumerable
      |> Enum.to_list()
      |> :array.from_list(default)

    internal =
      if validate_fixed_keyword(opts) do
        :array.fix(internal)
      else
        internal
      end

    %A.Array{internal: internal}
  end

  @doc ~S"""
  Returns an array with `elem` repeated `n` times.

  Sets `elem` as the default value.
  Mirroring `List.duplicate/2`.

  ## Examples
      iex> A.Array.duplicate(0, 9)
      #A.Array<[0, 0, 0, 0, 0, 0, 0, 0, 0], default: 0>
      iex> A.Array.duplicate("hi", 3, fixed?: true)
      #A.Array<["hi", "hi", "hi"], default: "hi", fixed?: true>

  ## Underlying erlang function: `:array.new/1`
      iex> :array.new(size: 9, default: 0)
      {:array, 9, 0, 0, 10}
      iex> :array.new(size: 3, default: "hi", fixed: false)
      {:array, 3, 10, "hi", 10}

  Note: in the erlang version, the array is fixed size by default.
  """
  @spec new(val, non_neg_integer()) :: t(val) when val: value
  def duplicate(elem, n, opts \\ []) when is_integer(n) and n >= 0 do
    internal = :array.new(size: n, default: elem)

    internal =
      if validate_fixed_keyword(opts) do
        internal
      else
        :array.relax(internal)
      end

    %A.Array{internal: internal}
  end

  @doc ~S"""
  Returns the number of elements in `array`.

  ## Examples
      iex> array = A.Array.new([1, 2, 3, 5, 8])
      iex> A.Array.size(array)
      5

  ## Underlying erlang function: `:array.size/1`
      iex> array = :array.from_list([1, 2, 3, 5, 8])
      iex> :array.size(array)
      5
  """
  @spec size(t) :: non_neg_integer
  def size(%A.Array{internal: internal}) do
    :array.size(internal)
  end

  @doc ~S"""
  Returns the default value of `array`.

  ## Examples
      iex> A.Array.default_value(A.Array.new([]))
      nil
      iex> A.Array.default_value(A.Array.new([], default: 0))
      0

  ## Underlying erlang function: `:array.default/1`
      iex> :array.default(:array.from_list([]))
      :undefined
      iex> :array.default(:array.from_list([], 0))
      0
  """
  @spec default_value(t) :: term
  def default_value(%A.Array{internal: internal}) do
    :array.default(internal)
  end

  @doc ~S"""
  Returns true if `array` is fixed size, false else.

  ## Examples
      iex> A.Array.fixed?(A.Array.new([1, 2, 3]))
      false
      iex> A.Array.fixed?(A.Array.new([1, 2, 3], fixed?: true))
      true

  ## Underlying erlang function: `:array.is_fix/1`
      iex> array = :array.from_list([1, 2, 3])
      iex> :array.is_fix(array)
      false
      iex> :array.is_fix(:array.fix(array))
      true
  """
  @spec fixed?(t) :: boolean
  def fixed?(%A.Array{internal: internal}) do
    :array.is_fix(internal)
  end

  @doc ~S"""
  Ensure `array` has a fixed size.

  Does nothing if it is already the case.
  Calls to `A.Array.get/2` or `A.Array.set/3` with `index >= size` will fail for a fixed-sized array.
  The reverse operation is `A.Array.relax/1`.

  ## Examples
      iex> fixed = A.Array.fix(A.Array.new([1, 2, 3]))
      #A.Array<[1, 2, 3], fixed?: true>
      iex> A.Array.fixed?(fixed)
      true
      iex> ^fixed = A.Array.fix(fixed)
      iex> A.Array.get(fixed, 3)
      ** (ArgumentError) cannot access index above fixed size, expected index < 3, got: 3

  ## Underlying erlang function: `:array.fix/1`
      iex> fixed = :array.fix(:array.from_list([1, 2, 3]))
      iex> :array.is_fix(fixed)
      true
      iex> ^fixed = :array.fix(fixed)
  """
  @spec fix(t(val)) :: t(val) when val: value
  def fix(%A.Array{internal: internal} = array) do
    %{array | internal: :array.fix(internal)}
  end

  @doc ~S"""
  Ensure `array` has a dynamic (non-fixed) size.

  Does nothing if it is already the case. The reverse operation is `A.Array.fix/1`.

  ## Examples
      iex> relaxed = A.Array.new([1, 2, 3], fixed?: true) |> A.Array.relax()
      #A.Array<[1, 2, 3]>
      iex> A.Array.fixed?(relaxed)
      false
      iex> ^relaxed = A.Array.relax(relaxed)
      iex> A.Array.get(relaxed, 4)
      nil

  ## Underlying erlang function: `:array.relax/1`
      iex> fixed = :array.fix(:array.from_list([1, 2, 3]))
      iex> relaxed = :array.relax(fixed)
      iex> :array.is_fix(relaxed)
      false
      iex> ^relaxed = :array.relax(relaxed)
  """
  @spec relax(t(val)) :: t(val) when val: value
  def relax(%A.Array{internal: internal} = array) do
    %{array | internal: :array.relax(internal)}
  end

  @doc ~S"""
  Returns the i-th element in `array`.

  Runs in constant time.

  ## Examples
      iex> array = A.Array.new([1, 2, 3, 5, 8])
      iex> A.Array.get(array, 2)
      3
      iex> A.Array.get(array, 10)
      nil

  ## Underlying erlang function: `:array.get/2`
      iex> array = :array.from_list([1, 2, 3, 5, 8])
      iex> :array.get(2, array)
      3
  """
  @spec get(t(val), index) :: t(val) when val: value
  def get(%A.Array{internal: internal}, index) do
    try do
      :array.get(index, internal)
    rescue
      ArgumentError ->
        handle_argument_error(internal, index)
    end
  end

  @doc ~S"""
  Returns a new `array` where the i-th element is su `array`.

  Runs in constant time.

  ## Examples
      iex> array = A.Array.new([1, 2, 3, 5, 8])
      iex> A.Array.set(array, 2, 100)
      #A.Array<[1, 2, 100, 5, 8]>

  Unless of fixed size, the array will grow automatically to accomodate the new index, using its default value:
      iex> A.Array.new() |> A.Array.set(7, 45)
      #A.Array<[nil, nil, nil, nil, nil, nil, nil, 45]>

  Also see: `A.Array.replace_at/3`, `A.Array.update_at/3`

  ## Underlying erlang function: `:array.set/3`
      iex> array = :array.from_list([1, 2, 3])
      {:array, 3, 10, :undefined, {1, 2, 3, :undefined, :undefined, :undefined, :undefined, :undefined, :undefined, :undefined}}
      iex> :array.set(2, 100, array)
      {:array, 3, 10, :undefined, {1, 2, 100, :undefined, :undefined, :undefined, :undefined, :undefined, :undefined, :undefined}}
  """
  @spec set(t(val), index, val) :: t(val) when val: value
  def set(%A.Array{internal: internal} = array, index, value) do
    try do
      %{array | internal: :array.set(index, value, internal)}
    rescue
      ArgumentError ->
        handle_argument_error(internal, index)
    end
  end

  @doc ~S"""
  Similar to `A.Array.set/3`, excepts it does nothing for out of bound indexes.

  Mirroring the behavior of `List.replace_at/3`.

  ## Examples
      iex> array = A.Array.new([1, 2, 3, 5, 8])
      iex> A.Array.replace_at(array, 2, 100)
      #A.Array<[1, 2, 100, 5, 8]>
      iex> A.Array.replace_at(array, 5, 100)
      #A.Array<[1, 2, 3, 5, 8]>

  ## Underlying erlang function: same as `A.Array.set/3`
  """
  @spec replace_at(t(val), index, val) :: t(val) when val: value
  def replace_at(%A.Array{internal: internal} = array, index, value) when is_integer(index) do
    if in_range(internal, index) do
      %{array | internal: :array.set(index, value, internal)}
    else
      array
    end
  end

  @doc ~S"""
  Returns an array with an updated value at the specified `index` by invoking `fun`.

  Does nothing for out of bound indexes.

  Mirroring the behavior of `List.update_at/3`.

  ## Examples
      iex> array = A.Array.new([1, 2, 3, 5, 8])
      iex> A.Array.update_at(array, 2, &(&1 + 100))
      #A.Array<[1, 2, 103, 5, 8]>
      iex> A.Array.update_at(array, 5, &(&1 + 100))
      #A.Array<[1, 2, 3, 5, 8]>

  ## Underlying erlang function: same as `A.Array.set/3`
  """
  @spec update_at(t(val), index, (val -> val)) :: t(val) when val: value
  def update_at(%A.Array{internal: internal} = array, index, fun)
      when is_integer(index) and is_function(fun, 1) do
    if in_range(internal, index) do
      value = fun.(:array.get(index, internal))
      %{array | internal: :array.set(index, value, internal)}
    else
      array
    end
  end

  @doc ~S"""
  Returns an array where each element is the result of invoking `fun` on each corresponding element.

  Mirroring the behavior of `Enum.map/2` but returns an `A.Array` instead of a list.

  ## Examples
      iex> array = A.Array.new([1, 2, 3, 5, 8])
      iex> A.Array.map(array, &(&1 + 30))
      #A.Array<[31, 32, 33, 35, 38]>
      iex> sparse = A.Array.new([1, 2, 3], default: 0) |> A.Array.set(7, 10)
      #A.Array<[1, 2, 3, 0, 0, 0, 0, 10], default: 0>
      iex> A.Array.map(sparse, &(&1 + 30))
      #A.Array<[31, 32, 33, 30, 30, 30, 30, 40], default: 0>

  See also: `A.Array.map_with_index/2`, `A.Array.sparse_map/2` and `A.Array.sparse_map_with_index/2`

  ## Underlying erlang function: `:array.map/2`
      iex> array = :array.from_list([1, 2, 3, 5, 8])
      iex> result = :array.map(fn _index, value -> 30 + value end, array)
      iex> :array.to_list(result)
      [31, 32, 33, 35, 38]

  Note: `:array.map/2` takes a callback of arity /2 looping over (index, value)
  """
  @spec map(t(val), (val -> val)) :: t(val) when val: value
  def map(%A.Array{internal: internal} = array, fun) when is_function(fun, 1) do
    new_internal = :array.map(fn _index, value -> fun.(value) end, internal)
    %{array | internal: new_internal}
  end

  @doc ~S"""
  Same as `A.Array.map/2` but takes an arity /2 callback looping over (value, index).

  ## Examples
      iex> array = A.Array.new([1, 2, 3, 5, 8])
      iex> A.Array.map_with_index(array, fn value, index -> {index, value} end)
      #A.Array<[{0, 1}, {1, 2}, {2, 3}, {3, 5}, {4, 8}]>
      iex> sparse = A.Array.new([1, 2, 3], default: 0) |> A.Array.set(7, 10)
      #A.Array<[1, 2, 3, 0, 0, 0, 0, 10], default: 0>
      iex> A.Array.map_with_index(sparse, fn value, index -> value + index end)
      #A.Array<[1, 3, 5, 3, 4, 5, 6, 17], default: 0>

  See also: `A.Array.map/2`, `A.Array.sparse_map/2` and `A.Array.sparse_map_with_index/2`

  ## Underlying erlang function: `:array.map/2`
      iex> array = :array.from_list([1, 2, 3, 5, 8])
      iex> result = :array.map(fn index, value -> {index, value} end, array)
      iex> :array.to_list(result)
      [{0, 1}, {1, 2}, {2, 3}, {3, 5}, {4, 8}]
  """
  @spec map_with_index(t(val), (val, index -> val)) :: t(val) when val: value
  def map_with_index(%A.Array{internal: internal} = array, fun) when is_function(fun, 2) do
    new_internal = :array.map(fn index, value -> fun.(value, index) end, internal)
    %{array | internal: new_internal}
  end

  @doc ~S"""
  Same as `A.Array.map/2` but keeps the sparse elements untouched.

  ## Examples
      iex> sparse = A.Array.new([1, 2, 3], default: 0) |> A.Array.set(7, 10)
      #A.Array<[1, 2, 3, 0, 0, 0, 0, 10], default: 0>
      iex> A.Array.sparse_map(sparse, &(&1 + 30))
      #A.Array<[31, 32, 33, 0, 0, 0, 0, 40], default: 0>

  See also: `A.Array.map/2`, `A.Array.map_with_index/2` and `A.Array.sparse_map_with_index/2`

  ## Underlying erlang function: `:array.sparse_map/2`
      iex> array = :array.set(7, 10, :array.from_list([1, 2, 3]))
      iex> result = :array.sparse_map(fn _index, value -> 30 + value end, array)
      iex> :array.to_list(result)
      [31, 32, 33, :undefined, :undefined, :undefined, :undefined, 40]

  Note: `:array.sparse_map/2` takes a callback of arity /2 looping over (index, value)
  """
  @spec sparse_map(t(val), (val -> val)) :: t(val) when val: value
  def sparse_map(%A.Array{internal: internal} = array, fun) when is_function(fun, 1) do
    new_internal = :array.sparse_map(fn _index, value -> fun.(value) end, internal)
    %{array | internal: new_internal}
  end

  @doc ~S"""
  Same as `A.Array.sparse_map/2` but takes an arity /2 callback looping over (value, index).

  ## Examples
      iex> sparse = A.Array.new([1, 2, 3], default: 0) |> A.Array.set(7, 10)
      #A.Array<[1, 2, 3, 0, 0, 0, 0, 10], default: 0>
      iex> A.Array.sparse_map_with_index(sparse, fn value, index -> value + index end)
      #A.Array<[1, 3, 5, 0, 0, 0, 0, 17], default: 0>

  See also: `A.Array.map/2`, `A.Array.sparse_map/2` and `A.Array.map_with_index/2`

  ## Underlying erlang function: `:array.sparse_map/2`
      iex> array = :array.set(7, 10, :array.from_list([1, 2, 3]))
      iex> result = :array.sparse_map(fn index, value -> index + value end, array)
      iex> :array.to_list(result)
      [1, 3, 5, :undefined, :undefined, :undefined, :undefined, 17]
  """
  @spec sparse_map_with_index(t(val), (val, index -> val)) :: t(val) when val: value
  def sparse_map_with_index(%A.Array{internal: internal} = array, fun) when is_function(fun, 2) do
    new_internal = :array.sparse_map(fn index, value -> fun.(value, index) end, internal)
    %{array | internal: new_internal}
  end

  @doc ~S"""
  Converts `array` to a list.

  ## Examples
      iex> A.Array.new([1, 2, 3]) |> A.Array.to_list()
      [1, 2, 3]

  ## Underlying erlang function: `:array.to_list/1`
      iex> :array.to_list(:array.from_list([1, 2, 3]))
      [1, 2, 3]
  """
  @spec to_list(t(val)) :: [val] when val: value
  def to_list(%A.Array{internal: internal}) do
    :array.to_list(internal)
  end

  @doc ~S"""
  Converts `array` to a list keeping only non-sparse values.

  ## Examples
      iex> A.Array.new([nil, 1, nil, nil, 2, 3, nil]) |> A.Array.sparse_to_list()
      [1, 2, 3]

  ## Underlying erlang function: `:array.sparse_to_list/1`
      iex> :array.sparse_to_list(:array.from_list([:undefined, 1, 2, :undefined, 3]))
      [1, 2, 3]
  """
  @spec sparse_to_list(t(val)) :: [val] when val: value
  def sparse_to_list(%A.Array{internal: internal}) do
    :array.sparse_to_list(internal)
  end

  @doc ~S"""
  Appends a value at the end of the array.

  Some append might trigger resizes: if you need to append several values,
  use `append_many/2` which only does one resize.

  ## Examples
      iex> A.Array.new([1, 2, 3]) |> A.Array.append(4)
      #A.Array<[1, 2, 3, 4]>

  Not directly in the original erlang module, based on `:array.set/3`.
  """
  @spec append(t(val), val) :: t(val) when val: value
  def append(%A.Array{internal: internal} = array, value) do
    new_internal = :array.size(internal) |> :array.set(value, internal)
    %{array | internal: new_internal}
  end

  # TODO: benchmark append_many

  @doc ~S"""
  Appends all values from the enumerable at the end of the array.

  It should be more efficient than many individual calls to `append/2`
  since it only needs to resize once.

  ## Examples
      iex> A.Array.new([1, 2, 3]) |> A.Array.append_many([4, 5, 6])
      #A.Array<[1, 2, 3, 4, 5, 6]>

  Not directly in the original erlang module, based on `:array.set/3`.
  """
  @spec append_many(t(val), [val]) :: t(val) when val: value
  def append_many(%A.Array{internal: internal} = array, values) do
    size = :array.size(internal)

    # insert in reverse order have only one resize!
    new_internal =
      values
      |> Enum.with_index()
      |> Enum.reverse()
      |> Enum.reduce(internal, fn {value, index}, acc ->
        :array.set(size + index, value, acc)
      end)

    %{array | internal: new_internal}
  end

  # Access callbacks

  @doc """
  Fetches the value for a specific `index` and returns it in a ok-tuple.
  If the key does not exist, returns :error.

  ## Examples

      iex> A.Array.new([1, 2, 3]) |> A.Array.fetch(2)
      {:ok, 3}
      iex> A.Array.new([1, 2, 3]) |> A.Array.fetch(3)
      :error
      iex> A.Array.new([1, 2, 3], fixed?: true) |> A.Array.fetch(3)
      :error

  ## Underlying erlang function: `:array.get/2`

  Unlike `A.Array.fetch/2` which treats all out of bound cases the same,`:array.get/2`:
  - returns the default value when index >= size for non-fixed arrays
  - raises an `ArgumentError` when index >= size for fixed-size arrays
  - raises an `ArgumentError` for negative indexes

      iex> array = :array.from_list([1, 2, 3])
      iex> :array.get(2, array)
      3
      iex> :array.get(3, array)
      :undefined
      iex> :array.get(3, :array.fix(array))
      ** (ArgumentError) argument error
  """
  @spec fetch(t(val), index) :: {:ok, val} | :error when val: value
  @impl Access
  def fetch(%A.Array{internal: internal}, index) when is_integer(index) and index >= 0 do
    if index >= :array.size(internal) do
      :error
    else
      {:ok, :array.get(index, internal)}
    end
  end

  @doc """
  Gets the value from `index` and updates it, all in one pass.

  This `fun` argument receives the value of `index` (or the default value
  if key is not present) and must return a two-element tuple: the "get" value
  (the retrieved value, which can be operated on before being returned)
  and the new value to be stored under `index`. The `fun` may also
  return `:pop`, implying the current value shall be reset to the default value
  of the array and its previous value returned.

  The returned value is a tuple with the "get" value returned by
  `fun` and a new keyword list with the updated value under `index`.

  ## Examples

      iex> array = A.Array.new([1, 2, 3])
      iex> {2, updated} = A.Array.get_and_update(array, 1, fn current_value ->
      ...>   {current_value, :new_value}
      ...> end)
      iex> updated
      #A.Array<[1, :new_value, 3]>
      iex> {nil, updated} = A.Array.get_and_update(array, 3, fn current_value ->
      ...>   {current_value, :new_value}
      ...> end)
      iex> updated
      #A.Array<[1, 2, 3, :new_value]>
      iex> {2, updated} = A.Array.get_and_update(array, 1, fn _ -> :pop end)
      iex> updated
      #A.Array<[1, nil, 3]>
      iex> {nil, updated} = A.Array.get_and_update(array, 3, fn _ -> :pop end)
      iex> updated
      #A.Array<[1, 2, 3]>
  """
  @spec get_and_update(t(val), index, (val -> {returned, val} | :pop)) :: {returned, t(val)}
        when val: value, returned: term
  @impl Access
  def get_and_update(%A.Array{internal: internal} = array, index, fun)
      when is_integer(index) and index >= 0 and is_function(fun, 1) do
    previous_value = get(array, index)

    case fun.(previous_value) do
      :pop ->
        {previous_value, do_reset(array, index)}

      {retrieved_value, updated_value} ->
        new_array = %{array | internal: :array.set(index, updated_value, internal)}
        {retrieved_value, new_array}

      other ->
        raise "the given function must return a two-element tuple or :pop, got: #{inspect(other)}"
    end
  end

  @doc """
  Returns the value for `index` and resets the existing value to the array default.
  It returns a tuple where the first element is the value for `index` and the
  second element is the array with the reset value.
  If the `index` is not present in the array, `{default, array}` is returned, where default is:
  - the provided `default` parameter for `pop/3`
  - the array default value for `pop/2`

  ## Examples

      iex> array = A.Array.new([1, 2, 3])
      iex> {2, updated} = A.Array.pop(array, 1)
      iex> updated
      #A.Array<[1, nil, 3]>
      iex> {nil, updated} = A.Array.pop(array, 3)
      iex> updated
      #A.Array<[1, 2, 3]>
      iex> {0, updated} = A.Array.pop(array, 3, 0)
      iex> updated
      #A.Array<[1, 2, 3]>
      iex> {0, updated} = A.Array.new([1, 2, 3], default: 0) |> A.Array.pop(3)
      iex> updated
      #A.Array<[1, 2, 3], default: 0>
  """
  @spec pop(t(val), index, val) :: {val, t(val)} when val: value
  @impl Access
  def pop(array, index, default \\ :"A.Array.default_value")

  def pop(%A.Array{} = array, index, :"A.Array.default_value") do
    case fetch(array, index) do
      {:ok, value} -> {value, do_reset(array, index)}
      :error -> {A.Array.default_value(array), array}
    end
  end

  def pop(%A.Array{} = array, index, default) do
    case fetch(array, index) do
      {:ok, value} -> {value, do_reset(array, index)}
      :error -> {default, array}
    end
  end

  # Private function

  defp validate_fixed_keyword(opts) do
    case Keyword.get(opts, :fixed?, false) do
      boolean when is_boolean(boolean) -> boolean
      value -> raise ArgumentError, "fixed? must be a boolean, got: #{inspect(value)}"
    end
  end

  defp in_range(internal, index) do
    index > 0 and index < :array.size(internal)
  end

  defp handle_argument_error(internal, index) do
    message =
      cond do
        not (is_integer(index) and index >= 0) ->
          "index must be a non-negative integer, got: #{inspect(index)}"

        :array.is_fix(internal) and index >= :array.size(internal) ->
          "cannot access index above fixed size, expected index < #{:array.size(internal)}, got: #{
            index
          }"

          # any other case is unexpected
      end

    raise ArgumentError, message
  end

  defp do_reset(%A.Array{internal: internal} = array, index) do
    %{array | internal: :array.reset(index, internal)}
  end

  defimpl Enumerable do
    def count(array) do
      {:ok, A.Array.size(array)}
    end

    def member?(_array, _value), do: {:error, __MODULE__}

    def slice(array) do
      size = A.Array.size(array)

      slicing_fun = fn start, length ->
        for i <- 0..(length - 1), do: A.Array.get(array, start + i)
      end

      {:ok, size, slicing_fun}
    end

    def reduce(array, acc, fun) do
      # TODO: check alternative implementation with foldl and stream/lazy?
      reduce_array(array, acc, fun, 0, A.Array.size(array))
    end

    defp reduce_array(_array, {:halt, acc}, _fun, _i, _size), do: {:halted, acc}

    defp reduce_array(array, {:suspend, acc}, fun, i, size),
      do: {:suspended, acc, &reduce_array(array, &1, fun, i, size)}

    defp reduce_array(_array, {:cont, acc}, _fun, size, size), do: {:done, acc}

    defp reduce_array(array, {:cont, acc}, fun, i, size) do
      element = A.Array.get(array, i)
      reduce_array(array, fun.(element, acc), fun, i + 1, size)
    end
  end

  defimpl Collectable do
    def into(array) do
      fun = fn
        list, {:cont, x} -> [x | list]
        list, :done -> A.Array.append_many(array, Enum.reverse(list))
        _, :halt -> :ok
      end

      {[], fun}
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(array, opts) do
      opts = %Inspect.Opts{opts | charlists: :as_lists}

      default =
        case A.Array.default_value(array) do
          nil -> []
          value -> [", default: ", inspect(value)]
        end

      fixed =
        if A.Array.fixed?(array) do
          [", fixed?: true"]
        else
          []
        end

      [
        "#A.Array<",
        Inspect.List.inspect(A.Array.to_list(array), opts),
        default,
        fixed,
        ">"
      ]
      |> List.flatten()
      |> concat()
    end
  end

  if Code.ensure_loaded?(Jason.Encoder) do
    defimpl Jason.Encoder do
      def encode(array, opts) do
        array
        |> Enum.to_list()
        |> Jason.Encode.list(opts)
      end
    end
  end
end
