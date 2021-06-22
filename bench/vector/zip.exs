list = Enum.to_list(1..100)
vector = A.Vector.new(list)

Benchee.run(%{
  "A.Vector.zip/2" => fn -> A.Vector.zip(vector, vector) end,
  "Enum.zip/2" => fn -> Enum.zip(list, list) end,
  "A.Enum.zip/2" => fn -> A.Enum.zip(list, list) end
})
