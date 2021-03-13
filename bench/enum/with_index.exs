list = Enum.to_list(1..100)
vector = A.Vector.new(list)

Benchee.run(%{
  "A.Enum.with_index/1 (list)" => fn -> A.Enum.with_index(list) end,
  "A.Enum.with_index/1 (vector)" => fn -> A.Enum.with_index(vector) end,
  "Enum.with_index/1 (list)" => fn -> Enum.with_index(list) end,
  "Enum.with_index/1 (vector)" => fn -> Enum.with_index(vector) end
})
