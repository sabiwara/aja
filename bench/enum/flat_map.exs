list = Enum.to_list(1..100)
vector = Aja.Vector.new(list)

fun = fn x -> [x, x] end

Benchee.run(%{
  "Aja.Vector.flat_map/2 (vector)" => fn -> Aja.Vector.flat_map(vector, fun) end,
  "Aja.Enum.flat_map/2 (vector)" => fn -> Aja.Enum.flat_map(vector, fun) end,
  "Aja.Enum.flat_map/2 (list)" => fn -> Aja.Enum.flat_map(list, fun) end,
  "Enum.flat_map/2 (list)" => fn -> Enum.flat_map(list, fun) end
})
