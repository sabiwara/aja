:rand.seed(:exsss, {1, 2, 3})

size = 1000
range = 1..size
list = Enum.shuffle(range)
vector = A.Vector.new(list)

Benchee.run(%{
  "Enum.sort/1 (list)" => fn -> Enum.sort(list) end,
  "Enum.sort/1 (vector)" => fn -> Enum.sort(vector) end,
  "A.Vector.sort/1 (vector)" => fn -> A.Vector.sort(vector) end,
  "A.Enum.sort/1 (vector)" => fn -> A.Enum.sort(vector) end
})
