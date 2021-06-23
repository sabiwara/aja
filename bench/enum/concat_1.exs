range = 1..100
duplicates = 10

inputs = [
  list_of_lists: Enum.map(range, &List.duplicate(&1, duplicates)),
  list_of_vectors: Enum.map(range, &A.Vector.duplicate(&1, duplicates)),
  vector_of_lists: A.Vector.new(range, &List.duplicate(&1, duplicates)),
  vector_of_vectors: A.Vector.new(range, &A.Vector.duplicate(&1, duplicates))
]

Benchee.run(
  %{
    "A.Enum.concat/1" => fn enum -> A.Enum.concat(enum) end,
    "Enum.concat/1" => fn enum -> Enum.concat(enum) end
  },
  inputs: inputs
)
