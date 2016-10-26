# Reliable Error Handler

Invoke any function in such way that all errors are captured.
If there are no errors return function-return-value.

By default, timeout is set to 3 seconds.

## Installation
Add to the list of dependencies:
```elixir
def deps do
  [
    {:reliable_error_handler, github: "renderedtext/reliable-error-handler"}
  ]
end
```
Add to the list of applications (only for Exrm):
```elixir
def application do
  [applications: [:reliable_error_handler]]
end
```

## Examples

### Successful execution - returning function return value
Unnamed function:
```elixir
iex> handle(fn-> :a end)
{:ok, :a}

```
Named function without arguments:
```elixir
handle(&Process.list/0)
{:ok, [#PID<0.0.0>, #PID<0.3.0>, #PID<0.6.0>, #PID<0.7.0>, ...]}
```
Named function with arguments:
```elixir
handle(Enum, :count, [[1,2,3]])
{:ok, 3}
```

Both versions with timeout explicitly set to 2 seconds:
```elixir
handle(&Process.list/0, 2_000)
{:ok, [#PID<0.0.0>, #PID<0.3.0>, #PID<0.6.0>, #PID<0.7.0>, ...]}

handle(Enum, :count, [[1,2,3]], 2_000)
{:ok, 3}
```

### Failed execution - returning failure reason
```elixir
defmodule Test do
  def f do
    raise "Hello"
  end
end

iex> handle(&Test.f/0)
{:error,
 {%RuntimeError{message: "Hello"},
  [{Test, :f, 0, [file: 'iex', line: 23]},
   {ReliableErrorHandler, :"-send_return_value/1-fun-0-", 2,
    [file: 'lib/reliable_error_handler.ex', line: 75]}]}}

iex> handle(fn-> throw :foo end)
{:error,
 {{:nocatch, :foo},
  [{ReliableErrorHandler, :"-send_return_value/1-fun-0-", 2,
    [file: 'lib/reliable_error_handler.ex', line: 75]}]}}

iex> handle(fn-> exit :foo end)
{:error, :foo}

```
