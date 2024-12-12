list = Enum.map(1..1000, &(1 + rem(&1, 3)))
vector = Aja.Vector.new(list)

Benchee.run(%{
  "Aja.Enum.sum_by/2 (vector)" => fn -> Aja.Enum.sum_by(vector, & &1) end,
  "Aja.Enum.sum_by/2 (list)" => fn -> Aja.Enum.sum_by(list, & &1) end,
  "Enum.sum_by/2 (vector)" => fn -> Enum.sum_by(vector, & &1) end,
  "Aja.Enum.reduce/3 (vector)" => fn -> Aja.Enum.reduce(vector, 0, &+/2) end,
  "Enum.sum_by/2 (list)" => fn -> Enum.sum_by(list, & &1) end,
  # for comparison:
  ":lists.sum/1" => fn -> :lists.sum(list) end
})
