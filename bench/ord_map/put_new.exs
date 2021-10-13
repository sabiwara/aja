defmodule Bench.Maps.PutNew do
  def inputs() do
    for n <- [10, 100, 10_000] do
      {"n = #{n}", n}
    end
  end

  def create_scenario(from_list_callback, put_callback) do
    {
      fn {map, keys} ->
        Enum.reduce(keys, map, fn key, acc -> put_callback.(acc, key, :foo) end)
      end,
      before_scenario: fn n ->
        map = 1..n |> Enum.map(fn i -> {i, i + 1} end) |> from_list_callback.()
        # use several keys to be more representative
        keys = [0, n + 1, n * 2]
        {map, keys}
      end
    }
  end

  def run() do
    Benchee.run(
      [
        {"Map", create_scenario(&Map.new/1, fn map, key, value -> Map.put(map, key, value) end)},
        {"Aja.OrdMap",
         create_scenario(&Aja.OrdMap.new/1, fn map, key, value ->
           Aja.OrdMap.put(map, key, value)
         end)}
      ],
      inputs: inputs()
    )
  end
end

Bench.Maps.PutNew.run()
