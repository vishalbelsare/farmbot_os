defmodule Farmbot.CeleryScript do
  @moduledoc """
  CeleryScript is the scripting language that Farmbot OS understands.
  """

  alias Farmbot.CeleryScript
  alias CeleryScript.{AST, Runtime}
  use Farmbot.Logger

  def execute(%AST{} = ast) do
    ref = Runtime.Scheduler.schedule(ast)
    case Runtime.Scheduler.await(ref) do
      :ok -> {:ok, struct(Macro.Env)}
      er -> er
    end
  end
end
