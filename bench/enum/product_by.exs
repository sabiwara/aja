list = Enum.map(1..1000, &(1 + rem(&1, 3)))
vector = Aja.Vector.new(list)

Benchee.run(%{
  "Aja.Enum.product_by/2 (vector)" => fn -> Aja.Enum.product_by(vector, & &1) end,
  "Enum.product_by/2 (vector)" => fn -> Enum.product_by(vector, & &1) end,
  "Aja.Enum.reduce/3 (vector)" => fn -> Aja.Enum.reduce(vector, 1, &*/2) end,
  "Enum.product_by/2 (list)" => fn -> Enum.product_by(list, & &1) end,
  # for comparison:
  "Enum.product(list)" => fn -> Enum.product(list) end,
  "Aja.Enum.product(vector)" => fn -> Aja.Enum.product(vector) end
})
