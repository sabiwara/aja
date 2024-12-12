defmodule Aja.TestHelpers do
  def ignore(expr) do
    expr
  end

  defmacro capture_error(expr) do
    quote do
      try do
        {:ok, unquote(expr)}
      rescue
        error ->
          %error_type{} = error
          {:error, error_type}
      end
    end
  end

  defmacro capture_error_without_type(expr) do
    quote do
      try do
        {:ok, unquote(expr)}
      rescue
        error ->
          :error
      end
    end
  end

  def spy_callback(fun) do
    {:ok, agent} = Agent.start_link(fn -> [] end)

    callback = fn arg ->
      Agent.update(agent, fn state -> [arg | state] end)
      fun.(arg)
    end

    pop_args = fn ->
      Agent.get_and_update(agent, fn state -> {Enum.reverse(state), []} end)
    end

    {callback, pop_args}
  end

  def with_seed(fun) when is_function(fun, 0) do
    Task.async(fn ->
      :rand.seed(:exsss, {101, 102, 103})
      fun.()
    end)
    |> Task.await()
  end
end
