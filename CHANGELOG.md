# Changelog

## Dev

## v0.5.1 (2021-04-09)

### Enhancements

* Add `A.Vector.flat_map/2`
* Add `A.Vector.reverse/2` and `A.Enum.reverse/2`
* Add `A.Enum.concat/2`
* Add `A.Enum.zip/2` and `A.Enum.unzip/1`
* `A.OrdMap.drop/2` will only try to period rebuild once after dropping all keys

### Bug fixes

* Fix the minimal version needed for `Jason` (1.2)
* `A.OrdMap.take/2` behaves as expected when keys are duplicated
* `A.ord/1` warning on duplicate keys uses the proper stacktrace

### Breaking changes

* Change `Inspect` protocol for `A.Vector` and `A.OrdMap`
* Deprecate A.Enum.sort_uniq/1, A.Enum.sort_uniq/2

## v0.5.0 (2021-03-25)

### Enhancements

* `A.OrdMap` new implemention, with highly improved performance ⚡️⚡️
* `A.Enum` as a faster `Enum` module optimized for Aja structures (vectors, ord maps)
* Added `A.ord_size/1` macro
* `A.vec/1` can pattern-match on first and last elements
* `A.ord/1` warns on duplicate errors and can generate the AST on compile time for constant keys

### Breaking changes

* Reimplement `A.OrdMap`, changing its internals completely
* Change signature of `A.OrdMap.foldl/3` and `A.OrdMap.foldr/3` for consistency
* Remove A.OrdMap.pop_first/1 and A.OrdMap.pop_last/1
* Modify `A.Vector` internals (only breaking if persisted)
* Deprecate methods from `A.Vector` that have been moved to `A.Enum`
* Remove A.RBMap and A.RBSet
* Rename `A.List.repeat/2` and `A.Vector.repeat/2` (previously "repeatedly")

## v0.4.8 (2021-02-23)

### Enhancements

* Add `A.Vector.map_reduce/3`
* Add `A.Vector.scan/2` and `A.Vector.scan/3`
* `A.Vector.with_index/2` accepts a function parameter

### Breaking changes

  * Deprecate A.RBMap and A.RBSet

### Bug fixes

* Fix A.Vector.join/2 bug when working with chardata

## v0.4.7 (2021-02-19)

### Enhancements

* Add A.Vector.reduce/2 and A.Vector.reduce/3
* Add `A.Vector.split/2` and `A.Vector.split_with/2`
* Add A.Vector.frequencies/1 and A.Vector.frequencies_by/2
* Add A.Vector.group_by/3
* Add `A.Vector.dedup/1` and `A.Vector.dedup_by/2`
* Add A.Vector.min/2, A.Vector.max/2, A.Vector.min_by/3, A.Vector.max_by/3
* Improve performance for  A.Vector.min/1, A.Vector.max/1 and `A.Vector.uniq/1`

## v0.4.6 (2021-02-10)

### Enhancements

* Add A.Vector.find_index/2
* Add `A.Vector.take_while/2`, `A.Vector.drop_while/2` and `A.Vector.split_while/2`
* Add `A.Vector.zip/2` and `A.Vector.unzip/1`
* Add `A.Vector.fetch!/2` alias

## v0.4.5 (2021-01-31)

### Enhancements

* Add A.Vector.find/3 and A.Vector.find_value/3
* Add `A.+++/2` convenience operator
* Improve efficiency of vector access functions: `A.Vector.at/2`,
  `A.Vector.fetch/2`, `A.Vector.replace_at/3`,  `A.Vector.delete_at/2`...  ⚡️
* Improve compile times

### Bug fixes

* Invoke callbacks in the right order for: `A.Vector.filter/2`,
  `A.Vector.reject/2` and improve performance

## v0.4.4 (2021-01-23)

### Enhancements

* Add `A.vec_size/1` macro
* Add `A.Vector.with_index/2`
* Add A.Vector.random/1, `A.Vector.take_random/2` and `A.Vector.shuffle/1`
* Drastically improve efficiency of `A.Vector.duplicate/2` ⚡️⚡️⚡️

### Breaking changes

  * Changed internal representation of `A.Vector` (only breaking if persisted)
  * Stop documenting and exposing internal trees (A.RBTree)
  * Rename and deprecate A.Vector.append_many/2 to `A.Vector.concat/2`

## v0.4.3 (2021-01-12)

This release is mostly focused on vector slicing and performance ⚡️

### Enhancements

* Add A.Vector.each/2
* Add `A.Vector.slice/2`, `A.Vector.slice/3`, `A.Vector.take/2` and `A.Vector.drop/2`
* `A.Vector` efficiently implements `Enumerable.slice/1`
* Reimplement `A.Vector.delete_at/2`, `A.Vector.pop_at/2` efficiently

## v0.4.2 (2021-01-10)

### Enhancements

* Implement A.Vector.product/1

### Bug fixes

* Invoke callbacks in the right order for: `A.Vector.map/2`,
  `A.Vector.map_intersperse/3`, A.Vector.map_join/3,
  A.Vector.any?/2, A.Vector.all?/2

## v0.4.1 (2020-12-05)

### Enhancements

* Add A.Vector.map_join/3 and `A.Vector.map_intersperse/3`
* Implement `A.Vector.intersperse/2` more efficiently

### Bug fixes

* A.Vector.sum/1 adds using the same order as `Enum.sum/1`,
  avoiding slight inconsistencies for floats

## v0.4.0 (2020-12-02)

### Enhancements

* Introduce persistent vectors: `A.Vector` 🚀️
* Add `A.vec/1`

## v0.3.3 (2020-11-14)

### Enhancements

* Add `A.sigil_i/2`
* Add `A.IO.to_iodata/1`

## v0.3.2 (2020-11-14)

### Enhancements

* Add A.Enum.sort_uniq/1, A.Enum.sort_uniq/2
* Add `A.List.prepend/2`

## v0.3.1 (2020-11-05)

### Bug fixes

  * A.RBMap.Enumerable.member?/2 returns `false` instead of crashing for values
    other than size-2 tuples

## v0.3.0 (2020-10-31)

### Enhancements

  * Rework all internals, improved peformance for `A.OrdMap`, A.RBMap, A.RBSet
  * Add `default` parameter to `A.OrdMap.first/1`, `A.OrdMap.last/1`,
   A.RBMap.first/1, A.RBMap.last/1, A.RBSet.first/1, A.RBSet.last/1

### Breaking changes

  * Changed signature of `A.OrdMap.foldl/3`, `A.OrdMap.foldr/3`,
    A.RBMap.foldl/3, A.RBMap.foldr/3
  * Internals of all data structures have been changed
  * Split A.RBTree as A.RBTree.Map and A.RBTree.Set

## v0.2.0 (2020-10-25)

### Enhancements

  * Add `A.String.slugify/2`

### Breaking changes

  * Remove `A.Array` module

## v0.1.2 (2020-10-22)

### Enhancements

  * Add `pop_first/1` and `pop_last/1` to A.RBMap, A.RBSet and `A.OrdMap`
  * Add some guards to functions

### Bug fixes

  * A.RBSet.disjoint?/2 was not returning the expected value

## v0.1.1 (2020-10-21)

### Bug fixes

  * Fix incompatibility with Elixir 1.10

## v0.1.0 (2020-10-18)

  * Initial release
