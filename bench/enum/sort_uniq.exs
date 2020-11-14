defmodule Bench.Enum.SortUniq do
  def inputs() do
    for n <- [100, 10_000] do
      :rand.seed(:exsplus, {1, 2, 3})

      list =
        fn -> div(n, 3) |> :rand.uniform() end
        |> Stream.repeatedly()
        |> Enum.take(n)

      {"n = #{n}", list}
    end
  end

  def run() do
    Benchee.run(
      [
        {"A.Enum.sort_uniq/1", fn list -> A.Enum.sort_uniq(list) end},
        {"Enum.sort/1 |> Enum.dedup/1", fn list -> list |> Enum.sort() |> Enum.dedup() end},
        {"Enum.sort/1 |> Enum.uniq/1", fn list -> list |> Enum.sort() |> Enum.uniq() end}
      ],
      inputs: inputs()
    )
  end
end

Bench.Enum.SortUniq.run()
