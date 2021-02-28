list = Enum.to_list(1..1000)
vector = A.Vector.new(list)
set = MapSet.new(list)

Benchee.run(%{
  "A.Enum.max/1 (list)" => fn -> A.Enum.max(list) end,
  "A.Enum.max/1 (vector)" => fn -> A.Enum.max(vector) end,
  "A.Enum.max/1 (set)" => fn -> A.Enum.max(set) end,
  "Enum.max/1 (list)" => fn -> Enum.max(list) end,
  "Enum.max/1 (vector)" => fn -> Enum.max(vector) end,
  "Enum.max/1 (set)" => fn -> Enum.max(set) end,
  ":lists.max/1" => fn -> :lists.max(list) end
})
