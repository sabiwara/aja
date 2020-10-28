defmodule Bench.IO.Empty do
  def inputs() do
    for n <- [0, 1, 10, 100] do
      :rand.seed(:exsplus, {1, 2, 3})
      iodata = Stream.repeatedly(fn -> <<?a..?z |> Enum.random()>> end) |> Enum.take(n)
      {"n = #{n}", iodata}
    end
  end

  def run() do
    Benchee.run(
      [
        {"IO.iodata_length() == 0", fn iodata -> IO.iodata_length(iodata) == 0 end},
        {"A.IO.iodata_empty?/1", fn iodata -> A.IO.iodata_empty?(iodata) end}
      ],
      inputs: inputs()
    )
  end
end

Bench.IO.Empty.run()
