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
    assert r |> elem(1) |> elem(0) == %RuntimeError{message: "Something happened"}
  end

  test "thrown exception - unnamed function, 1 arg" do
    r = Wormhole.capture(fn-> throw "Something happened" end)
    assert r |> elem(0) == :error
    assert r |> elem(1) |> elem(0) ==  {:nocatch, "Something happened"}
  end

  test "timeout - callback process killed?" do
    assert Wormhole.capture(__MODULE__, :send_pid, [self], 100) == {:error, {:timeout, 100}}
    :timer.sleep(100)
    receive do
      {:worker_pid, pid} ->
        refute Process.alive?(pid)
    end
  end

  test "callback not function - unnamed" do
    assert Wormhole.capture(:a)   == {:error, {:not_function, :a}}
    assert Wormhole.capture(self) == {:error, {:not_function, self}}
  end

  test "callback not function - named" do
    r = Wormhole.capture(List, :foo, [])
    assert r |> elem(0) == :error
    assert r |> elem(1) |> elem(0) == :undef
  end

  def foo_function do :foo end

  def bar_function(arg) do {:bar, arg} end

  def send_pid(destination) do
    send destination, {:worker_pid, self}
    :timer.sleep :infinity
  end
end
