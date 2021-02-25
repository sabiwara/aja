<img width="160" src="https://raw.githubusercontent.com/sabiwara/aja/main/images/logo_large.png" alt="Aja">

[![Hex Version](https://img.shields.io/hexpm/v/aja.svg)](https://hex.pm/packages/aja)
[![docs](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/aja/)
[![CI](https://github.com/sabiwara/aja/workflows/CI/badge.svg)](https://github.com/sabiwara/aja/actions?query=workflow%3ACI)

Extension of the Elixir standard library focused on data stuctures, data manipulation and performance.

- [Data structures](#data-structures)
- [Utility functions](#utility-functions)
- [Installation](#installation)
- [About Aja](#about-aja)
- [FAQ](#faq)

## Data structures

> "there is one aspect of functional programming that no amount of cleverness on the part of the
  compiler writer is likely to mitigate — the use of inferior or inappropriate data structures."
> -- [Chris Okasaki](https://www.cs.cmu.edu/~rwh/theses/okasaki.pdf)

#### Persistent vectors: `A.Vector`

Clojure-like [persistent vectors](https://hypirion.com/musings/understanding-persistent-vector-pt-1)
are an efficient alternative to lists, supporting many operations like appends and random access
in effective constant time.

```elixir
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
```

`A.Vector` is blazing fast and easier to use from Elixir than Erlang's
[`:array`](http://erlang.org/doc/man/array.html) module.

`A.Vector` reimplements many of the functions from the `Enum` module specifically for vectors,
with efficiency in mind.

The `A.vec/1` and `A.vec_size/1` macros, while being totally optional, can make it easier to work with vectors
and make pattern-matching possible:

```elixir
iex> import A
iex> vec([a, 2, c, _d, e]) = A.Vector.new(1..5)
#A<vec([1, 2, 3, 4, 5])>
iex> {a, c, e}
{1, 3, 5}
iex> match?(v when vec_size(v) > 9, vec(1..10))
true
```

The `A.+++/2` operator can make appending to a vector more explicit:

```elixir
iex> vec([1, 2, 3]) +++ vec([4, 5])
#A<vec([1, 2, 3, 4, 5])>
```

#### Ordered maps: `A.OrdMap`

The standard library does not offer any similar functionality:
- regular maps do not keep track of the insertion order
- keywords do but they only support atoms and do not have the right performance characteristics (plain lists)

```elixir
iex> %{"one" => 1, "two" => 2, "three" => 3}
%{"one" => 1, "three" => 3, "two" => 2}
iex> ord_map = A.OrdMap.new([{"one", 1}, {"two", 2}, {"three", 3}])
#A<ord(%{"one" => 1, "two" => 2, "three" => 3})>
iex> ord_map["two"]
2
iex> Enum.to_list(ord_map)
[{"one", 1}, {"two", 2}, {"three", 3}]
```

Ordered maps behave pretty much like regular maps, and the `A.OrdMap` module
offers the same API as `Map`.
The convenience macro `A.ord/1` make them a breeze to instantiate or patter-match upon:

```elixir
iex> import A
iex> ord_map = ord(%{"一" => 1, "二" => 2, "三" => 3})
#A<ord(%{"一" => 1, "二" => 2, "三" => 3})>
iex> ord(%{"三" => three, "一" => one}) = ord_map
iex> {one, three}
{1, 3}
```

All data structures offer:
- good performance characteristics at any size (see [FAQ](#faq))
- well-documented APIs that are consistent with the standard library
- implementation of `Inspect`, `Enumerable` and `Collectable` protocols
- implementation of the `Access` behaviour
- (optional if `Jason` is installed) implemention of the `Jason.Encoder` protocol


## Utility functions

#### Sigil i for [IO data](https://hexdocs.pm/elixir/IO.html#module-io-data)

```elixir
iex> import A
iex> ~i"atom: #{:foo}, charlist: #{'abc'}, number: #{12 + 2.35}\n"
["atom: ", "foo", ", charlist: ", 'abc', ", number: ", "14.35", 10]
```

#### Exclusive ranges: `A.ExRange`

```elixir
iex> A.ExRange.new(0, 10) |> Enum.to_list()
[0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
iex> import A
iex> Enum.map(0 ~> 5, &"id_#{&1}")
["id_0", "id_1", "id_2", "id_3", "id_4"]
```

#### *Don't Break The Pipe!*

```elixir
iex> %{foo: "bar"} |> A.Pair.wrap(:noreply)
{:noreply, %{foo: "bar"}}
iex> {:ok, 55} |> A.Pair.unwrap!(:ok)
55
```

#### Various other convenience helpers

```elixir
iex> A.String.slugify("> \"It Was Me, Dio!!!\"\n")
"it-was-me-dio"
iex> A.Integer.decimal_format(1234567)
"1,234,567"
iex> A.Integer.div_rem(7, 3)
{2, 1}
iex> A.Enum.sort_uniq([1, 4, 2, 2, 3, 1, 4, 3])
[1, 2, 3, 4]
iex> A.List.repeatedly(&:rand.uniform/0, 3)
[0.40502929729990744, 0.45336720247823126, 0.04094511692041057]
iex> A.IO.iodata_empty?(["", []])
true
```

Nothing groundbreaking, but having these helpers to hand might save you the implementation
and the testing, or bringing over a library just for this one thing.

Browse the API documentation for more details.

## Installation

Aja can be installed by adding `aja` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:aja, "~> 0.4.8"}
  ]
end
```

Documentation can be found at [https://hexdocs.pm/aja](https://hexdocs.pm/aja).

## About Aja

### Inspirations

- the amazingly polished [Elixir standard library](https://hexdocs.pm/elixir): self-consistent,
  well-documented and just **delightful** ✨️
- the also amazing [Python standard library](https://docs.python.org/3/library/),
  notably its [collections](https://docs.python.org/3/library/collections.html) module
- the amazing [lodash](https://lodash.com/docs) which complements nicely the (historically rather small)
  javascript standard library, with a very consistent API
- various work on efficient [persistent data structures](https://en.wikipedia.org/wiki/Persistent_data_structure) spearheaded by Okasaki
  (see [resources section](#resources) below)
- Clojure's persistent vectors, by Rich Hickey and influenced by Phil Bagwell

### Goals

- like the standard library, being **delightful** to use ✨️ (consistency with Elixir and itself, quality, documentation)
- no external dependency to help you preserve a decent dependency tree
- performance-conscious (right algorithm, proper benchmarking, fast compile times*)
- mostly dead-simple pure functions: no configuration, no mandatory macro, no statefulness / OTP

(\* while fast compile time is a target, `A.Vector`, which is optimized for fast runtime at the expense of compile time,
slows it down)

### Non-goals

- add every possible feature that has not been accepted in elixir core (Aja is opinionated!)
- touching anything OTP-related / stateful

### Resources

- Chris Okasaki's [Purely Functional Data Structures](https://www.cs.cmu.edu/~rwh/theses/okasaki.pdf)
- Jean Niklas L'orange's [articles](https://hypirion.com/musings/understanding-persistent-vector-pt-1)
  and [thesis](https://hypirion.com/thesis.pdf) about persistent vectors and RRB trees

## FAQ

### How stable is it?

Aja is still pretty early stage and the high-level organisation is still in flux.
Expect some breaking changes until it reaches maturity.

However, many of its APIs are based on the standard library and should therefore remain fairly stable.

Besides, Aja is tested quite thoroughly both with unit tests and property-based testing (especially for
data structures).
This effort is far from perfect, but increases our confidence in the overall reliability.

### How is the performance?

#### Vectors

Most operations from `A.Vector` are much faster than Erlang's `:array` equivalents, and in some cases are even
noticeably faster than equivalent list operations (map, folds, join, sum...).

#### Ordered maps

Performance for ordered maps has an inevitable though decent overhead over plain maps in terms of creation and
update time (write operations), as well as memory usage, since some extra work is needed to keep track of the order.
It has however very good read performance, with a very minimal overhead in terms of key access, and can be
enumerated much faster than maps.

#### Aja + JIT = 💖️

Aja's data structures (vectors and ordered maps) are already pretty fast on pre-JIT versions of OTP (`<= 23`).
Benchmarks on OTP 24 suggest however that they are taking great advantage of the
[JIT](https://blog.erlang.org/a-first-look-at-the-jit/), relative to lists/maps, making them
even more interesting performance-wise.

#### Benchmarks

Aja data structures should work fine in most cases, but if you're considering them for
performance-critical sections of your code, make sure to benchmark them.

Benchmarking is still a work in progress, but you can check the
[`bench` folder](https://github.com/sabiwara/aja/blob/main/bench) for more detailed figures.

### Does Aja try to do too much?

The Unix philosophy of *"Do one thing and do it well"* is arguably the right approach in many cases.
Aja doesn't really follow it, but there are conscious reasons for going that direction.

While it might be possible later down the road to split some of its components, there is no plan to do so
at the moment.

First, we don't think there is any real downside of shipping "too much": Aja is and aims to remain
lightweight and keep a modular structure.
You can just use what you need without suffering from what you don't.

This lodash-like approach has benefits too: it aims to ship with a lot of convenience while introducing only
one flat dependency. This can help staying out of two extreme paths:

- the ["leftpad way"](https://www.theregister.com/2016/03/23/npm_left_pad_chaos/), where every project relies on
  a ton of small dependencies, ending up with un-manageable dependency trees and brittle software.
- the ["Lisp Curse way"](http://winestockwebdesign.com/Essays/Lisp_Curse.html), where everybody keeps rewriting
  the same thing over and over because nobody wants the extra dependency. Being a hidden Lisp with similar
  super powers and expressiveness, Elixir might make it relatively easy and tempting to go down that path.

Finally, data structures can work more efficiently together than if they were separated libraries.

### What are the next steps?

Nothing is set in stone, but the next steps will probably be:
- complete the API for `A.Vector` and improve its ergonomics
- more benchmarks and performance optimizations

## Copyright and License

Aja is licensed under the [MIT License](LICENSE.md).
