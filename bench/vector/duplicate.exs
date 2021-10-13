inputs =
  Enum.map([100, 1_000, 100_000], fn n ->
    {"n = #{n}", n}
  end)

Benchee.run(
  %{
    "List.duplicate/2" => fn n -> List.duplicate(:x, n) end,
    "Aja.Vector.duplicate/2" => fn n -> Aja.Vector.duplicate(:x, n) end
  },
  inputs: inputs
)
