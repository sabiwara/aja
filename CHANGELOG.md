# Changelog

## Dev

### Enhancements

* Improve efficiency of vector access functions: `A.Vector.at/2`,
  `A.Vector.fetch/2`, `A.Vector.replace_at/3`,  `A.Vector.delete_at/2`...  ⚡️

### Bug fixes

* Invoke callbacks in the right order for: `A.Vector.filter/2`,
  `A.Vector.reject/2` and improve performance

## v0.4.4 (2021-01-23)

### Enhancements

* Add `A.vec_size/1` macro
* Add `A.Vector.with_index/2`
* Add `A.Vector.random/1`, `A.Vector.take_random/2` and `A.Vector.shuffle/1`
* Drastically improve efficiency of `A.Vector.duplicate/2` ⚡️⚡️⚡️

### Breaking changes

  * Changed internal representation of `A.Vector` (only breaking if persisted)
  * Stop documenting and exposing internal trees (A.RBTree)
  * Rename and deprecate `A.Vector.append_many/2` to `A.Vector.concat/2`

## v0.4.3 (2021-01-12)

This release is mostly focused on vector slicing and performance ⚡️

### Enhancements

* Add `A.Vector.each/2`
* Add `A.Vector.slice/2`, `A.Vector.slice/3`, `A.Vector.take/2` and `A.Vector.drop/2`
* `A.Vector` efficiently implements `Enumerable.slice/1`
* Reimplement `A.Vector.delete_at/2`, `A.Vector.pop_at/2` efficiently

## v0.4.2 (2021-01-10)

### Enhancements

* Implement `A.Vector.product/1`

### Bug fixes

* Invoke callbacks in the right order for: `A.Vector.map/2`,
  `A.Vector.map_intersperse/3`, `A.Vector.map_join/3`,
  `A.Vector.any?/2`, `A.Vector.all?/2`

## v0.4.1 (2020-12-05)

### Enhancements

* Add `A.Vector.map_join/3` and `A.Vector.map_intersperse/3`
* Implement `A.Vector.intersperse/2` more efficiently

### Bug fixes

* `A.Vector.sum/1` adds using the same order as `Enum.sum/1`,
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

* Add `A.Enum.sort_uniq/1`, `A.Enum.sort_uniq/2`
* Add `A.List.prepend/2`

## v0.3.1 (2020-11-05)

### Bug fixes

  * `A.RBMap.Enumerable.member?/2` returns `false` instead of crashing for values
    other than size-2 tuples

## v0.3.0 (2020-10-31)

### Enhancements

  * Rework all internals, improved peformance for `A.OrdMap`, `A.RBMap`, `A.RBSet`
  * Add `default` parameter to `A.OrdMap.first/1`, `A.OrdMap.last/1`,
   `A.RBMap.first/1`, `A.RBMap.last/1`, `A.RBSet.first/1`, `A.RBSet.last/1`

### Breaking changes

  * Changed signature of `A.OrdMap.foldl/3`, `A.OrdMap.foldr/3`,
    `A.RBMap.foldl/3`, `A.RBMap.foldr/3`
  * Internals of all data structures have been changed
  * Split `A.RBTree` as A.RBTree.Map and A.RBTree.Set

## v0.2.0 (2020-10-25)

### Enhancements

  * Add `A.String.slugify/2`

### Breaking changes

  * Remove `A.Array` module

## v0.1.2 (2020-10-22)

### Enhancements

  * Add `pop_first/1` and `pop_last/1` to `A.RBMap`, `A.RBSet` and `A.OrdMap`
  * Add some guards to functions

### Bug fixes

  * `A.RBSet.disjoint?/2` was not returning the expected value

## v0.1.1 (2020-10-21)

### Bug fixes

  * Fix incompatibility with Elixir 1.10

## v0.1.0 (2020-10-18)

  * Initial release
