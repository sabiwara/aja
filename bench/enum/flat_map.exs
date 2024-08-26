list = Enum.to_list(-50..50)
vector = Aja.Vector.new(list)

fun = fn x -> if x > 0, do: [x], else: [] end

Benchee.run(%{
  "Aja.Vector.flat_map/2 (vector)" => fn -> Aja.Vector.flat_map(vector, fun) end,
  "Aja.Enum.flat_map/2 (vector)" => fn -> Aja.Enum.flat_map(vector, fun) end,
  "Aja.Enum.flat_map/2 (list)" => fn -> Aja.Enum.flat_map(list, fun) end,
  "Enum.flat_map/2 (list)" => fn -> Enum.flat_map(list, fun) end
})
