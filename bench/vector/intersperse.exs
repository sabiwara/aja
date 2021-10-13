list = Enum.to_list(1..100)
vector = Aja.Vector.new(list)

Benchee.run(%{
  "Aja.Vector.intersperse/1" => fn -> Aja.Vector.intersperse(vector, ",") end,
  "Enum.intersperse/2 (list)" => fn -> Enum.intersperse(list, ",") end,
  "Aja.Enum.intersperse/2 (vector)" => fn -> Aja.Enum.intersperse(vector, ",") end
})
