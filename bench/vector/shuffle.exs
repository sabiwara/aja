size = 1000
range = 1..size
list = Enum.to_list(range)
vector = A.Vector.new(list)

Benchee.run(
  %{
    "A.Vector.shuffle/1 (vector)" => fn _ -> A.Vector.shuffle(vector) end,
    "Enum.shuffle/1 (list)" => fn _ -> Enum.shuffle(list) end,
    "Enum.shuffle/1 (vector)" => fn _ -> Enum.shuffle(vector) end,
    "A.Enum.shuffle/1 (vector)" => fn _ -> A.Enum.shuffle(vector) end
  },
  before_scenario: fn _ -> :rand.seed(:exrop, {101, 102, 103}) end
)
