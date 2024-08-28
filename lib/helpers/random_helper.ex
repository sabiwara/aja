defmodule Aja.RandomHelper do
  @moduledoc false

  # TODO Remove this module when dropping support for Elixir 1.16

  # vendoring Elixir's 1.17 implementation of take_random/2 and shuffle/1 which are:
  # - faster
  # - necessary to keep CI deterministic across multiple Elixir versions

  def shuffle(enumerable) do
    randomized =
      Enum.reduce(enumerable, [], fn x, acc ->
        [{:rand.uniform(), x} | acc]
      end)

    shuffle_unwrap(:lists.keysort(1, randomized))
  end

  defp shuffle_unwrap([{_, h} | rest]), do: [h | shuffle_unwrap(rest)]
  defp shuffle_unwrap([]), do: []

  def take_random(enumerable, count)
  def take_random(_enumerable, 0), do: []
  def take_random([], _), do: []

  def take_random(enumerable, 1) do
    enumerable
    |> Enum.reduce({0, 0, 1.0, nil}, fn
      elem, {idx, idx, w, _current} ->
        {jdx, w} = take_jdx_w(idx, w, 1)
        {idx + 1, jdx, w, elem}

      _elem, {idx, jdx, w, current} ->
        {idx + 1, jdx, w, current}
    end)
    |> case do
      {0, 0, 1.0, nil} -> []
      {_idx, _jdx, _w, current} -> [current]
    end
  end

  def take_random(enumerable, count) when count in 0..128 do
    sample = Tuple.duplicate(nil, count)

    reducer = fn
      elem, {idx, jdx, w, sample} when idx < count ->
        rand = take_index(idx)
        sample = sample |> put_elem(idx, elem(sample, rand)) |> put_elem(rand, elem)

        if idx == jdx do
          {jdx, w} = take_jdx_w(idx, w, count)
          {idx + 1, jdx, w, sample}
        else
          {idx + 1, jdx, w, sample}
        end

      elem, {idx, idx, w, sample} ->
        pos = :rand.uniform(count) - 1
        {jdx, w} = take_jdx_w(idx, w, count)
        {idx + 1, jdx, w, put_elem(sample, pos, elem)}

      _elem, {idx, jdx, w, sample} ->
        {idx + 1, jdx, w, sample}
    end

    {size, _, _, sample} = Enum.reduce(enumerable, {0, count - 1, 1.0, sample}, reducer)

    if count < size do
      Tuple.to_list(sample)
    else
      take_tupled(sample, size, [])
    end
  end

  def take_random(enumerable, count) when is_integer(count) and count >= 0 do
    reducer = fn
      elem, {idx, jdx, w, sample} when idx < count ->
        rand = take_index(idx)
        sample = sample |> Map.put(idx, Map.get(sample, rand)) |> Map.put(rand, elem)

        if idx == jdx do
          {jdx, w} = take_jdx_w(idx, w, count)
          {idx + 1, jdx, w, sample}
        else
          {idx + 1, jdx, w, sample}
        end

      elem, {idx, idx, w, sample} ->
        pos = :rand.uniform(count) - 1
        {jdx, w} = take_jdx_w(idx, w, count)
        {idx + 1, jdx, w, %{sample | pos => elem}}

      _elem, {idx, jdx, w, sample} ->
        {idx + 1, jdx, w, sample}
    end

    {size, _, _, sample} = Enum.reduce(enumerable, {0, count - 1, 1.0, %{}}, reducer)
    take_mapped(sample, Kernel.min(count, size), [])
  end

  @compile {:inline, take_jdx_w: 3, take_index: 1}
  defp take_jdx_w(idx, w, count) do
    w = w * :math.exp(:math.log(:rand.uniform()) / count)
    jdx = idx + floor(:math.log(:rand.uniform()) / :math.log(1 - w)) + 1
    {jdx, w}
  end

  defp take_index(0), do: 0
  defp take_index(idx), do: :rand.uniform(idx + 1) - 1

  defp take_tupled(_sample, 0, acc), do: acc

  defp take_tupled(sample, position, acc) do
    position = position - 1
    take_tupled(sample, position, [elem(sample, position) | acc])
  end

  defp take_mapped(_sample, 0, acc), do: acc

  defp take_mapped(sample, position, acc) do
    position = position - 1
    take_mapped(sample, position, [Map.fetch!(sample, position) | acc])
  end
end
