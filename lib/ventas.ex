defmodule Libremarket.Ventas do
  def reservar_producto(producto_id) do
    reservado = :rand.uniform(100) <= 50

    if reservado do
      true
    else
      false
    end
  end

  def hubo_infraccion(producto_id) do
    infraccion =
      Enum.find(Libremarket.Infracciones.Server.listar_infracciones(), fn {id, _value} ->
        id == producto_id
      end)

    if reservar_producto(producto_id) and not infraccion do
      liberar_producto(producto_id)
    else
      pago_autorizado(producto_id)
    end
  end

  def pago_autorizado(producto_id) do
    se_autorizo_pago = Libremarket.Pagos.Server.autorizarPago(producto_id)

    if se_autorizo_pago == {:pago_autorizado} do
      enviar_producto(producto_id)
    else
      liberar_producto(producto_id)
    end
  end

  def liberar_producto(producto_id) do
    producto_liberado = :rand.uniform(100) <= 30

    if producto_liberado do
      true
    else
      false
    end
  end

  def enviar_producto(producto_id) do
    producto_id
  end
end

defmodule Libremarket.Ventas.Server do
  @moduledoc """
  Ventas
  """

  use GenServer

  # API del cliente

  @doc """
  Crea un nuevo servidor de Ventas
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: {:global, __MODULE__})
  end

  def reservar_producto(id \\ 0, pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, {:reservar_producto, id})
  end

  def pago_autorizado(pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, :pago_autorizado)
  end

  def liberar_producto(id \\ 0, pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, {:liberar_producto, id})
  end

  def enviar_producto(id \\ 0, pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, {:enviar_producto, id})
  end

  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
@impl true
def init(_opts) do
  case Libremarket.Persistencia.leer_estado("ventas") do
    {:ok, contenido} ->
      Process.send_after(self(), :persistir_estado, 60_000)
      {:ok, contenido}

    {:error, _} ->
      estado_inicial = %{}  # Estado por defecto si no se puede leer el estado
      Process.send_after(self(), :persistir_estado, 60_000)
      {:ok, estado_inicial}

    :ok ->
      # Manejo explícito si por alguna razón obtienes :ok en lugar de {:ok, contenido}
      IO.puts("Advertencia: se obtuvo :ok sin contenido en leer_estado")
      estado_inicial = %{}
      Process.send_after(self(), :persistir_estado, 60_000)
      {:ok, estado_inicial}
  end
end

  @doc """
  Callback para un call :ventas
  """
  @impl true
  def handle_call({:reservar_producto, id}, _from, state) do
    result = Libremarket.Ventas.reservar_producto(id)
    {:reply, result, [{id, result} | state]}
  end

  @impl true
  def handle_info(:persistir_estado, state) do
    Libremarket.Persistencia.escribir_estado(state, "ventas")

    Process.send_after(self(), :persistir_estado, 60_000)
    {:noreply, state}
  end
end
