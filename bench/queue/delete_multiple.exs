list = Enum.to_list(1..20)
queue = Queue.new(list)
simple_queue = SimpleQueue.new(list)
peekable_queue = PeekableQueue.new(list)
raw_queue = :queue.from_list(list)

defmodule Runner do
  def run_times(initial, fun, times \\ 20)

  def run_times(initial, _fun, 0), do: initial

  def run_times(initial, fun, times) do
    value = fun.(initial)
    run_times(value, fun, times - 1)
  end
end

Benchee.run(%{
  "Queue" => fn -> Runner.run_times(queue, &Queue.delete_first/1) end,
  ":queue" => fn -> Runner.run_times(raw_queue, &:queue.drop/1) end
})
