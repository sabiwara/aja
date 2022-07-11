list = Enum.to_list(1..20)
queue = Queue.new(list)
simple_queue = SimpleQueue.new(list)
peekable_queue = PeekableQueue.new(list)
keyed_queue = KeyedQueue.new(list)
raw_queue = :queue.from_list(list)

defmodule Runner do
  def run_times(initial, fun, times \\ 20)

  def run_times(initial, _fun, 0), do: initial

  def run_times(initial, fun, times) do
    value = fun.(initial, times)
    run_times(value, fun, times - 1)
  end
end

Benchee.run(%{
  "Queue" => fn -> Runner.run_times(queue, &Queue.append/2) end,
  "SimpleQueue" => fn -> Runner.run_times(simple_queue, &SimpleQueue.append/2) end,
  "PeekableQueue" => fn -> Runner.run_times(peekable_queue, &PeekableQueue.append/2) end,
  "KeyedQueue" => fn -> Runner.run_times(keyed_queue, &KeyedQueue.append/2) end,
  ":queue" => fn -> Runner.run_times(raw_queue, &:queue.in(&2, &1)) end
})
