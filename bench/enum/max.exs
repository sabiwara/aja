list = Enum.to_list(1..1000)
vector = Aja.Vector.new(list)
set = MapSet.new(list)

Benchee.run(%{
  "Aja.Enum.max/1 (list)" => fn -> Aja.Enum.max(list) end,
  "Aja.Enum.max/1 (vector)" => fn -> Aja.Enum.max(vector) end,
  "Aja.Enum.max/1 (set)" => fn -> Aja.Enum.max(set) end,
  "Enum.max/1 (list)" => fn -> Enum.max(list) end,
  "Enum.max/1 (vector)" => fn -> Enum.max(vector) end,
  "Enum.max/1 (set)" => fn -> Enum.max(set) end,
  ":lists.max/1" => fn -> :lists.max(list) end
})
