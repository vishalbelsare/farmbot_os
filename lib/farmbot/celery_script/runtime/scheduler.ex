defmodule Farmbot.CeleryScript.Runtime.Scheduler do
  @moduledoc "Handles queuing of celeryscript code."
  alias Farmbot.CeleryScript.{AST, Runtime}
  use GenServer
  use Farmbot.Logger

  @checkup_time_ms 10

  @doc "Schedule some code to be ran."
  def schedule(%AST{} = ast) do
    GenServer.call(__MODULE__, {:schedule, ast})
  end

  @doc "Await a scheduled reference."
  def await(ref) when is_reference(ref) do
    GenServer.call(__MODULE__, {:await, ref}, :infinity)
  end

  @doc false
  def start_link do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  defmodule State do
    @moduledoc false
    defstruct [
      checkup_timer: nil,
      current_item: nil,
      queue: :queue.new(),
      awaiting: %{},
      refs: []
    ]
  end

  @doc false
  def init([]) do
    {:ok, struct(State), :hibernate}
  end

  def handle_call({:schedule, ast}, _, state) do
    ref = make_ref()
    new_state = %{state | queue: :queue.in({ref, ast}, state.queue), refs: [ref | state.refs]} |> maybe_start_timer()
    {:reply, ref, new_state}
  end

  def handle_call({:await, ref}, from, state) do
    if ref in state.refs do
      new_awaiting = Map.update(state.awaiting, ref, [from], fn(old_value) ->
        [from | old_value]
      end)
      # Logger.info 3, "#{inspect from} awaiting #{inspect ref}"
      {:noreply, %{state | awaiting: new_awaiting}}
    else
      {:reply, {:error, "unknown ref"}, state}
    end
  end

  def handle_info(:checkup, %State{current_item: nil} = state) do
    case :queue.out(state.queue) do
      {:empty, new_queue} ->
        {:noreply, %{state | checkup_timer: nil, queue: new_queue}}
      {{:value, {ref, %AST{} = code}}, new_queue} ->
        pid = spawn(Runtime, :run, [code])
        # Logger.info 3, "Starting #{inspect ref} #{inspect pid}"
        Process.monitor(pid)
        {:noreply, %{state | checkup_timer: nil, current_item: {ref, pid}, queue: new_queue}}
    end
  end

  def handle_info(:checkup, %State{} = state) do
    # Some code is already running. Don't checkup right now.
    Logger.info 3, "Skipping checkup. Process is already running."
    {:noreply, state}
  end

  def handle_info({:DOWN, _, :process, runtime_pid, reason}, %State{current_item: {ref, runtime_pid}} = state) do
    # Logger.info 3, "Finished with #{inspect ref} #{inspect runtime_pid}: #{inspect state.awaiting}"
    reply = case reason do
      :normal -> :ok
      other -> other
    end

    for from <- state.awaiting[ref] do
      # Logger.info 3, "Replying: #{inspect from} => #{inspect reply}"
      :ok = GenServer.reply(from, reply)
    end

    new_awaiting = Map.delete(state.awaiting, ref)
    new_state = %{state |
      current_item: nil,
      awaiting: new_awaiting,
      refs: List.delete(state.refs, ref)
    } |> maybe_start_timer()
    {:noreply, new_state}
  end

  defp maybe_start_timer(state) do
    if state.checkup_timer && Process.read_timer(state.checkup_timer) do
      state
    else
      checkup_timer = Process.send_after(self(), :checkup, @checkup_time_ms)
      %{state | checkup_timer: checkup_timer}
    end
  end
end
