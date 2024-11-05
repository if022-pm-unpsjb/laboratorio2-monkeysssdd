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
  #use GenServer
  use AMQP
  use GenServer

  @impl true
  def init(_opts) do
    spawn(fn -> start()end)
    {:ok, %{}}
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: {:global, __MODULE__})
  end

  def start do
    # Conectar al servidor RabbitMQ
    {:ok, connection} = Connection.open("amqps://bpxlyvej:BrB1fZjd60Ix5DV7IxIH8RbuGswFQ7nM@jackal.rmq.cloudamqp.com/bpxlyvej", ssl_options: [verify: :verify_none])
    {:ok, channel} = Channel.open(connection)

    # Declarar una cola
    queue_name = "test_queue"
    Queue.declare(channel, queue_name, durable: true)

    # Configurar el consumidor
    Basic.consume(channel, queue_name, nil, no_ack: true)

    # Iniciar el loop para recibir mensajes
    receive_messages(channel)
  end

  defp receive_messages(channel) do
    IO.puts("ESPERANDO MENSAJES EN INFRACCIONES")
    receive do
      {:basic_deliver, payload, _meta} ->
        {eval_payload, _bindings} = Code.eval_string(payload)

        case eval_payload do
          {:detectar_infracciones, id} ->
            # Realiza la llamada a detectar infracciones
            GenServer.call({:global, Libremarket.Infracciones.Server}, {:detectar_infracciones, id})
          _ ->
            IO.puts("Payload recibido: #{payload}")
        end
        IO.puts("Mensaje recibido EN INFRACCIONES: #{payload}")
        receive_messages(channel)
    end
  end

  @impl true
  def handle_info({:basic_consume_ok, _meta}, state) do
    IO.puts("RECIBI HANDLEINFO EN INFRACCIONES")
    # Ignorar el mensaje de confirmación de consumo
    {:noreply, state}
  end

  def send_message(message) do
    {:ok, connection} = Connection.open("amqps://bpxlyvej:BrB1fZjd60Ix5DV7IxIH8RbuGswFQ7nM@jackal.rmq.cloudamqp.com/bpxlyvej", ssl_options: [verify: :verify_none])
    {:ok, channel} = Channel.open(connection)

    # Declarar una cola y un exchange
    queue_name = "compras_queue"
    exchange_name = "test_exchange"

    Queue.declare(channel, queue_name, durable: true)
    Exchange.declare(channel, exchange_name, :direct, durable: true)

    # Enlazar la cola con el exchange
    Queue.bind(channel, queue_name, exchange_name)

    # Publicar el mensaje
    Basic.publish(channel, exchange_name, "", message)

    IO.puts("Mensaje enviado: #{message}")

    # Cerrar conexión
    Channel.close(channel)
    Connection.close(connection)
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
  Callback para un call :comprar
  """
  @impl true
  def handle_call({:detectar_infracciones, id}, _from, state) do
    result = Libremarket.Infracciones.detectar_infracciones()
    IO.puts("MANDADO")
    Libremarket.Infracciones.MessageServer.send_message(inspect(result))
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
