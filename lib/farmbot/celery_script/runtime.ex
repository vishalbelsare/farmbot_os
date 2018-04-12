defmodule Farmbot.CeleryScript.Runtime do
  @moduledoc "CeleryScript Virtual Machine runtime."
  alias Farmbot.CeleryScript.{Address, AST, Heap, Runtime}
  alias Runtime.{State, Instruction, Utils}
  import Utils

  defmodule SymbolEntry do
    @moduledoc "Data stored on a StackFrame."
    defstruct [
      :type,
      :value,
      :label,
    ]
  end

  defmodule StackFrame do
    @moduledoc "Individual frame on the Stack."
    defstruct [
      locals: %{}
    ]
  end

  defimpl Inspect, for: State do
    def inspect(%State{} = state, _) do
      "<[#{inspect state.ref}] CeleryMachine PC: #{inspect state.pc} SP: #{inspect state.sp}>"
    end
  end

  @doc "Execute an AST until complete."
  def run(%AST{} = ast) do
    initial_state = init(ast)
    do_run(initial_state)
  end

  defp do_run(state) do
    case execute(state) do
      %State{pc: %Address{value: 0}} = final_state ->
        vm_debug(final_state, "Program Counter: 0")
        final_state
      %State{} = next_state  ->
        vm_debug(next_state, "going to tick again.")
        do_run(next_state)
      {:error, reason, state} when is_binary(reason) -> {:error, reason, state}
    end
  end

  @doc "Initialize the Machine's state."
  def init(ast) do
    heap = Farmbot.CeleryScript.AST.Slicer.run(ast)
    struct(State, [heap: heap, ref: make_ref()])
    |> vm_debug("init")
  end

  @doc "One single tick."
  def execute(%State{} = state) do
    pc = state.pc
    vm_debug(state, "tick: #{inspect pc}")
    instruction = state.heap[pc] || raise "Stack Overflow"
    Instruction.apply(state, instruction)
  end
end
