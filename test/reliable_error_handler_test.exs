defmodule ReliableErrorHandlerTest do
  use ExUnit.Case
  doctest ReliableErrorHandler, [import: true]

  alias ReliableErrorHandler, as: Reh

  test "successful execution - named function - foo, 1 arg" do
    assert Reh.handle(&foo_function/0) == {:ok, :foo}
  end

  test "successful execution - named function - foo, 3 arg" do
    assert Reh.handle(__MODULE__, :foo_function, []) == {:ok, :foo}
  end

  test "successful execution - named function - bar, 3 arg" do
    assert Reh.handle(__MODULE__, :bar_function, [4]) == {:ok, {:bar, 4}}
  end

  test "raised exception - unnamed function, 1 arg" do
    r = Reh.handle(fn-> raise "Something happened" end)
    assert r |> elem(0) == :error
    assert r |> elem(1) |> elem(0) == %RuntimeError{message: "Something happened"}
  end

  test "thrown exception - unnamed function, 1 arg" do
    r = Reh.handle(fn-> throw "Something happened" end)
    assert r |> elem(0) == :error
    assert r |> elem(1) |> elem(0) ==  {:nocatch, "Something happened"}
  end


  def foo_function do :foo end

  def bar_function(arg) do {:bar, arg} end
end
