defmodule A.TestDataGenerators do
  import StreamData

  def simple_value do
    one_of([float(), string(:printable), atom(:alphanumeric)])
    |> log_rescale()
  end

  def big_positive_integer, do: positive_integer() |> scale(&(&1 * 100))

  def log_rescale(generator) do
    scale(generator, &trunc(:math.log(&1)))
  end

  def enumerable_of({key_generator, value_generator}) do
    one_of([
      do_enumerable_of({key_generator, value_generator}),
      do_map_of(key_generator, value_generator)
    ])
  end

  def enumerable_of(single_generator) do
    do_enumerable_of(single_generator)
  end

  defp do_enumerable_of(value_generator) do
    map({one_of([List, MapSet, Stream, A.Vector]), list_of(value_generator)}, fn
      {List, x} -> x
      {MapSet, x} -> MapSet.new(x)
      {Stream, x} -> Stream.map(x, & &1)
      {A.Vector, x} -> A.Vector.new(x)
    end)

    [& &1, &MapSet.new/1, &A.Vector.new/1, fn list -> Stream.map(list, & &1) end]
    |> Enum.map(fn fun -> map(list_of(value_generator), fun) end)
    |> one_of()
  end

  def collectable_of({key_generator, value_generator}) do
    one_of([
      do_collectable_of({key_generator, value_generator}),
      do_map_of(key_generator, value_generator)
    ])
  end

  def collectable_of(single_generator) do
    do_collectable_of(single_generator)
  end

  defp do_collectable_of(value_generator) do
    [&MapSet.new/1, &A.Vector.new/1]
    |> Enum.map(fn fun -> map(list_of(value_generator), fun) end)
    |> one_of()
  end

  def do_map_of(key_generator, value_generator) do
    [&Map.new/1, &A.OrdMap.new/1]
    |> Enum.map(fn fun -> map(list_of({key_generator, value_generator}), fun) end)
    |> one_of()
  end
end
