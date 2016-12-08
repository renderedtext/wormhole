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

    task
    |> Task.yield(timeout_ms)
    |> task_demonitor(task)
    |> task_silence(task)
    |> response_format(timeout_ms)
  end

  defp task_demonitor(response, task) do
    Map.get(task, :ref) |> Process.demonitor([:flush])
    response
  end

  defp task_silence(response, task) do
    Map.get(task, :pid) |> send({:wormhole_timeout, :silence})
    response
  end

  defp response_format({:ok,   state},  _)          do {:ok,    state} end
  defp response_format({:exit, reason}, _)          do {:error, reason} end
  defp response_format(nil,             timeout_ms) do {:error, {:timeout, timeout_ms}} end

end
