defmodule Farmbot.CeleryScript.Runtime.Instruction do
  alias Farmbot.CeleryScript.{AST, Address, Runtime}
  alias Runtime.{State, Utils}
  import Utils
  use Farmbot.Logger

  def apply(%State{} = state, %{__kind: name} = instruction) do
    case name do
      # Sequence jumps into it's own body.
      :sequence ->
        %{state | pc: instruction.__body}
      :rpc_request ->
        label = instruction.label
        case Runtime.execute(%{state | pc: instruction.__body}) do
          %State{} = new_state ->
            :ok = Farmbot.BotState.emit(rpc_ok(label))
            new_state
          {:error, reason, %State{} = new_state} ->
            :ok = Farmbot.BotState.emit(rpc_error(label, reason))
            {:error, reason, new_state}
        end
      :read_status ->
        Farmbot.BotState.force_state_push()
        %{state | pc: instruction.__next}
      :nothing ->
        %{state | pc: instruction.__next}
      unknown ->
        Logger.error 3, "unimplemented instruction: #{unknown} #{inspect instruction}"
        {:error, "unimplemented", %{state | pc: instruction.__next}}
    end
  end

  def rpc_ok(label) do
    {:ok, ast} = AST.decode(%{kind: :rpc_ok, args: %{label: label}})
    ast
  end

  def rpc_error(label, reason) do
    explanation = %{kind: :explanation, args: %{message: reason}}
    {:ok, ast} = AST.decode(%{kind: :rpc_error, args: %{label: label}, body: [explanation]})
    ast
  end

  def nothing do
    {:ok, ast} = AST.decode(%{kind: :nothing, args: %{}, body: []})
    ast
  end
end
