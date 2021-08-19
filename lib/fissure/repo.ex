defmodule Fissure.Repo do
  defmodule State do
    defstruct [
      base_path: nil,
      schemas: %{}
    ]
  end

  @moduledoc """
  Keeps track of all the schema information
  """
  use GenServer

  import Fissure.Sanitizer

  @typedoc """
  Where a database's data will be all stored.
  """
  @type base_path_option :: {:base_path, Path.t()}

  @type start_option :: base_path_option()

  @type start_options :: [start_option()]

  @timeout 15_000

  def insert(repo, schema_name, row, timeout \\ @timeout) do
    GenServer.call(repo, {:insert, schema_name, row}, timeout)
  end

  def update(repo, schema_name, row, timeout \\ @timeout) do
    GenServer.call(repo, {:update, schema_name, row}, timeout)
  end

  def delete(repo, schema_name, id, timeout \\ @timeout) do
    GenServer.call(repo, {:delete, schema_name, id}, timeout)
  end

  def get(repo, schema_name, id, timeout \\ @timeout) do
    GenServer.call(repo, {:get, schema_name, id}, timeout)
  end

  def get_schema(repo, schema_name, timeout \\ @timeout) do
    GenServer.call(repo, {:get_schema, schema_name}, timeout)
  end

  def get_schemas(repo, timeout \\ @timeout) do
    GenServer.call(repo, :get_schemas, timeout)
  end

  def get_data_path(repo, timeout \\ @timeout) do
    GenServer.call(repo, :get_data_path, timeout)
  end

  def get_schemas_path(repo, timeout \\ @timeout) do
    GenServer.call(repo, :get_schemas_path, timeout)
  end

  defdelegate stop(server, reason \\ :normal, timeout \\ @timeout), to: GenServer

  @spec start_link(start_options(), Keyword.t()) :: GenServer.on_start()
  def start_link(options, process_options \\ []) do
    GenServer.start_link(__MODULE__, options, process_options)
  end

  @impl true
  def init(options) do
    state = %State{
      base_path: Keyword.fetch!(options, :base_path),
    }

    {:ok, state, {:continue, :load_schemas}}
  end

  @impl true
  def handle_continue(:load_schemas, %State{} = state) do
    state = do_load_schemas(state)
    {:noreply, state}
  end

  @impl true
  def handle_call({:insert, schema_name, row}, _from, %State{} = state) do
    schema_name = sanitize_path_component(schema_name)
    case Map.fetch(state.schemas, schema_name) do
      {:ok, %Fissure.Schema{} = schema} ->
        path = make_data_path([schema.name, "items"], state)
        {:reply, Fissure.Schema.create_item_file_with_schema(path, row, schema), state}

      :error ->
        {:reply, {:error, {:schema_not_found, schema_name}}, state}
    end
  end

  @impl true
  def handle_call({:get, schema_name, id}, _from, %State{} = state) do
    schema_name = sanitize_path_component(schema_name)
    case Map.fetch(state.schemas, schema_name) do
      {:ok, %Fissure.Schema{} = schema} ->
        path = make_data_path([schema.name, "items"], state)
        {:reply, Fissure.Schema.load_item_from_file_with_schema(path, id, schema), state}

      :error ->
        {:reply, {:error, {:schema_not_found, schema_name}}, state}
    end
  end

  @impl true
  def handle_call({:get_schema, schema_name}, _from, %State{} = state) do
    schema_name = sanitize_path_component(schema_name)
    case Map.fetch(state.schemas, schema_name) do
      {:ok, %Fissure.Schema{} = schema} ->
        {:reply, {:ok, schema}, state}

      :error ->
        {:reply, {:error, {:schema_not_found, schema_name}}, state}
    end
  end

  @impl true
  def handle_call(:get_schemas, _from, %State{} = state) do
    {:reply, state.schemas, state}
  end

  @impl true
  def handle_call(:get_schemas_path, _from, %State{} = state) do
    {:reply, make_schemas_path([], state), state}
  end

  @impl true
  def handle_call(:get_data_path, _from, %State{} = state) do
    {:reply, make_data_path([], state), state}
  end

  defp do_load_schemas(%State{} = state) do
    wildcard_path = make_schemas_path(["*.schema"], state)
    IO.inspect wildcard_path
    schema_filenames = Path.wildcard(wildcard_path)

    schemas =
      Enum.reduce(schema_filenames, %{}, fn filename, schemas ->
        {:ok, schema} = Fissure.Schema.load_schema_from_file(filename)
        Map.put(schemas, sanitize_path_component(schema.name), schema)
      end)

    %{state | schemas: schemas}
  end

  defp make_schemas_path(path, %State{} = state) when is_list(path) do
    Path.join([state.base_path, "schemas" | path])
  end

  defp make_data_path(path, %State{} = state) when is_list(path) do
    Path.join([state.base_path, "data" | path])
  end
end
