defmodule Bench.Maps.Fetch do
  def inputs() do
    for n <- [10, 100, 10_000] do
      {"n = #{n}", n}
    end
  end

  def create_scenario(from_list_callback, fetch_callback) do
    {
      fn {map, keys} -> Enum.map(keys, fn key -> fetch_callback.(map, key) end) end,
      before_scenario: fn n ->
        map = 1..n |> Enum.map(fn i -> {i, i + 1} end) |> from_list_callback.()
        # use several keys to be more representative
        keys = sample_keys(n, 3) ++ sample_keys(n, 4)
        {map, keys}
      end
    }
  end

  defp sample_keys(n, p) do
    1..(p - 1) |> Enum.map(fn i -> div(i * n, p) end)
  end

  def run() do
    Benchee.run(
      [
        {"Map", create_scenario(&Map.new/1, fn map, key -> Map.fetch!(map, key) end)},
        {"Aja.OrdMap",
         create_scenario(&Aja.OrdMap.new/1, fn map, key -> Aja.OrdMap.fetch!(map, key) end)}
      ],
      inputs: inputs()
    )
  end
end

Bench.Maps.Fetch.run()
