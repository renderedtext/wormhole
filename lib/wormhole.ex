defmodule Wormhole do
  require Logger

  @timeout_ms 3_000

  @description """
  Invokes `callback` and returns `callback` return value
  if finished successfully.
  Otherwise, reliably captures error reason of all possible error types.

  If `callback` execution is not finished within specified timeout,
  kills `callback` process and returns error.
  """

  @doc """
  #{@description}  Default timeout is #{@timeout_ms} milliseconds.

  Examples:
      iex> handle(fn-> :a end)
      {:ok, :a}

      iex> handle(fn-> raise "Something happened" end) |> elem(0)
      :error

      iex> r = handle(fn-> throw "Something happened" end) |> elem(0)
      :error

      iex> handle(fn-> exit :foo end)
      {:error, :foo}

      iex> handle(fn-> Process.exit(self, :foo) end)
      {:error, :foo}
  """
  def handle(callback), do:
    handle(callback, @timeout_ms)

  @doc """
  #{@description}  Default timeout is #{@timeout_ms} milliseconds.

  Examples:
      iex> handle(Enum, :count, [[]])
      {:ok, 0}

      iex> handle(Enum, :count, [:foo]) |> elem(0)
      :error
  """
  def handle(module, function, args), do:
    handle(module, function, args, @timeout_ms)

    @doc """
    #{@description}

    Examples:
        iex> handle(:timer, :sleep, [20], 50)
        {:ok, :ok}

        iex> handle(:timer, :sleep, [:infinity], 50)
        {:error, {:timeout, 50}}
    """
  def handle(module, function, args, timeout_ms), do:
    handle(fn-> apply(module, function, args) end, timeout_ms)

    @doc """
    #{@description}

    Examples:
        iex> handle(fn-> :timer.sleep 20 end, 50)
        {:ok, :ok}

        iex> handle(fn-> :timer.sleep :infinity end, 50)
        {:error, {:timeout, 50}}
    """
  def handle(callback, timeout_ms) do
    {pid, monitor} = callback |> propagate_return_value_wrapper |> spawn_monitor
    receive do
      {:DOWN, ^monitor, :process, ^pid, :normal} ->
        timeout_ms |> response_receive
      {:DOWN, ^monitor, :process, ^pid, reason}  ->
        Logger.error "Error in handeled function: #{inspect reason}";
        {:error, reason}
    after timeout_ms ->
      pid |> Process.exit(:kill)
      Logger.error "Timeout..."
      {:error, {:timeout, timeout_ms}}
    end
  end

  defp propagate_return_value_wrapper(callback) do
    caller_pid = self
    fn-> caller_pid |> send( {__MODULE__, :response, callback.()}) end
  end

  defp response_receive(timeout_ms) do
    receive do
      {__MODULE__, :response, response} ->
        {:ok, response}
    after timeout_ms ->
      Logger.error "#{__MODULE__}: Unexpected! Should never get here..."
      {:error, {:timeout, timeout_ms}}
    end
  end
end
