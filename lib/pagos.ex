defmodule Libremarket.Pagos do

  def autorizarPago(id) do
    pago = :rand.uniform(100) <= 70

    if pago do
      {:pago_autorizado}
    else
      {:pago_rechazado}
    end

  end


end

defmodule Libremarket.Pagos.Server do
  @moduledoc """
  Pagos
  """

  use GenServer

  # API del cliente

  @doc """
  Crea un nuevo servidor de Infracciones
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def autorizarPago(id \\ 0, pid \\ __MODULE__) do
    GenServer.call(pid, {:autorizarPago, id})
  end

  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(_opts) do
    estado_inicial = case Libremarket.Persistencia.leer_estado("pagos") do
      {:ok, contenido} -> contenido
      {:error, _} -> %{}
    end

    Process.send_after(self(), :persistir_estado, 60_000)

    {:ok, estado_inicial}
  end

  @doc """
  Callback para un call :comprar
  """
  @impl true
  def handle_call({:autorizarPago, id}, _from, state) do
    result = Libremarket.Pagos.autorizarPago(id)
    {:reply, result, [{id, result} | state]}
  end

  @impl true
  def handle_info(:persistir_estado, state) do
    estado_formateado = inspect(state)
    Libremarket.Persistencia.escribir_estado(estado_formateado, "pagos")

    Process.send_after(self(), :persistir_estado, 60_000)
    {:noreply, state}
  end
end
