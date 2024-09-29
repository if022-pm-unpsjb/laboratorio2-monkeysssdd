defmodule Libremarket.Envios do
  def calcular_costo() do
    :rand.uniform(1000)
  end

  def agendar_envio(id) do
    {:envio_agendado, id}
  end
end

defmodule Libremarket.Envios.Server do
  use GenServer

  # API del cliente

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def calcular_costo(id, pid \\ __MODULE__) do
    GenServer.call(pid, {:calcular_costo, id})
  end

  def listar_envios(pid \\ __MODULE__) do
    GenServer.call(pid, :listar_envios)
  end

  def agendar_envio(id, pid \\ __MODULE__) do
    GenServer.call(pid, {:agendar_envio, id})
  end

  # Callbacks
  # @impl true
  # def init(_opts) do
  #   Process.send_after(self(), :persistir_estado, 60_000)
  #   {:ok, %{}}
  # end

  @impl true
  def init(_opts) do
    estado_inicial = case Libremarket.Persistencia.leer_estado("envios") do
      {:ok, contenido} -> contenido
      {:error, _} -> %{}
    end

    Process.send_after(self(), :persistir_estado, 60_000)

    {:ok, estado_inicial}
  end

  @impl true
  def handle_call({:calcular_costo, id}, _from, state) do
    result = Libremarket.Envios.calcular_costo()
    nuevo_estado = Map.update(state, id, %{costo: result, agendado: false}, fn envio ->
      Map.put(envio, :costo, result)
    end)
    {:reply, result, nuevo_estado}
  end

  @impl true
  def handle_call({:agendar_envio, id}, _from, state) do
    nuevo_estado = Map.update(state, id, %{costo: 0, agendado: true}, fn envio ->
      Map.put(envio, :agendado, true)
    end)
    {:reply, {:envio_agendado, id}, nuevo_estado}
  end

  @impl true
  def handle_call(:listar_envios, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:persistir_estado, state) do
    estado_formateado = inspect(state)
    Libremarket.Persistencia.escribir_estado(estado_formateado, "envios")

    Process.send_after(self(), :persistir_estado, 60_000)
    {:noreply, state}
  end
end
