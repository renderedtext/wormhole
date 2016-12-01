defmodule Wormhole.Capture do
  require Logger

  @timeout_ms  5_000
  @retry_count 1
  @backoff_ms  1_000

  def capture(callback, options) do
    capture_(callback, options)
    |> logger(callback)
  end

  def capture(module, function, args, options), do:
    capture_(fn-> apply(module, function, args) end, options)
    |> logger({module, function, args})


  #################  implementation  #################

  defp capture_(callback, options) when is_function(callback) do
    timeout_ms  = Keyword.get(options, :timeout_ms)  || @timeout_ms
    retry_count = Keyword.get(options, :retry_count) || @retry_count
    backoff_ms  = Keyword.get(options, :backoff_ms)  || @backoff_ms

    callback_exec_and_response_retry(
          {:error, {:invalid_value, {:retry_count, 0}}},
          callback, timeout_ms, retry_count, backoff_ms)
  end
  defp capture_(callback, _options) do
    {:error, {:not_function, callback}}
  end

  defp callback_exec_and_response_retry(prev_response,
        _callback, _timeout_ms, 0, _backoff_ms) do
    prev_response
  end
  defp callback_exec_and_response_retry(_prev_response,
        callback, timeout_ms, retry_count, backoff_ms) do
    task = Task.Supervisor.async_nolink(:wormhole_task_supervisor, callback)
    pid = Map.get(task, :pid)

    task
    |> Task.yield(timeout_ms)
    |> terminate_child(pid)
    |> response_format(timeout_ms)
    |> retry({callback, timeout_ms, retry_count, backoff_ms})
  end

  defp terminate_child(nil, pid) do
    Task.Supervisor.terminate_child :wormhole_task_supervisor, pid
    receive do {:DOWN, _, :process, ^pid, _} -> nil end
  end
  defp terminate_child(response, pid) do response end

  defp response_format({:ok,   state},  _)          do {:ok,    state} end
  defp response_format({:exit, reason}, _)          do {:error, reason} end
  defp response_format(nil,             timeout_ms) do {:error, {:timeout, timeout_ms}} end

  defp retry(response={:ok, _}, _) do response end
  defp retry(response, {callback, timeout_ms, retry_count, backoff_ms}) do
    retry_count = retry_count - 1
    if(retry_count > 0) do
      Logger.warn "#{__MODULE__}:: Retrying #{retry_count}, callback: #{inspect callback}; reason: #{inspect response}"
      :timer.sleep(backoff_ms)
    end

    callback_exec_and_response_retry(response,
          callback, timeout_ms, retry_count, backoff_ms)
  end

  defp logger(response = {:ok, _},    _callback), do: response
  defp logger(response = {:error, reason}, callback)   do
    Logger.warn "#{__MODULE__}:: callback: #{inspect callback}; reason: #{inspect reason}";

    response
  end
end
