defmodule Wormhole.Capture do
  require Logger

  alias Wormhole.Defaults

  def exec(callback, options) do
    capture(callback, options)
  end


  defp capture(callback, options) do
    timeout_ms  = Keyword.get(options, :timeout_ms)  || Defaults.timeout_ms
    callback    = callback |> Wormhole.CallbackWrapper.wrap

    task = Task.Supervisor.async_nolink(:wormhole_task_supervisor, callback)
    pid  = Map.get(task, :pid)

    task
    |> Task.yield(timeout_ms)
    |> terminate_child(pid)
    |> response_format(timeout_ms)
  end

  defp terminate_child(nil, pid) do
    Task.Supervisor.terminate_child :wormhole_task_supervisor, pid
    receive do {:DOWN, _, :process, ^pid, _} -> nil after 50 -> nil end
  end
  defp terminate_child(response, _pid) do response end

  defp response_format({:ok,   state},  _)          do {:ok,    state} end
  defp response_format({:exit, reason}, _)          do {:error, reason} end
  defp response_format(nil,             timeout_ms) do {:error, {:timeout, timeout_ms}} end

end
