defmodule Libremarket.Compras do

  def comprar() do
    {:show_me_the_money}
  end

  def seleccionar_producto(id) do
    infraccion = Libremarket.Infracciones.Server.detectar_infracciones(id)
    #Libremarket.Ventas.Server.reservar_producto(id)
    seleccionar_forma_entrega(id)
  end

  def seleccionar_forma_entrega(id) do
    correo = :rand.uniform(100) <= 80
    if correo do
      costo = Libremarket.Envios.Server.calcular_costo()
      seleccionar_medio_pago(id, costo, correo)
    else
      costo = 10
      seleccionar_medio_pago(id, costo, correo)
    end
  end

  def seleccionar_medio_pago(id, costo, correo) do
    confirmar_compra(id, costo, correo)
  end

  def confirmar_compra(id, costo, correo) do
    element = Enum.find(Libremarket.Infracciones.Server.listar_infracciones(), fn {id, _value} -> id == id end)
    case element do
      {id, {:hay_infraccion}} -> informar_infraccion(id)
      {id, {:no_hay_infraccion}} ->
        pago = Libremarket.Pagos.Server.autorizarPago(id)
        case pago do
          {:pago_autorizado} ->
            if correo do
              Libremarket.Envios.Server.agendar_envio(id)
              finalizar_compra(id, costo)
            else
              finalizar_compra(id, costo)
            end
          {:pago_rechazado} -> informar_pago_rechazado(id)
        end
      _ -> :default
    end
  end

  def finalizar_compra(id, costo) do
    IO.puts("Compra finalizada con éxito")
  end

  def informar_pago_rechazado(id) do
    IO.puts("Pago rechazado")
  end

  def informar_infraccion(id) do
    IO.puts("Infracción detectada.")
  end

end

defmodule Libremarket.Compras.Server do
  @moduledoc """
  Compras
  """

  use GenServer

  # API del cliente

  @doc """
  Crea un nuevo servidor de Compras
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def comprar(pid \\ __MODULE__) do
    GenServer.call(pid, :comprar)
  end

  def seleccionar_producto(id, pid \\ __MODULE__) do
    GenServer.call(pid, {:seleccionar_producto, id})
  end

  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(state) do
    {:ok, state}
  end


  @impl true
  def handle_call({:seleccionar_producto, id}, _from, state) do
    result = Libremarket.Compras.seleccionar_producto(id)
    {:reply, result, state}
  end

  @doc """
  Callback para un call :comprar
  """
  @impl true
  def handle_call(:comprar, _from, state) do
    result = Libremarket.Compras.comprar
    {:reply, result, state}
  end

end
