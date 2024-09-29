defmodule Libremarket.Infracciones do

  def detectar_infracciones() do
    infraccion = :rand.uniform(100) <= 30

    if infraccion do
      {:hay_infraccion}
    else
      {:no_hay_infraccion}
    end

  end


end

defmodule Libremarket.Infracciones.Server do
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

  def detectar_infracciones(id \\ 0, pid \\ __MODULE__) do
    GenServer.call(pid, {:detectar_infracciones, id})
  end

  def listar_infracciones(pid \\ __MODULE__) do
    GenServer.call(pid, :listar_infracciones)
  end

  def inspeccionar(id \\ 0, pid \\ __MODULE__) do
    GenServer.call(pid, {:inspeccionar, id})
  end

  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(_opts) do
    Process.send_after(self(), :persistir_estado, 60_000)
    {:ok, %{}}
  end

  @doc """
  Callback para un call :comprar
  """
  @impl true
  def handle_call({:detectar_infracciones, id}, _from, state) do
    result = Libremarket.Infracciones.detectar_infracciones()
    {:reply, result, [{id, result} | state]}
  end

  @impl true
  def handle_call(:listar_infracciones, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:inspeccionar, id}, _from, state) do
    raise "error"
  end

  @impl true
  def handle_info(:persistir_estado, state) do
    estado_formateado = inspect(state)
    Libremarket.Persistencia.escribir_estado(estado_formateado, "infracciones")

    Process.send_after(self(), :persistir_estado, 60_000)
    {:noreply, state}
  end
end
