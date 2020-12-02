# TODO bench bigger numbers
list = Enum.to_list(1..1000)
vector = A.Vector.new(list)

Benchee.run(%{
  "A.Vector.sum/1" => fn -> A.Vector.sum(vector) end,
  "A.Vector.foldl/3" => fn -> A.Vector.foldl(vector, 0, &+/2) end,
  "Enum.sum/1 (list)" => fn -> Enum.sum(list) end,
  ":lists.sum/1" => fn -> :lists.sum(list) end
})
