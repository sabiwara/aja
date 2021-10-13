defmodule Aja.Vector.IndexError do
  defexception [:index, :size]

  @impl true
  def exception(index: index, size: size) do
    %__MODULE__{index: index, size: size}
  end

  @impl true
  def message(%__MODULE__{index: index, size: 0}) do
    "out of bound index: #{index} for empty vector"
  end

  def message(%__MODULE__{index: index, size: size}) do
    "out of bound index: #{index} not in #{-size}..#{size - 1}"
  end
end

defmodule Aja.Vector.EmptyError do
  defexception []

  @impl true
  def exception(_) do
    %__MODULE__{}
  end

  @impl true
  def message(%__MODULE__{}) do
    "empty vector error"
  end
end
