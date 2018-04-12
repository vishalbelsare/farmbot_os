defmodule Farmbot.CeleryScript.Runtime.InstructionSet do
  @moduledoc """
  Replacable instructions to the CeleryScript Runtime.
  """

  alias Farmbot.CeleryScript.{AST, Runtime}
  alias Runtime.State
  defstruct [
    :_if,
    :calibrate,
    :check_updates,
    :emergency_lock,
    :execute,
    :execute_script,
    :factory_reset,
    :find_home,
    :home,
    :install_farmware,
    :install_first_party_farmware,
    :move_absolute,
    :move_relative,
    :nothing,
    :point,
    :power_off,
    :read_pin,
    :read_status,
    :reboot,
    :remove_farmware,
    :rpc_request,
    :send_message,
    :sequence,
    :set_user_env,
    :sync,
    :take_photo,
    :toggle_pin,
    :update_farmware,
    :wait,
    :write_pin,
    :zero
  ]

  def default do
    %__MODULE__{

      rpc_request: fn(state, instruction_set, instruction) ->
        label = instruction.label
        case Runtime.execute(%{state | pc: instruction.__body}, instruction_set) do
          %State{} = new_state ->
            :ok = Farmbot.BotState.emit(rpc_ok(label))
            new_state
          {:error, reason, %State{} = new_state} ->
            :ok = Farmbot.BotState.emit(rpc_error(label, reason))
            {:error, reason, new_state}
        end
      end,

      nothing: fn(state, _, instruction) -> %{state | pc: instruction.__next} end,

      read_status: fn(state, _, instruction) ->
        Farmbot.BotState.force_state_push()
        %{state | pc: instruction.__next}
      end
    }
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
