<img width="160" src="https://raw.githubusercontent.com/sabiwara/aja/main/images/logo_large.png" alt="Aja">

[![Hex Version](https://img.shields.io/hexpm/v/aja.svg)](https://hex.pm/packages/aja)
[![docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/aja/)
[![CI](https://github.com/sabiwara/aja/workflows/CI/badge.svg)](https://github.com/sabiwara/aja/actions?query=workflow%3ACI)

Extension of the Elixir standard library focused on data stuctures, data
manipulation and performance.

- [Data structures](#data-structures)
- [Utility functions](#utility-functions)
- [Installation](#installation)
- [About Aja](#about-aja)
- [FAQ](#faq)

## Data structures

> "there is one aspect of functional programming that no amount of cleverness on
> the part of the compiler writer is likely to mitigate — the use of inferior or
> inappropriate data structures." --
> [Chris Okasaki](https://www.cs.cmu.edu/~rwh/theses/okasaki.pdf)

#### Persistent vectors: `Aja.Vector`

A blazing fast, pure Elixir implementation of a persistent vector, meant to
offer an efficient alternative to lists. Supports many operations like appends
and random access in effective constant time.

```elixir
iex> vector = Aja.Vector.new(1..10)
vec([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
iex> Aja.Vector.append(vector, :foo)
vec([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, :foo])
iex> vector[3]
4
iex> Aja.Vector.replace_at(vector, -1, :bar)
vec([1, 2, 3, 4, 5, 6, 7, 8, 9, :bar])
iex> 3 in vector
true
```

`Aja.Vector` reimplements many of the functions from the `Enum` module
specifically for vectors, with efficiency in mind. It should be easier to use
from Elixir than Erlang's [`:array`](https://erlang.org/doc/man/array.html)
module and faster in most cases.

The `Aja.vec/1` and `Aja.vec_size/1` macros, while being totally optional, can
make it easier to work with vectors and make pattern-matching possible:

```elixir
iex> import Aja
iex> vec([a, 2, c, _d, e]) = Aja.Vector.new(1..5); {a, c, e}
{1, 3, 5}
iex> vec(first ||| last) = Aja.Vector.new(1..1_000_000); {first, last}
{1, 1000000}
iex> match?(v when vec_size(v) > 9, vec(1..10))
true
```

The `Aja.+++/2` operator provides synctactic sugar for vector concatenation:

```elixir
iex> vec([1, 2, 3]) +++ vec([4, 5])
vec([1, 2, 3, 4, 5])
```

#### Ordered maps: `Aja.OrdMap`

The standard library does not offer any similar functionality:

- regular maps do not keep track of the insertion order
- keywords do but they only support atoms and do not have the right performance
  characteristics (plain lists)

```elixir
iex> %{"one" => 1, "two" => 2, "three" => 3}
%{"one" => 1, "three" => 3, "two" => 2}
iex> ord_map = Aja.OrdMap.new([{"one", 1}, {"two", 2}, {"three", 3}])
ord(%{"one" => 1, "two" => 2, "three" => 3})
iex> ord_map["two"]
2
iex> Enum.to_list(ord_map)
[{"one", 1}, {"two", 2}, {"three", 3}]
```

Ordered maps behave pretty much like regular maps, and the `Aja.OrdMap` module
offers the same API as `Map`. The convenience macro `Aja.ord/1` make them a
breeze to instantiate or pattern-match upon:

```elixir
iex> import Aja
iex> ord_map = ord(%{"一" => 1, "二" => 2, "三" => 3})
ord(%{"一" => 1, "二" => 2, "三" => 3})
iex> ord(%{"三" => three, "一" => one}) = ord_map
iex> {one, three}
{1, 3}
```

All data structures offer:

- great performance characteristics at any size (see [FAQ](#faq))
- well-documented APIs that are consistent with the standard library
- implementation of `Inspect`, `Enumerable` and `Collectable` protocols
- implementation of the `Access` behaviour
- (optional if `Jason` is installed) implemention of the `Jason.Encoder`
  protocol

#### Optimized `Enum`: `Aja.Enum`

`Aja.Enum` mirrors the `Enum` module, but its implementation is highly optimized
for Aja structures such as `Aja.Vector` or `Aja.OrdMap`.

`Aja.Enum` on vectors/ord maps can often be faster than `Enum` on lists/maps,
depending on the function and size of the sequence.

## Utility functions

#### IO data

[IO data](https://hexdocs.pm/elixir/IO.html#module-io-data) are nested
structures based on lists to work more efficiently with binary/text data without
the need for any expensive concatenation.

The `~i` sigil provides a way to build IO data using string interpolation:

```elixir
iex> import Aja
iex> ~i"atom: #{:foo}, charlist: #{'abc'}, number: #{12 + 2.35}\n"
["atom: ", "foo", ", charlist: ", 'abc', ", number: ", "14.35", 10]
```

The `Aja.IO` module provides functions to work with IO data:

```elixir
iex> Aja.IO.to_iodata(:foo)
"foo"
iex> Aja.IO.to_iodata(["abc", 'def' | "ghi"])
["abc", 'def' | "ghi"]
iex> Aja.IO.iodata_empty?(["", []])
true
```

## Installation

Aja can be installed by adding `aja` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:aja, "~> 0.6.2"}
  ]
end
```

Or, if you are using Elixir 1.12, you can just try it out from `iex` or an
`.exs` script:

```elixir
iex> Mix.install([:aja])
:ok
iex> Aja.Vector.new(["Hello", "world!"])
vec(["Hello", "world!"])
```

Documentation can be found at [https://hexdocs.pm/aja](https://hexdocs.pm/aja).

## About Aja

### Inspirations

- the amazingly polished [Elixir standard library](https://hexdocs.pm/elixir):
  self-consistent, well-documented and just **delightful** ✨️
- the also amazing
  [Python standard library](https://docs.python.org/3/library/), notably its
  [collections](https://docs.python.org/3/library/collections.html) module
- various work on efficient
  [persistent data structures](https://en.wikipedia.org/wiki/Persistent_data_structure)
  spearheaded by Okasaki
- Clojure's persistent vectors, by Rich Hickey and influenced by Phil Bagwell

### Goals

- being consistent with Elixir and with itself (API, quality, documentation)
- no external dependency to help you preserve a decent dependency tree
- performance-conscious (right algorithm, proper benchmarking, fast compile
  times\*)
- mostly dead-simple pure functions: no configuration, no mandatory macro, no
  statefulness / OTP

(\* while fast compile time is a target, vectors are optimized for fast runtime
at the expense of compile time)

### Resources

- Chris Okasaki's
  [Purely Functional Data Structures](https://www.cs.cmu.edu/~rwh/theses/okasaki.pdf)
- Jean Niklas L'orange's
  [articles](https://hypirion.com/musings/understanding-persistent-vector-pt-1)
  and [thesis](https://hypirion.com/thesis.pdf) about persistent vectors and RRB
  trees

## FAQ

### How stable is it?

Aja is still pretty early stage and the high-level organisation is still in
flux. Expect some breaking changes until it reaches maturity.

However, most of its APIs are based on the standard library and should therefore
remain fairly stable.

Besides, Aja is tested quite thoroughly both with unit tests and property-based
testing (especially for data structures). This effort is far from perfect, but
increases our confidence in the overall reliability.

### How is the performance?

#### Vectors

Most operations from `Aja.Vector` are much faster than Erlang's `:array`
equivalents, and in some cases are even noticeably faster than equivalent list
operations (map, folds, join, sum...). Make sure to read the efficiency guide
from `Aja.Vector` doc.

#### Ordered maps

Performance for ordered maps has an inevitable though decent overhead over plain
maps in terms of creation and update time (write operations), as well as memory
usage, since some extra work is needed to keep track of the order. It has
however very good read performance, with a very minimal overhead in terms of key
access, and can be enumerated much faster than maps using `Aja.Enum`.

#### Aja 💖️ JIT

Aja's data structures (vectors and ordered maps) are already pretty fast on
pre-JIT versions of OTP (`<= 23`). Benchmarks on OTP 24 suggest however that
they are taking great advantage of the
[JIT](https://blog.erlang.org/a-first-look-at-the-jit/), relative to lists/maps,
making them even more interesting performance-wise.

#### Benchmarks

Aja data structures should work fine in most cases, but if you're considering
them for performance-critical sections of your code, make sure to benchmark
them.

Benchmarking is still a work in progress, but you can check the
[`bench` folder](https://github.com/sabiwara/aja/blob/main/bench) for more
detailed figures.

## Copyright and License

Aja is licensed under the [MIT License](LICENSE.md).
