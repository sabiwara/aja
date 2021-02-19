list = Enum.to_list(1..100)
vector = A.Vector.new(list)

Benchee.run(%{
  "A.Vector.intersperse/1" => fn -> A.Vector.intersperse(vector, ",") end,
  "Enum.intersperse/2 (list)" => fn -> Enum.intersperse(list, ",") end
})
