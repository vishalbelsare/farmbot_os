defmodule Farmbot.CeleryScript.Runtime.InstructionSet do
  @moduledoc """
  Replacable instructions to the CeleryScript Runtime.
  """

  alias Farmbot.CeleryScript.{AST, Runtime}
  alias Runtime.State
  use Farmbot.Logger

  @fpf_url Application.get_env(:farmbot, :farmware, :first_part_farmware_manifest_url)

  defstruct [
    :_if,
    :calibrate,
    :check_updates,
    :change_ownership,
    :emergency_lock,
    :emergency_unlock,
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
      _if: nil,

      calibrate: fn(state, _, instruction) ->
        case instruction.axis do
          :all -> {{:error, "maping not supported yet."}, state}
          axis when axis in [:x, :y, :z] ->
            {Farmbot.Firmware.calibrate(axis), inc_pc(state, instruction)}
        end
      end,

      change_ownership: nil,

      check_updates: fn(state, _, instruction) ->
        case Farmbot.System.Updates.check_updates() do
          {:error, reason} -> {{:error, reason}, inc_pc(state, instruction)}
          nil -> {:ok, inc_pc(state, instruction)}
          url ->
            case Farmbot.System.Updates.download_and_apply_update(url) do
              :ok -> {:ok, inc_pc(state, instruction)}
              {:error, reason} -> {{:error, reason}, inc_pc(state, instruction)}
            end
        end
      end,

      emergency_lock: fn(state, _, instruction) ->
        {Farmbot.Firmware.emergency_lock(), inc_pc(state, instruction)}
      end,

      emergency_unlock: fn(state, _, instruction) ->
        {Farmbot.Firmware.emergency_unlock(), inc_pc(state, instruction)}
      end,

      execute: nil,
      execute_script: nil,

      factory_reset: fn(state, _, instruction) ->
        case instruction.package do
          :farmbot_os ->
            Farmbot.BotState.set_sync_status(:maintenance)
            Farmbot.BotState.force_state_push()
            Farmbot.System.ConfigStorage.update_config_value(:bool, "settings", "disable_factory_reset", false)
            Logger.warn 1, "Farmbot OS going down for factory reset!"
            Farmbot.System.factory_reset("CeleryScript request.")
            {:ok, inc_pc(state, instruction)}
          :arduino_firmware ->
            Farmbot.BotState.set_sync_status(:maintenance)
            Logger.warn 1, "Arduino Firmware going down for factory reset!"
            Farmbot.HTTP.delete!("/api/firmware_config")
            pl = Poison.encode!(%{"api_migrated" => true})
            Farmbot.HTTP.put!("/api/firmware_config", pl)
            Farmbot.Bootstrap.SettingsSync.do_sync_fw_configs()
            Farmbot.BotState.reset_sync_status()
            {:ok, inc_pc(state, instruction)}
        end
      end,

      find_home: nil,
      home: fn(state, _, instruction) -> 

      end,

      install_farmware: nil,

      install_first_party_farmware: fn(state, _, instruction) ->
        case Farmbot.Farmware.Installer.add_repo(@fpf_url) do
          {:ok, _}                       -> {Farmbot.Farmware.Installer.sync_repo(@fpf_url), inc_pc(state, instruction)}
          {:error, :repo_already_exists} -> {Farmbot.Farmware.Installer.sync_repo(@fpf_url), inc_pc(state, instruction)}
          {:error, reason}               -> {{:error, reason}, inc_pc(state, instruction)}
        end
      end,

      move_absolute: nil,
      move_relative: nil,

      nothing: fn(state, _, instruction) -> {:ok, inc_pc(state, instruction)} end,

      power_off: fn(state, _, instruction) ->
        Farmbot.BotState.set_sync_status(:maintenance)
        Farmbot.BotState.force_state_push()
        Farmbot.System.shutdown("CeleryScript request")
        {:ok, inc_pc(state, instruction)}
      end,

      read_pin: nil,

      read_status: fn(state, _, instruction) ->
        Farmbot.BotState.force_state_push()
        {:ok, inc_pc(state, instruction)}
      end,

      reboot: fn(state, _, instruction) ->
        Logger.warn 1, "Going down for a reboot!"
        Farmbot.BotState.set_sync_status(:maintenance)
        Farmbot.BotState.force_state_push()
        Farmbot.System.reboot("CeleryScript request.")
        {:ok, inc_pc(state, instruction)}
      end,

      remove_farmware: fn(state, _, instruction) ->
        case Farmbot.Farmware.lookup(instruction.name) do
          {:ok, fw} -> {Farmbot.Farmware.Installer.uninstall(fw), inc_pc(state, instruction)}
          {:error, _} -> {:ok, inc_pc(state, instruction)}
        end
      end,

      rpc_request: fn(state, instruction_set, instruction) ->
        label = instruction.label
        case Runtime.execute(%{state | pc: instruction.__body}, instruction_set) do
          %State{} = new_state ->
            {Farmbot.BotState.emit(rpc_ok(label)), new_state}
          {:error, reason, %State{} = new_state} ->
            {Farmbot.BotState.emit(rpc_error(label, reason)), new_state}
        end
      end,

      send_message: nil,
      sequence: nil,
      set_user_env: nil,

      sync: fn(state, _, instruction) ->
        {Farmbot.Repo.sync(), inc_pc(state, instruction)}
      end,

      take_photo: nil,
      toggle_pin: nil,
      update_farmware: nil,

      wait: fn(state, _, instruction) ->
        {Process.sleep(instruction.milliseconds), inc_pc(state, instruction)}
      end,

      write_pin: nil,
      zero: fn(state, _, instruction) ->
        case instruction.axis do
          :all ->
            {{:error, "mapping is bork"}, inc_pc(state, instruction)}
          axis when axis in [:x, :y, :z] ->
            {Farmbot.Firmware.zero(axis), inc_pc(state, instruction)}
        end
      end
    }
  end

  # Private

  defp inc_pc(state, instruction) do
    %{state | pc: instruction.__next}
  end

  defp rpc_ok(label) do
    {:ok, ast} = AST.decode(%{kind: :rpc_ok, args: %{label: label}})
    ast
  end

  defp rpc_error(label, reason) do
    explanation = %{kind: :explanation, args: %{message: reason}}
    {:ok, ast} = AST.decode(%{kind: :rpc_error, args: %{label: label}, body: [explanation]})
    ast
  end

  @type impl :: (State, t, Instruction.t -> {:ok, State.t} | {{:error, term}, State.t})
  @type t :: %__MODULE__{
    _if: impl | nil,
    calibrate: impl | nil,
    check_updates: impl | nil,
    change_ownership: impl | nil,
    emergency_lock: impl | nil,
    emergency_unlock: impl | nil,
    execute: impl | nil,
    execute_script: impl | nil,
    factory_reset: impl | nil,
    find_home: impl | nil,
    home: impl | nil,
    install_farmware: impl | nil,
    install_first_party_farmware: impl | nil,
    move_absolute: impl | nil,
    move_relative: impl | nil,
    nothing: impl | nil,
    power_off: impl | nil,
    read_pin: impl | nil,
    read_status: impl | nil,
    reboot: impl | nil,
    remove_farmware: impl | nil,
    rpc_request: impl | nil,
    send_message: impl | nil,
    sequence: impl | nil,
    set_user_env: impl | nil,
    sync: impl | nil,
    take_photo: impl | nil,
    toggle_pin: impl | nil,
    update_farmware: impl | nil,
    wait: impl | nil,
    write_pin: impl | nil,
    zero: impl | nil
  }
end
