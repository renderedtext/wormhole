defmodule WormholeTest do
  use ExUnit.Case
  doctest Wormhole, [import: true]

  alias Wormhole

  test "successful execution - named function - foo, 1 arg" do
    assert Wormhole.capture(&foo_function/0) == {:ok, :foo}
  end

  test "successful execution - named function - foo, 3 arg" do
    assert Wormhole.capture(__MODULE__, :foo_function, []) == {:ok, :foo}
  end

  test "successful execution - named function - bar, 3 arg" do
    assert Wormhole.capture(__MODULE__, :bar_function, [4]) == {:ok, {:bar, 4}}
  end

  test "raised exception - unnamed function, 1 arg" do
    r = Wormhole.capture(fn-> raise "Something happened" end)
    assert r |> elem(0) == :error
    assert r |> elem(1) == {:shutdown, %RuntimeError{message: "Something happened"}}
  end

  test "thrown exception - unnamed function, 1 arg" do
    r = Wormhole.capture(fn-> throw "Something happened" end)
    assert r |> elem(0) == :error
    assert r |> elem(1) == {:shutdown, {:throw, "Something happened"}}
  end

  test "timeout - callback process not killed?" do
    assert Wormhole.capture(__MODULE__, :send_pid_and_freeze, [self], timeout_ms: 100) ==
            {:error, {:timeout, 100}}
    :timer.sleep(100)
    receive do
      {:worker_pid, pid} ->
        assert Process.alive?(pid)
    end
  end

  test "callback not function - unnamed" do
    assert Wormhole.capture(:a)   == {:error, {:shutdown, %BadFunctionError{term: :a}}}
    assert Wormhole.capture(self) == {:error, {:shutdown, %BadFunctionError{term: self}}}
  end

  test "callback not function - named" do
    r = Wormhole.capture(List, :foo, [])
    raised = struct(UndefinedFunctionError, %{arity: 0, function: :foo, module: List})
    assert r == {:error, {:shutdown, raised}}
  end

  test "retry count - fail" do
    retry_count = 3
    options = [timeout_ms: 100, retry_count: retry_count, backoff_ms: 10]
    assert Wormhole.capture(__MODULE__, :send_pid_and_freeze, [self], options) ==
            {:error, {:timeout, 100}}
    for _ <- 1..retry_count do
      assert_receive({:worker_pid, _})
    end
  end

  test "retry count - pass" do
    retry_count = 3
    options = [retry_count: retry_count]
    tester = self
    assert Wormhole.capture(fn-> send(tester, :aaa) end, options) == {:ok, :aaa}
    assert_receive(:aaa)
    refute_receive(:aaa, 300)
  end

  test "if response arived after timeout" do
    retry_count = 3
    options = [timeout_ms: 100, retry_count: retry_count, backoff_ms: 10]
    assert Wormhole.capture(fn-> :timer.sleep 150; :foo end, options) == {:error, {:timeout, 100}}
    refute_receive({_, :foo})
  end

  def foo_function do :foo end

  def bar_function(arg) do {:bar, arg} end

  def send_pid_and_freeze(destination) do
    send destination, {:worker_pid, self}
    :timer.sleep :infinity
  end
end
