list = Enum.to_list(1..50) ++ Enum.to_list(50..1)
vector = A.Vector.new(list)

Benchee.run(%{
  "A.Vector.uniq/1" => fn -> A.Vector.uniq(vector) end,
  "Enum.uniq/2 (list)" => fn -> Enum.uniq(list) end,
  "A.Vector.dedup/1" => fn -> A.Vector.dedup(vector) end,
  "Enum.dedup/2 (list)" => fn -> Enum.dedup(list) end
})
