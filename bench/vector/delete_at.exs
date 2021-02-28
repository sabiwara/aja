n = 1000
list = Enum.to_list(1..n)
vector = A.Vector.new(list)

Benchee.run(%{
  "A.Vector.delete_at/2 (10)" => fn -> A.Vector.delete_at(vector, 10) end,
  "A.Vector.delete_at/2 (-1)" => fn -> A.Vector.delete_at(vector, -1) end,
  "A.Vector.delete_at/2 (-10)" => fn -> A.Vector.delete_at(vector, -10) end,
  "List.delete_at/2 (10)" => fn -> List.delete_at(list, 10) end,
  "List.delete_at/2 (-10)" => fn -> List.delete_at(list, n - 10) end
})
