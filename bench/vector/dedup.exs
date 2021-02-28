list = Enum.to_list(1..50) ++ Enum.to_list(50..1)
vector = A.Vector.new(list)

Benchee.run(%{
  "A.Vector.dedup/1 (vector)" => fn -> A.Vector.dedup(vector) end,
  "A.Enum.dedup/1 (vector)" => fn -> A.Enum.dedup(vector) end,
  "A.Enum.dedup/2 (list)" => fn -> A.Enum.dedup(list) end,
  "Enum.dedup/2 (list)" => fn -> Enum.dedup(list) end
})
