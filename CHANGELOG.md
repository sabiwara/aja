# Changelog

## Dev

## v0.6.2 (2023-03-10)

### Enhancements

- `Aja.OrdMap.from_struct/1` respects the defined field order (Elixir >= 1.14)

## v0.6.1 (2022-02-04)

### Enhancements

- Add `Aja.OrdMap.filter/2` and `Aja.OrdMap.reject/2`
- Add `Aja.OrdMap.from_keys/2`
- Bump `ex_doc` to the latest version

## v0.6.0 (2021-10-16)

### Breaking changes

- Rename top module from `A` to `Aja`
- Remove deprecated Aja.ExRange module
- Remove deprecated functions

## v0.5.3 (2021-08-20)

### Enhancement

- Optimize `Aja.OrdMap` internals to reduce memory usage

### Bug fixes

- Fix compilation warning in deprecated module

## v0.5.2 (2021-07-01)

### Enhancement

- Add support for stepped ranges in Elixir 1.12
- More efficient implementation of vector concatenation
- Add `Aja.Enum.concat/1` and `Aja.Enum.into/3`
- Add `Aja.Vector.zip_with/3`

### Bug fixes

- Fix bug in `Aja.Enum.into/2` when merging into an `Aja.OrdMap`
- Fix `Aja.vec/1` bug when ranges use negative number

### Breaking changes

- Deprecate Aja.ExRange

## v0.5.1 (2021-04-09)

### Enhancements

- Add `Aja.Vector.flat_map/2`
- Add `Aja.Vector.reverse/2` and `Aja.Enum.reverse/2`
- Add `Aja.Enum.concat/2`
- Add `Aja.Enum.zip/2` and `Aja.Enum.unzip/1`
- `Aja.OrdMap.drop/2` will only try to period rebuild once after dropping all
  keys

### Bug fixes

- Fix the minimal version needed for `Jason` (1.2)
- `Aja.OrdMap.take/2` behaves as expected when keys are duplicated
- `Aja.ord/1` warning on duplicate keys uses the proper stacktrace

### Breaking changes

- Change `Inspect` protocol for `Aja.Vector` and `Aja.OrdMap`
- Deprecate Aja.Enum.sort_uniq/1, Aja.Enum.sort_uniq/2

## v0.5.0 (2021-03-25)

### Enhancements

- `Aja.OrdMap` new implemention, with highly improved performance ⚡️⚡️
- `Aja.Enum` as a faster `Enum` module optimized for Aja structures (vectors,
  ord maps)
- Added `Aja.ord_size/1` macro
- `Aja.vec/1` can pattern-match on first and last elements
- `Aja.ord/1` warns on duplicate errors and can generate the AST on compile time
  for constant keys

### Breaking changes

- Reimplement `Aja.OrdMap`, changing its internals completely
- Change signature of `Aja.OrdMap.foldl/3` and `Aja.OrdMap.foldr/3` for
  consistency
- Remove Aja.OrdMap.pop_first/1 and Aja.OrdMap.pop_last/1
- Modify `Aja.Vector` internals (only breaking if persisted)
- Deprecate methods from `Aja.Vector` that have been moved to `Aja.Enum`
- Remove Aja.RBMap and Aja.RBSet
- Rename `Aja.List.repeat/2` and `Aja.Vector.repeat/2` (previously "repeatedly")

## v0.4.8 (2021-02-23)

### Enhancements

- Add `Aja.Vector.map_reduce/3`
- Add `Aja.Vector.scan/2` and `Aja.Vector.scan/3`
- `Aja.Vector.with_index/2` accepts a function parameter

### Breaking changes

- Deprecate Aja.RBMap and Aja.RBSet

### Bug fixes

- Fix Aja.Vector.join/2 bug when working with chardata

## v0.4.7 (2021-02-19)

### Enhancements

- Add Aja.Vector.reduce/2 and Aja.Vector.reduce/3
- Add `Aja.Vector.split/2` and `Aja.Vector.split_with/2`
- Add Aja.Vector.frequencies/1 and Aja.Vector.frequencies_by/2
- Add Aja.Vector.group_by/3
- Add `Aja.Vector.dedup/1` and `Aja.Vector.dedup_by/2`
- Add Aja.Vector.min/2, Aja.Vector.max/2, Aja.Vector.min_by/3,
  Aja.Vector.max_by/3
- Improve performance for Aja.Vector.min/1, Aja.Vector.max/1 and
  `Aja.Vector.uniq/1`

## v0.4.6 (2021-02-10)

### Enhancements

- Add Aja.Vector.find_index/2
- Add `Aja.Vector.take_while/2`, `Aja.Vector.drop_while/2` and
  `Aja.Vector.split_while/2`
- Add `Aja.Vector.zip/2` and `Aja.Vector.unzip/1`
- Add `Aja.Vector.fetch!/2` alias

## v0.4.5 (2021-01-31)

### Enhancements

- Add Aja.Vector.find/3 and Aja.Vector.find_value/3
- Add `Aja.+++/2` convenience operator
- Improve efficiency of vector access functions: `Aja.Vector.at/2`,
  `Aja.Vector.fetch/2`, `Aja.Vector.replace_at/3`, `Aja.Vector.delete_at/2`...
  ⚡️
- Improve compile times

### Bug fixes

- Invoke callbacks in the right order for: `Aja.Vector.filter/2`,
  `Aja.Vector.reject/2` and improve performance

## v0.4.4 (2021-01-23)

### Enhancements

- Add `Aja.vec_size/1` macro
- Add `Aja.Vector.with_index/2`
- Add Aja.Vector.random/1, `Aja.Vector.take_random/2` and `Aja.Vector.shuffle/1`
- Drastically improve efficiency of `Aja.Vector.duplicate/2` ⚡️⚡️⚡️

### Breaking changes

- Changed internal representation of `Aja.Vector` (only breaking if persisted)
- Stop documenting and exposing internal trees (Aja.RBTree)
- Rename and deprecate Aja.Vector.append_many/2 to `Aja.Vector.concat/2`

## v0.4.3 (2021-01-12)

This release is mostly focused on vector slicing and performance ⚡️

### Enhancements

- Add Aja.Vector.each/2
- Add `Aja.Vector.slice/2`, `Aja.Vector.slice/3`, `Aja.Vector.take/2` and
  `Aja.Vector.drop/2`
- `Aja.Vector` efficiently implements `Enumerable.slice/1`
- Reimplement `Aja.Vector.delete_at/2`, `Aja.Vector.pop_at/2` efficiently

## v0.4.2 (2021-01-10)

### Enhancements

- Implement Aja.Vector.product/1

### Bug fixes

- Invoke callbacks in the right order for: `Aja.Vector.map/2`,
  `Aja.Vector.map_intersperse/3`, Aja.Vector.map_join/3, Aja.Vector.any?/2,
  Aja.Vector.all?/2

## v0.4.1 (2020-12-05)

### Enhancements

- Add Aja.Vector.map_join/3 and `Aja.Vector.map_intersperse/3`
- Implement `Aja.Vector.intersperse/2` more efficiently

### Bug fixes

- Aja.Vector.sum/1 adds using the same order as `Enum.sum/1`, avoiding slight
  inconsistencies for floats

## v0.4.0 (2020-12-02)

### Enhancements

- Introduce persistent vectors: `Aja.Vector` 🚀️
- Add `Aja.vec/1`

## v0.3.3 (2020-11-14)

### Enhancements

- Add `Aja.sigil_i/2`
- Add `Aja.IO.to_iodata/1`

## v0.3.2 (2020-11-14)

### Enhancements

- Add Aja.Enum.sort_uniq/1, Aja.Enum.sort_uniq/2
- Add `Aja.List.prepend/2`

## v0.3.1 (2020-11-05)

### Bug fixes

- Aja.RBMap.Enumerable.member?/2 returns `false` instead of crashing for values
  other than size-2 tuples

## v0.3.0 (2020-10-31)

### Enhancements

- Rework all internals, improved peformance for `Aja.OrdMap`, Aja.RBMap,
  Aja.RBSet
- Add `default` parameter to `Aja.OrdMap.first/1`, `Aja.OrdMap.last/1`,
  Aja.RBMap.first/1, Aja.RBMap.last/1, Aja.RBSet.first/1, Aja.RBSet.last/1

### Breaking changes

- Changed signature of `Aja.OrdMap.foldl/3`, `Aja.OrdMap.foldr/3`,
  Aja.RBMap.foldl/3, Aja.RBMap.foldr/3
- Internals of all data structures have been changed
- Split Aja.RBTree as Aja.RBTree.Map and Aja.RBTree.Set

## v0.2.0 (2020-10-25)

### Enhancements

- Add `Aja.String.slugify/2`

### Breaking changes

- Remove `Aja.Array` module

## v0.1.2 (2020-10-22)

### Enhancements

- Add `pop_first/1` and `pop_last/1` to Aja.RBMap, Aja.RBSet and `Aja.OrdMap`
- Add some guards to functions

### Bug fixes

- Aja.RBSet.disjoint?/2 was not returning the expected value

## v0.1.1 (2020-10-21)

### Bug fixes

- Fix incompatibility with Elixir 1.10

## v0.1.0 (2020-10-18)

- Initial release
