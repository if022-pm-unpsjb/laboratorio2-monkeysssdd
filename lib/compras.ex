defmodule Libremarket.Compras do

  def comprar() do
    {:show_me_the_money}
  end

  def seleccionar_producto(id) do
    infraccion = Libremarket.Infracciones.Server.detectar_infracciones(id)
    reservado = true
    #reservado = Libremarket.Ventas.Server.reservar_producto(id)
    %{"producto" => %{"id" => id, "infraccion" => elem(infraccion, 0), "reservado" => reservado}}
  end

  def seleccionar_forma_entrega() do
    forma = :rand.uniform(100) <= 80
    if forma do
      forma = :correo
      costo = Libremarket.Envios.Server.calcular_costo()
      %{"forma_entrega" => forma, "costo_envio" => costo}
      #seleccionar_medio_pago(id, costo, correo)
    else
      forma = :retira
      costo = 0 # ?
      #seleccionar_medio_pago(id, costo, correo)
      %{"forma_entrega" => forma, "costo_envio" => costo}
    end
  end

  def seleccionar_medio_pago() do
    if :rand.uniform(100) <= 80 do
      %{"medio_de_pago" => :transferencia}
    else
      %{"medio_de_pago" => :efectivo}
    end

  end

  def confirmar_compra(id, state) do
    hay_infraccion = Map.get(Map.get(state, "producto"), "infraccion") == :hay_infraccion

    if hay_infraccion do
      informar_infraccion(id)
      %{"estado" => :hay_infraccion}
    else
      pago_autorizado = elem(Libremarket.Pagos.Server.autorizarPago(id), 0)
      if pago_autorizado == :pago_rechazado do
        informar_pago_rechazado(id)
        %{"estado" => :pago_rechazado}
      else
        correo = Map.get(state, "forma_entrega") == :correo

        if correo do
          Libremarket.Envios.Server.agendar_envio(id)
        end

        informar_confirmar_compra(id)
        %{"estado" => :confirmada}
      end
    end
  end

  def informar_confirmar_compra(id) do
    IO.puts("Compra confirmada con éxito")
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
  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def comprar(pid \\ __MODULE__) do
    GenServer.call(pid, :comprar)
  end

  def generar_compra(id, pid \\ __MODULE__) do
    GenServer.call(pid, {:generar_compra, id})
  end

  def seleccionar_producto(id_compra, id_producto, pid \\ __MODULE__) do
    GenServer.call(pid, {:seleccionar_producto, id_compra, id_producto})
  end

  def seleccionar_forma_entrega(id_compra, pid \\ __MODULE__) do
    GenServer.call(pid, {:seleccionar_forma_entrega, id_compra})
  end

  def seleccionar_medio_pago(id_compra, pid \\ __MODULE__) do
    GenServer.call(pid, {:seleccionar_medio_pago, id_compra})
  end

  def confirmar_compra(id_compra, pid \\ __MODULE__) do
    GenServer.call(pid, {:confirmar_compra, id_compra})
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
  def handle_call({:generar_compra, id}, _from, state) do
    new_state = Map.put(state, id, %{})
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:seleccionar_producto, id_compra, id_producto}, _from, state) do
    result = Libremarket.Compras.seleccionar_producto(id_producto)
    actual_item_state = Map.get(state, id_compra)
    new_item_state = Map.merge(actual_item_state, result)
    new_state = Map.put(state, id_compra, new_item_state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:seleccionar_forma_entrega, id}, _from, state) do
    result = Libremarket.Compras.seleccionar_forma_entrega()
    actual_item_state = Map.get(state, id)
    new_item_state = Map.merge(actual_item_state, result)
    new_state = Map.put(state, id, new_item_state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:seleccionar_medio_pago, id_compra}, _from, state) do
    result = Libremarket.Compras.seleccionar_medio_pago()
    actual_item_state = Map.get(state, id_compra)
    new_item_state = Map.merge(actual_item_state, result)
    new_state = Map.put(state, id_compra, new_item_state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:confirmar_compra, id_compra}, _from, state) do
    actual_item_state = Map.get(state, id_compra)
    result = Libremarket.Compras.confirmar_compra(id_compra, actual_item_state)
    new_item_state = Map.merge(actual_item_state, result)
    new_state = Map.put(state, id_compra, new_item_state)

    {:reply, new_state, new_state}
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
