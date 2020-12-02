# TODO bench bigger numbers
list = Enum.to_list(1..100)
vector = A.Vector.new(list)

Benchee.run(%{
  "A.Vector.join/1" => fn -> A.Vector.join(vector, ",") end,
  "Enum.join/2 (list)" => fn -> Enum.join(list, ",") end
})
