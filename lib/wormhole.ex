defmodule Wormhole do
  require Logger

  @timeout_ms 3_000

  @description """
  Invokes `callback` in separate process and
  waits for message from callback process containing callback return value
  if finished successfully or
  error reason if callback process failed for any reason.

  If `callback` execution is not finished within specified timeout,
  kills `callback` process and returns error.
  """

  @doc """
  #{@description}  Default timeout is #{@timeout_ms} milliseconds.

  Examples:
      iex> capture(fn-> :a end)
      {:ok, :a}

      iex> capture(fn-> raise "Something happened" end) |> elem(0)
      :error

      iex> capture(fn-> throw "Something happened" end) |> elem(0)
      :error

      iex> capture(fn-> exit :foo end)
      {:error, :foo}

      iex> capture(fn-> Process.exit(self, :foo) end)
      {:error, :foo}

      iex> capture(fn-> :timer.sleep 20 end, 50)
      {:ok, :ok}

      iex> capture(fn-> :timer.sleep :infinity end, 50)
      {:error, {:timeout, 50}}
  """
  def capture(callback, timeout_ms \\ @timeout_ms)
  def capture(callback, timeout_ms) do
    capture_(callback, timeout_ms)
    |> log_error(callback)
  end


  @doc """
  #{@description}  Default timeout is #{@timeout_ms} milliseconds.

  Examples:
      iex> capture(Enum, :count, [[]])
      {:ok, 0}

      iex> capture(Enum, :count, [:foo]) |> elem(0)
      :error

      iex> capture(:timer, :sleep, [20], 50)
      {:ok, :ok}

      iex> capture(:timer, :sleep, [:infinity], 50)
      {:error, {:timeout, 50}}
  """
  def capture(module, function, args, timeout_ms \\ @timeout_ms)
  def capture(module, function, args, timeout_ms), do:
    capture_(fn-> apply(module, function, args) end, timeout_ms)
    |> log_error({module, function, args})


  #################  implementation  #################

  defp capture_(callback, timeout_ms) when is_function(callback) do
    Task.Supervisor.start_link
    |> callback_exec_and_response(callback, timeout_ms)
  end
  defp capture_(callback, _timeout_ms) do
    {:error, {:not_function, callback}}
  end

  defp callback_exec_and_response({:ok, sup}, callback, timeout_ms) do
    Task.Supervisor.async_nolink(sup, callback)
    |> Task.yield(timeout_ms)
    |> supervisor_stop(sup)
    |> response_format(timeout_ms)
  end
  defp callback_exec_and_response(start_link_response, _callback, _timeout_ms) do
    {:error, {:failed_to_start_supervisor, start_link_response}}
  end

  defp supervisor_stop(response, sup) do
    Process.unlink(sup)
    Process.exit(sup, :kill)

    response
  end

  defp response_format({:ok,   state},  _)          do {:ok,    state} end
  defp response_format({:exit, reason}, _)          do {:error, reason} end
  defp response_format(nil,             timeout_ms) do {:error, {:timeout, timeout_ms}} end


  defp log_error(response = {:ok, _},    _callback), do: response
  defp log_error(response = {:error, reason}, callback)   do
    Logger.error "#{__MODULE__}:: callback: #{inspect callback}; reason: #{inspect reason}";

    response
  end
end
