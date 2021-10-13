range = 1..100
duplicates = 10

inputs = [
  list_of_lists: Enum.map(range, &List.duplicate(&1, duplicates)),
  list_of_vectors: Enum.map(range, &Aja.Vector.duplicate(&1, duplicates)),
  vector_of_lists: Aja.Vector.new(range, &List.duplicate(&1, duplicates)),
  vector_of_vectors: Aja.Vector.new(range, &Aja.Vector.duplicate(&1, duplicates))
]

Benchee.run(
  %{
    "Aja.Enum.concat/1" => fn enum -> Aja.Enum.concat(enum) end,
    "Enum.concat/1" => fn enum -> Enum.concat(enum) end
  },
  inputs: inputs
)
