list = Enum.to_list(1..1000)
vector = A.Vector.new(list)

Benchee.run(%{
  "A.Vector.max/1" => fn -> A.Vector.max(vector) end,
  "Enum.max/1 (list)" => fn -> Enum.max(list) end,
  "Enum.max/1 (vector)" => fn -> Enum.max(vector) end,
  ":lists.max/1" => fn -> :lists.max(list) end
})
