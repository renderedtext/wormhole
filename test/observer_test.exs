defmodule BeholderTest do
  @moduledoc """
  This is not a real test.
  It is usefull to observe process topology when capture() calls are nested.
  """

  use ExUnit.Case

  @tag :observer
  test "observer" do
    :observer.start()
    Supervisor.start_child(Wormhole.Supervisor,
      %{
        id: :nesto,
        start: {__MODULE__, :start_link, []},
        restart: :permanent,
      }
    )

    :timer.sleep :infinity
  end

  def start_link() do
    pid = spawn_link(&start_wormhole/0)
    {:ok, pid}
  end

  def start_wormhole do
    fn ->
      Process.register(self(), :wh_srv_1)
      fn ->
        Process.register(self(), :wh_srv_2)
        fn ->
          Process.register(self(), :wh_srv_3)
          :timer.sleep(20_000)
        end
        |> Wormhole.capture(timeout: 16_000)
      end
      |> Wormhole.capture(timeout: 17_000)
    end
    |> Wormhole.capture(timeout: 19_000)
    |> IO.inspect(label: "WH result")
  end

end
