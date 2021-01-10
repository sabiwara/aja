list = Enum.to_list(1..100)
vector = A.Vector.new(list)
raw = A.Vector.Raw.new(list)

Benchee.run(%{
  # XXX the API is different for Raw (start, last) != (start, length)
  "A.Vector.Raw.slice/3" => fn -> A.Vector.Raw.slice(raw, 10, 90) end,
  "A.Vector.slice/3 (vector)" => fn -> A.Vector.slice(vector, 10, 80) end,
  "Enum.slice/3 (vector)" => fn -> Enum.slice(vector, 10, 80) end,
  "Enum.slice/3 (list)" => fn -> Enum.slice(list, 10, 80) end
})
