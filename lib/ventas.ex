defmodule Libremarket.Ventas do
  def reservar_producto(id_compra, id_producto) do
    GenServer.cast(
      {:global, Libremarket.Compras.MessageServer},
      {:send_message, "infracciones", {:detectar_infracciones, id_compra, id_producto}}
    )

    true
  end

  def hubo_infraccion(producto_id, infraccion) do
    # hay_infraccion = Map.get(Map.get(state_item_actual, "producto"), "infraccion") == :hay_infraccion

    IO.puts("Ventas: revisando infraccion #{inspect(producto_id)}")

    case elem(infraccion, 0) do
      :hay_infraccion ->
        liberar_producto(producto_id)
      _ ->
        GenServer.cast(
          {:global, Libremarket.Ventas.MessageServer},
          {:send_message, "pagos", {:pago_autorizado, producto_id}}
        )
    end
  end

  def pago_autorizado(producto_id, se_autorizo_pago) do
    # IO.puts("VENTAS: pago_autorizado --> #{inspect(producto_id)}")

    result =
      case se_autorizo_pago do
        :pago_autorizado ->
          enviar_producto(producto_id)

        _ ->
            liberar_producto(producto_id)
      end
  end

  def liberar_producto(producto_id) do
    producto_liberado = :rand.uniform(100) <= 30

    if producto_liberado do
      IO.puts("Producto liberado #{inspect(producto_id)}")
      true
    else
      IO.puts("Producto no liberado #{inspect(producto_id)}")
      false
    end
  end

  def enviar_producto(producto_id) do
    IO.puts("Ventas: Producto enviado #{inspect(producto_id)}")
    producto_id
  end
end

defmodule Libremarket.Ventas.MessageServer do
  use GenServer
  use AMQP

  @impl true
  def init(_opts) do
    # Conectar al servidor RabbitMQ
    {:ok, connection} =
      Connection.open(
        "amqps://bpxlyvej:BrB1fZjd60Ix5DV7IxIH8RbuGswFQ7nM@jackal.rmq.cloudamqp.com/bpxlyvej",
        ssl_options: [verify: :verify_none]
      )

    {:ok, channel} = Channel.open(connection)

    # Declarar una cola
    queue_name = "new_ventas_queue"
    Queue.declare(channel, queue_name, durable: true)

    # Configurar el consumidor
    Basic.consume(channel, queue_name, nil, no_ack: true)
    {:ok, channel}
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: {:global, __MODULE__})
  end

  @impl true
  def handle_cast({:send_message, server_name, message}, channel) do
    queue_name = "new_" <> server_name <> "_queue"
    exchange_name = ""
    Basic.publish(channel, exchange_name, queue_name, :erlang.term_to_binary(message))

    IO.puts("Mensaje enviado desde ventas: #{inspect(message)}")
    # IO.puts(queue_name)
    {:noreply, channel}
  end

  def handle_info({:basic_deliver, payload, _meta}, state) do
    # Evalúa el payload recibido
    eval_payload = :erlang.binary_to_term(payload)

    case eval_payload do
      {:reservar_producto, id_compra, id_producto } ->
        GenServer.call(
          {:global, Libremarket.Ventas.Server},
          {:reservar_producto, id_compra, id_producto}
        )

        IO.puts("Ventas: Reservando producto #{id_producto}...")

      {:liberar_producto, id_compra, result} ->
        GenServer.call(
          {:global, Libremarket.Ventas.Server},
          {:liberar_producto, id_compra, result}
        )

        IO.puts("Ventas: Liberando producto #{inspect(id_compra)}: #{inspect(result)}")

      {:pago_autorizado, id_compra, result} ->
        GenServer.call(
          {:global, Libremarket.Ventas.Server},
          {:pago_autorizado, id_compra, result}
        )

        IO.puts("Ventas: pago autorizado #{inspect(id_compra)}: #{inspect(result)}")

      {:hubo_infraccion, id_compra, result} ->
        GenServer.call(
          {:global, Libremarket.Ventas.Server},
          {:hubo_infraccion, id_compra, result}
        )

        IO.puts("Ventas: esperando infracciones #{inspect(id_compra)}: #{inspect(result)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:basic_consume_ok, _consumer_tag}, state) do
    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
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

  def reservar_producto(id_compra, id_producto \\ 0, pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, {:reservar_producto, id_compra, id_producto})
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
  def handle_call({:reservar_producto, id_compra, id_producto}, _from, state) do
    result = Libremarket.Ventas.reservar_producto(id_compra, id_producto)
    {:reply, result, [{id_producto, result} | state]}
  end

  @impl true
  def handle_call({:pago_autorizado, id_compra, pago_autorizado}, _from, state) do
    result = Libremarket.Ventas.pago_autorizado(id_compra, pago_autorizado)
    {:reply, result, [{id_compra, result} | state]}
  end

  @impl true
  def handle_call({:hubo_infraccion, id_compra, infraccion}, _from, state) do
    result = Libremarket.Ventas.hubo_infraccion(id_compra, infraccion)
    {:reply, result, state}
  end

  @impl true
  def handle_cast({:hubo_infraccion, id_compra}, state) do

  end

  @impl true
  def handle_info(:persistir_estado, state) do
    Libremarket.Persistencia.escribir_estado(state, "ventas")

    Process.send_after(self(), :persistir_estado, 60_000)
    {:noreply, state}
  end
end
