defmodule ReliableErrorHandlerTest do
  use ExUnit.Case
  doctest ReliableErrorHandler, [import: true]

  alias ReliableErrorHandler, as: Reh

  test "successful execution - foo, 1 arg" do
    assert Reh.handle(&foo_function/0) == {:ok, :foo}
  end

  test "successful execution - foo, 3 arg" do
    assert Reh.handle(__MODULE__, :foo_function, []) == {:ok, :foo}
  end

  test "successful execution - bar, 3 arg" do
    assert Reh.handle(__MODULE__, :bar_function, [4]) == {:ok, {:bar, 4}}
  end

  def foo_function do :foo end

  def bar_function(arg) do {:bar, arg} end
end
