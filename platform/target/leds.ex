defmodule Farmbot.Target.Leds do
  # [17, 23, 27, 06, 21, 24, 25, 12, 13]
  use GenServer

  alias ElixirALE.GPIO

  def helper do
    start_link([17, 23, 27, 06, 21, 24, 25, 12, 13])
  end

  def start_link(leds) do
    GenServer.start_link(__MODULE__, [leds], [name: __MODULE__])
  end

  def on(pin) do
    GenServer.call(__MODULE__, {pin, :on})
  end

  def off(pin) do
    GenServer.call(__MODULE__, {pin, :off})
  end

  def init([leds]) do
    pids = Map.new(leds, fn(pin_number) ->
      {:ok, pid} = GPIO.start_link(pin_number, :output)
      {pin_number, pid}
    end)
    {:ok, pids}
  end

  def handle_call({pin, :on}, _, state) do
    GPIO.write(state[pin], 1)
    {:reply, :ok, state}
  end

  def handle_call({pin, :off}, _, state) do
    GPIO.write(state[pin], 0)
    {:reply, :ok, state}
  end
end
