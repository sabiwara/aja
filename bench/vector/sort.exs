:rand.seed(:exsss, {1, 2, 3})

size = 1000
range = 1..size
list = Enum.shuffle(range)
vector = Aja.Vector.new(list)

Benchee.run(%{
  "Enum.sort/1 (list)" => fn -> Enum.sort(list) end,
  "Enum.sort/1 (vector)" => fn -> Enum.sort(vector) end,
  "Aja.Vector.sort/1 (vector)" => fn -> Aja.Vector.sort(vector) end,
  "Aja.Enum.sort/1 (vector)" => fn -> Aja.Enum.sort(vector) end
})
