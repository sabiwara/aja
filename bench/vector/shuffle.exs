size = 1000
range = 1..size
list = Enum.to_list(range)
vector = Aja.Vector.new(list)

Benchee.run(
  %{
    "Aja.Vector.shuffle/1 (vector)" => fn _ -> Aja.Vector.shuffle(vector) end,
    "Enum.shuffle/1 (list)" => fn _ -> Enum.shuffle(list) end,
    "Enum.shuffle/1 (vector)" => fn _ -> Enum.shuffle(vector) end,
    "Aja.Enum.shuffle/1 (vector)" => fn _ -> Aja.Enum.shuffle(vector) end
  },
  before_scenario: fn _ -> :rand.seed(:exrop, {101, 102, 103}) end
)
