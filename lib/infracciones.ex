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

defmodule Libremarket.Infracciones.MessageServer do
  # use GenServer
  use AMQP
  use GenServer

  @impl true
  def init(_opts) do
    {:ok, start()}
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: {:global, __MODULE__})
  end

  def start do
    # Conectar al servidor RabbitMQ
    {:ok, connection} =
      Connection.open(
        "amqps://bpxlyvej:BrB1fZjd60Ix5DV7IxIH8RbuGswFQ7nM@jackal.rmq.cloudamqp.com/bpxlyvej",
        ssl_options: [verify: :verify_none]
      )

    {:ok, channel} = Channel.open(connection)

    # Declarar una cola
    queue_name = "new_infracciones_queue"
    Queue.declare(channel, queue_name, durable: false)

    # Configurar el consumidor
    Basic.consume(channel, queue_name, nil, no_ack: true)

    channel
    # Iniciar el loop para recibir mensajes
    # receive_messages(channel)
  end

  def handle_info({:basic_deliver, payload, _meta}, state) do
    # Evalúa el payload recibido
    eval_payload = :erlang.binary_to_term(payload)

    case eval_payload do
      {:detectar_infracciones, id_compra, id_producto} ->
        # Realiza la llamada a detectar infracciones
        GenServer.call(
          {:global, Libremarket.Infracciones.Server},
          {:detectar_infracciones, id_compra, id_producto}
        )

        IO.puts("Infracciones: Detectando infracciones de #{id_compra}...")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:basic_consume_ok, _meta}, state) do
    # Ignorar el mensaje de confirmación de consumo
    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_message, server_name, message}, channel) do
    queue_name = "new_" <> server_name <> "_queue"
    exchange_name = ""
    Basic.publish(channel, exchange_name, queue_name, :erlang.term_to_binary(message))

    # IO.puts("Mensaje enviado desde infracciones: #{inspect(message)}")
    {:noreply, channel}
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
    GenServer.start_link(__MODULE__, opts, name: {:global, __MODULE__})
  end

  def detectar_infracciones(id \\ 0, pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, {:detectar_infracciones, id})
  end

  def listar_infracciones(pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, :listar_infracciones)
  end

  def inspeccionar(id \\ 0, pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, {:inspeccionar, id})
  end

  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(_opts) do
    case Libremarket.Persistencia.leer_estado("infracciones") do
      {:ok, contenido} ->
        Process.send_after(self(), :persistir_estado, 60_000)
        {:ok, contenido}

      {:error, _} ->
        # Estado por defecto si no se puede leer el estado
        estado_inicial = %{}
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
  Callback para un call :comprar
  """

  @impl true
  def handle_call({:detectar_infracciones, id_compra, id_producto}, _from, state) do
    result = Libremarket.Infracciones.detectar_infracciones()

    GenServer.cast(
      {:global, Libremarket.Infracciones.MessageServer},
      {:send_message, "compra", {:actualizar_infracciones, id_compra, result}}
    )

    # Libremarket.Infracciones.MessageServer.send_message(
    #  {:actualizar_infracciones, id_compra, result}
    # )

    {:reply, result, [{id_producto, result} | state]}
  end

  @impl true
  def handle_call({:detectar_infracciones, id}, _from, state) do
    result = Libremarket.Infracciones.detectar_infracciones()

    GenServer.cast(
      {:global, Libremarket.Infracciones.MessageServer},
      {:send_message, "compra", {:actualizar_infracciones, id, result}}
    )

    # Libremarket.Infracciones.MessageServer.send_message({:actualizar_infracciones, id, result})

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
    Libremarket.Persistencia.escribir_estado(state, "infracciones")

    Process.send_after(self(), :persistir_estado, 60_000)
    {:noreply, state}
  end
end
