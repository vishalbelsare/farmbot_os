defmodule Farmbot.CeleryScript.Runtime.UndefinedInstructionError do
  defexception [:message]
end

defmodule Farmbot.CeleryScript.Runtime.Instruction do
  alias Farmbot.CeleryScript.{AST, Address, Runtime}
  alias Runtime.{State, InstructionSet, UndefinedInstructionError}
  use Farmbot.Logger

  @exeutable_instructions [
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

  def apply(%State{} = state, %InstructionSet{} = is, %{__kind: name} = instruction) when name in @exeutable_instructions do
    impl = Map.get(is, name) || raise UndefinedInstructionError, "`#{name}` is not implemented or depreciated."
    case apply(impl, [state, is, instruction]) do
      %State{} = state -> state
      {:error, reason, state} when is_binary(reason) -> {:error, reason, state}
    end
  end
end
