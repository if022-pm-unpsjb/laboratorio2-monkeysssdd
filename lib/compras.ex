defmodule Libremarket.Compras do
  def seleccionar_producto(id) do
    #infraccion = Libremarket.Infracciones.Server.detectar_infracciones(id)
    Libremarket.Compras.MessageServer.send_message("{:detectar_infracciones, #{id}}")
    infraccion = Libremarket.Compras.MessageServer.receive_message()
    reservado = Libremarket.Ventas.Server.reservar_producto(id)
    %{"producto" => %{"id" => id, "infraccion" => infraccion, "reservado" => reservado}}
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

defmodule Libremarket.Compras.MessageServer do
  use GenServer
  use AMQP

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: {:global, __MODULE__})
end

  def send_message(message) do
    {:ok, connection} = Connection.open("amqps://bpxlyvej:BrB1fZjd60Ix5DV7IxIH8RbuGswFQ7nM@jackal.rmq.cloudamqp.com/bpxlyvej", ssl_options: [verify: :verify_none])
    {:ok, channel} = Channel.open(connection)

    # Declarar la cola y el intercambio con una clave de enrutamiento específica
    queue_name = "infracciones_queue"
    exchange_name = "libremarket_exchange"

    Queue.declare(channel, queue_name, durable: true)
    Exchange.declare(channel, exchange_name, :direct, durable: true)

    # Usar una clave de enrutamiento específica para infracciones
    routing_key = "infracciones_key"
    Queue.bind(channel, queue_name, exchange_name, routing_key: routing_key)

    # Publicar el mensaje con la clave de enrutamiento
    Basic.publish(channel, exchange_name, routing_key, message)

    IO.puts("Mensaje enviado: #{message}")

    Channel.close(channel)
    Connection.close(connection)
  end


  defp receive_messages(channel) do
    receive do
      {:basic_deliver, payload, _meta} ->
        receive_messages(channel)
    end
  end

  def receive_message() do
    {:ok, connection} = Connection.open("amqps://bpxlyvej:BrB1fZjd60Ix5DV7IxIH8RbuGswFQ7nM@jackal.rmq.cloudamqp.com/bpxlyvej", ssl_options: [verify: :verify_none])
    {:ok, channel} = Channel.open(connection)

    # Declarar la cola
    queue_name = "compras_queue"
    Queue.declare(channel, queue_name, durable: true)

    # Configurar el consumidor
    Basic.consume(channel, queue_name, nil, no_ack: true)

    # Recibir el mensaje de compras_queue
    res = receive do
      {:basic_deliver, payload, _meta} ->
        IO.puts("Mensaje recibido en compras_queue: #{payload}")
        {eval_payload, _bindings} = Code.eval_string(payload)
        eval_payload  # Retornar el payload evaluado
    end

    # Cerrar canal y conexión
    Channel.close(channel)
    Connection.close(connection)

    res
  end

  @impl true
  def handle_info({:basic_consume_ok, _consumer_tag}, state) do
    # Se ignora este mensaje ya que es solo una confirmación
    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
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

  def handle_info(_, state) do
    {:noreply, state}
  end
end
