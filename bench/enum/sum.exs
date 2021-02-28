# TODO bench bigger numbers
list = Enum.to_list(1..1000)
vector = A.Vector.new(list)

Benchee.run(%{
  "A.Enum.sum/1 (vector)" => fn -> A.Enum.sum(vector) end,
  "Enum.sum/1 (vector)" => fn -> Enum.sum(vector) end,
  "A.Enum.reduce/3 (vector)" => fn -> A.Enum.reduce(vector, 0, &+/2) end,
  "Enum.sum/1 (list)" => fn -> Enum.sum(list) end,
  ":lists.sum/1" => fn -> :lists.sum(list) end
})
