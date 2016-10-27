defmodule ReliableErrorHandler do
  require Logger

  @timeout_ms 3_000

  @doc """
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
  Examples:
      iex> handle(Enum, :count, [[]])
      {:ok, 0}

      iex> handle(Enum, :count, [:foo]) |> elem(0)
      :error
  """
  def handle(module, function, args), do:
    handle(module, function, args, @timeout_ms)

    @doc """
    Examples:
        iex> handle(:timer, :sleep, [20], 50)
        {:ok, :ok}

        iex> handle(:timer, :sleep, [:infinity], 50)
        {:error, {:timeout, 50}}
    """
  def handle(module, function, args, timeout), do:
    handle(fn-> apply(module, function, args) end, timeout)

    @doc """
    Examples:
        iex> handle(fn-> :timer.sleep 20 end, 50)
        {:ok, :ok}

        iex> handle(fn-> :timer.sleep :infinity end, 50)
        {:error, {:timeout, 50}}
    """
  def handle(callback, timeout) do
    {pid, monitor} = spawn_monitor(send_return_value(callback))
    receive do
      {:DOWN, ^monitor, :process, ^pid, :normal} ->
        response_receive(timeout)
      {:DOWN, ^monitor, :process, ^pid, reason}  ->
        Logger.error "Error in handeled function: #{inspect reason}";
        {:error, reason}
    after timeout ->
      Logger.error "Timeout..."
      {:error, {:timeout, timeout}}
    end
  end

  defp send_return_value(callback) do
    caller_pid = self
    fn-> send(caller_pid, {__MODULE__, :response, callback.()}) end
  end

  defp response_receive(timeout) do
    receive do
      {__MODULE__, :response, response} ->
        {:ok, response}
    after timeout ->
      Logger.error "#{__MODULE__}: Unexpected! Should never get here..."
      {:error, {:timeout, timeout}}
    end
  end
end
