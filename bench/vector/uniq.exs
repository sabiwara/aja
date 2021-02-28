list = Enum.to_list(1..50) ++ Enum.to_list(50..1)
vector = A.Vector.new(list)

Benchee.run(%{
  "A.Vector.uniq/1 (vector)" => fn -> A.Vector.uniq(vector) end,
  "A.Enum.uniq/1 (vector)" => fn -> A.Enum.uniq(vector) end,
  "Enum.uniq/2 (list)" => fn -> Enum.uniq(list) end
})
