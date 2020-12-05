# Changelog

## Dev

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
  * Split `A.RBTree` as `A.RBTree.Map` and `A.RBTree.Set`

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
