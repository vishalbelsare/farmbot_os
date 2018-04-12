defmodule Farmbot.CeleryScript.Runtime.State do
  alias Farmbot.CeleryScript.Address
  defstruct [
    heap: nil,
    stack: [],
    sp: Address.new(0),
    pc: Address.new(1),
    ref: nil
  ]
end
