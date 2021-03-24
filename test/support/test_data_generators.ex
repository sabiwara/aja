defmodule A.TestDataGenerators do
  import StreamData

  def simple_value do
    one_of([float(), string(:printable), atom(:alphanumeric)])
    |> log_rescale()
  end

  def big_positive_integer, do: positive_integer() |> scale(&(&1 * 100))

  def log_rescale(generator) do
    scale(generator, &trunc(:math.log(&1)))
  end
end
