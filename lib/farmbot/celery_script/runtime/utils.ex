defmodule Farmbot.CeleryScript.Runtime.Utils do
  alias Farmbot.CeleryScript.Runtime
  def vm_debug(%Runtime.State{} = state, str) do
    IO.puts "[CS VM #{inspect state}]: #{str}"
    state
  end
end
