defmodule FarmbotExt.MQTT.LogHandler do
  @moduledoc """
  Publishes JSON encoded bot state updates onto an MQTT channel
  """

  use GenServer

  require FarmbotCore.Logger
  require FarmbotTelemetry
  require Logger
  alias FarmbotCore.BotState
  alias FarmbotExt.MQTT.LogHandlerSupport
  alias __MODULE__, as: State

  defstruct [:client_id, :username, :state_cache]

  @checkup_ms 50

  @doc false
  def start_link(args, opts \\ [name: __MODULE__]) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def init(args) do
    state = %State{
      client_id: Keyword.fetch!(args, :client_id),
      username: Keyword.fetch!(args, :username)
    }

    {:ok, state, 0}
  end

  def handle_info(:timeout, %{state_cache: nil} = state) do
    initial_bot_state = BotState.subscribe()
    FarmbotExt.Time.no_reply(%{state | state_cache: initial_bot_state}, 0)
  end

  def handle_info(:timeout, state) do
    {:noreply, state, {:continue, FarmbotCore.Logger.handle_all_logs()}}
  end

  def handle_info({BotState, change}, state) do
    new_state_cache = Ecto.Changeset.apply_changes(change)
    {:noreply, %{state | state_cache: new_state_cache}, @checkup_ms}
  end

  def handle_info(other, state) do
    Logger.debug("UNEXPECTED MESSAGE: #{inspect(other)}")
    {:noreply, state, 0}
  end

  def handle_continue([log | rest], state) do
    case LogHandlerSupport.maybe_publish_log(log, state) do
      :ok ->
        {:noreply, state, {:continue, rest}}

      error ->
        Logger.error("Failed to upload log: #{inspect(error)}")
        # Reschedule log to be uploaded again
        FarmbotCore.Logger.insert_log!(log)
        {:noreply, state, @checkup_ms}
    end
  end

  def handle_continue([], state) do
    {:noreply, state, @checkup_ms}
  end
end
