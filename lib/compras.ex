defmodule Libremarket.Compras do
  def seleccionar_producto(id) do
    infraccion = Libremarket.Infracciones.Server.detectar_infracciones(id)
    reservado = Libremarket.Ventas.Server.reservar_producto(id)
    %{"producto" => %{"id" => id, "infraccion" => elem(infraccion, 0), "reservado" => reservado}}
  end

  def seleccionar_forma_entrega(id_compra) do
    forma = :rand.uniform(100) <= 80

    if forma do
      forma = :correo
      costo = Libremarket.Envios.Server.calcular_costo(id_compra)
      %{"forma_entrega" => forma, "costo_envio" => costo}
      # seleccionar_medio_pago(id, costo, correo)
    else
      forma = :retira
      # ?
      costo = 0
      # seleccionar_medio_pago(id, costo, correo)
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
    IO.puts("Compra " <> Integer.to_string(id) <> " confirmada con éxito")
  end

  def finalizar_compra(id, costo) do
    IO.puts(
      "Compra id " <>
        Integer.to_string(id) <> "costo " <> Integer.to_string(costo) <> " finalizada con éxito"
    )
  end

  def informar_pago_rechazado(id) do
    IO.puts("Pago rechazado para la compra " <> Integer.to_string(id))
  end

  def informar_infraccion(id) do
    IO.puts("Infracción detectada para la compra " <> Integer.to_string(id))
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
    GenServer.start_link(__MODULE__, %{}, name: {:global, __MODULE__})
  end

  def generar_compra(id, pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, {:generar_compra, id})
  end

  @spec seleccionar_producto(any(), any()) :: any()
  def seleccionar_producto(id_compra, id_producto, pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, {:seleccionar_producto, id_compra, id_producto})
  end

  def seleccionar_forma_entrega(id_compra, pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, {:seleccionar_forma_entrega, id_compra})
  end

  def seleccionar_medio_pago(id_compra, pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, {:seleccionar_medio_pago, id_compra})
  end

  def confirmar_compra(id_compra, pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, {:confirmar_compra, id_compra})
  end

  def listar_compras(pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, :listar_compras)
  end

  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(_opts) do
    case Libremarket.Persistencia.leer_estado("compras") do
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
    result = Libremarket.Compras.seleccionar_forma_entrega(id)
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

  @impl true
  def handle_call(:listar_compras, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:persistir_estado, state) do
    Libremarket.Persistencia.escribir_estado(state, "compras")

    Process.send_after(self(), :persistir_estado, 60_000)
    {:noreply, state}
  end
end
