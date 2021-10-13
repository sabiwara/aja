defmodule Bench.Maps.New do
  @shuffled true

  def inputs() do
    for n <- [100, 10_000], do: {"n = #{n}", n}
  end

  defp shuffle(enum) do
    if @shuffled do
      :rand.seed(:exrop, {1, 2, 3})
      Enum.shuffle(enum)
    else
      enum
    end
  end

  def run() do
    Benchee.run(
      [
        {"Map", &Map.new/1},
        {"Aja.OrdMap", &Aja.OrdMap.new/1}
      ],
      inputs: inputs(),
      before_scenario: fn n ->
        :rand.seed(:exrop, {1, 2, 3})
        1..n |> shuffle() |> Enum.map(fn i -> {i, "i"} end)
      end
    )
  end
end

Bench.Maps.New.run()
