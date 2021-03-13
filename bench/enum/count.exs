list = Enum.to_list(1..100)
vector = A.Vector.new(list)

Benchee.run(%{
  "Enum.count/1 (list)" => fn -> Enum.count(list) end,
  "Enum.count/1 (vector)" => fn -> Enum.count(vector) end,
  "A.Enum.count/1 (vector)" => fn -> A.Enum.count(vector) end
})
