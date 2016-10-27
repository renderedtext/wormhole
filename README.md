# Wormhole

![wormhole](wormhole.jpg)

## Description
Invokes `callback` and returns `calback` return value
if finished successfully.
Otherwise, reliably captures error reason of all possible error types.

By default, timeout is set to 3 seconds.

## Installation
Add to the list of dependencies:
```elixir
def deps do
  [
    {:wormhole, github: "renderedtext/wormhole"}
  ]
end
```
Add to the list of applications (only for Exrm):
```elixir
def application do
  [applications: [:wormhole]]
end
```

## Examples

### Successful execution - returning callback return value
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
   {Wormhole, :"-send_return_value/1-fun-0-", 2,
    [file: 'lib/wormhole.ex', line: 75]}]}}

iex> handle(fn-> throw :foo end)
{:error,
 {{:nocatch, :foo},
  [{Wormhole, :"-send_return_value/1-fun-0-", 2,
    [file: 'lib/wormhole.ex', line: 75]}]}}

iex> handle(fn-> exit :foo end)
{:error, :foo}

```

### Usage pattern
```elixir
def ... do
  ...
  (&some_function/0) |> handle |> some_function_response_handler
  ...
end

def some_function_response_handler({:ok, response}) do
 ...
end
def some_function_response_handler({:error, error}) do
 ...
end
```
