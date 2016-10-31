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
  """
  def capture(callback), do:
    capture(callback, @timeout_ms)

  @doc """
  #{@description}

  Examples:
      iex> capture(fn-> :timer.sleep 20 end, 50)
      {:ok, :ok}

      iex> capture(fn-> :timer.sleep :infinity end, 50)
      {:error, {:timeout, 50}}
  """
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
  """
  def capture(module, function, args), do:
    capture(module, function, args, @timeout_ms)

  @doc """
  #{@description}

  Examples:
      iex> capture(:timer, :sleep, [20], 50)
      {:ok, :ok}

      iex> capture(:timer, :sleep, [:infinity], 50)
      {:error, {:timeout, 50}}
  """
  def capture(module, function, args, timeout_ms), do:
    capture_(fn-> apply(module, function, args) end, timeout_ms)
    |> log_error({module, function, args})


  @doc """
  capture implementation
  """
  defp capture_(callback, timeout_ms) when is_function(callback) do
    {pid, monitor} = callback |> propagate_return_value_wrapper |> spawn_monitor
    receive do
      {:DOWN, ^monitor, :process, ^pid, :normal} ->
        timeout_ms |> response_receive
      {:DOWN, ^monitor, :process, ^pid, reason}  ->
        {:error, reason}
    after timeout_ms ->
      pid |> Process.exit(:kill)
      {:error, {:timeout, timeout_ms}}
    end
  end
  defp capture_(callback, _timeout_ms) do
    {:error, {:not_function, callback}}
  end

  defp propagate_return_value_wrapper(callback) do
    caller_pid = self
    fn-> caller_pid |> send( {__MODULE__, :response, callback.()}) end
  end

  defp response_receive(timeout_ms) do
    receive do
      {__MODULE__, :response, response} ->
        {:ok, response}
    # response should be here before process terminates and
    # should not be awaited for at all
    after 50 ->
      {:error, {:unexpected, :no_response}}
    end
  end


  defp log_error(response = {:ok, _},    _callback), do: response
  defp log_error(response = {:error, reason}, callback)   do
    Logger.error "#{__MODULE__}:: callback: #{inspect callback}; reason: #{inspect reason}";

    response
  end
end
