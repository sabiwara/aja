list = Enum.to_list(1..100)
vector = A.Vector.new(list)

fun = fn x -> [x, x] end

Benchee.run(%{
  "A.Vector.flat_map/2 (vector)" => fn -> A.Vector.flat_map(vector, fun) end,
  "A.Enum.flat_map/2 (vector)" => fn -> A.Enum.flat_map(vector, fun) end,
  "A.Enum.flat_map/2 (list)" => fn -> A.Enum.flat_map(list, fun) end,
  "Enum.flat_map/2 (list)" => fn -> Enum.flat_map(list, fun) end
})
