size = 1000
range = 1..size
list = Enum.to_list(range)
vector = Aja.Vector.new(list)

Benchee.run(
  %{
    ":rand.uniform/1" => fn _ -> :rand.uniform(size) end,
    "Aja.Enum.random/1 (vector)" => fn _ -> Aja.Enum.random(vector) end,
    "Enum.random/1 (list)" => fn _ -> Enum.random(list) end,
    "Enum.random/1 (vector)" => fn _ -> Enum.random(vector) end,
    "Enum.random/1 (range)" => fn _ -> Enum.random(range) end
  },
  before_scenario: fn _ -> :rand.seed(:exsss, {101, 102, 103}) end
)
