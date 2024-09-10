defmodule Libremarket.Envios do

  def calcular_costo() do
    :rand.uniform(1000)
  end

  def agendar_envio(id) do
    {:envio_agendado, id}
  end
end

defmodule Libremarket.Envios.Server do
  @moduledoc """
  Infracciones
  """

  use GenServer

  # API del cliente

  @doc """
  Crea un nuevo servidor de Infracciones
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def calcular_costo(id \\ 0, pid \\ __MODULE__) do
    GenServer.call(pid, {:calcular_costo, id})
  end

  def listar_envios(pid \\ __MODULE__) do
    GenServer.call(pid, :listar_envios)
  end

  def agendar_envio(id, pid \\ __MODULE__) do
    GenServer.call(pid, {:agendar_envio, id})
  end
  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(state) do
    {:ok, state}
  end

  @doc """
  Callback para un call :comprar
  """
  @impl true
  def handle_call({:calcular_costo, id}, _from, state) do
    result = Libremarket.Envios.calcular_costo()
    {:reply, result, [{id, result} | state]}
  end

  @impl true
  def handle_call({:agendar_envio, id}, _from, state) do
    result = Libremarket.Envios.agendar_envio(id)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:listar_envios, _from, state) do
    {:reply, state, state}
  end
end
