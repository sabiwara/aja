list = Enum.to_list(1..100)
vector = A.Vector.new(list)

Benchee.run(%{
  "A.Vector.with_index/1" => fn -> A.Vector.with_index(vector) end,
  "Enum.with_index/1" => fn -> Enum.with_index(list) end
})
