defmodule Libremarket.Envios do
  def calcular_costo() do
    :rand.uniform(1000)
  end

  def agendar_envio(id) do
    {:envio_agendado, id}
  end
end

defmodule Libremarket.Envios.MessageServer do
  use GenServer
  use AMQP

  @impl true
  def init(_opts) do
    {:ok, start()}
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: {:global, __MODULE__})
  end

  def start do
    {:ok, connection} =
      Connection.open(
        "amqps://bpxlyvej:BrB1fZjd60Ix5DV7IxIH8RbuGswFQ7nM@jackal.rmq.cloudamqp.com/bpxlyvej",
        ssl_options: [verify: :verify_none]
      )

    {:ok, channel} = Channel.open(connection)

    # Declarar una cola específica para envíos
    queue_name = "new_envios_queue"
    Queue.declare(channel, queue_name, durable: false)

    # Configurar el consumidor
    Basic.consume(channel, queue_name, nil, no_ack: true)

    channel
  end

  @impl true
  def handle_info({:basic_deliver, payload, _meta}, state) do
    eval_payload = :erlang.binary_to_term(payload)

    case eval_payload do
      {:calcular_costo, id} ->
        GenServer.call(
          {:global, Libremarket.Envios.Server},
          {:calcular_costo, id}
        )

      {:agendar_envio, id} ->
        GenServer.call(
          {:global, Libremarket.Envios.Server},
          {:agendar_envio, id}
        )
    end

    IO.puts("Mensaje recibido en envíos: #{inspect(eval_payload)}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:basic_consume_ok, _consumer_tag}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_message, server_name, message}, channel) do
    queue_name = "new_" <> server_name <> "_queue"
    exchange_name = ""
    Basic.publish(channel, exchange_name, queue_name, :erlang.term_to_binary(message))

    IO.puts("Mensaje enviado desde envíos: #{inspect(message)}")
    {:noreply, channel}
  end
end

defmodule Libremarket.Envios.Server do
  use GenServer

  # API del cliente

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: {:global, __MODULE__})
  end

  def calcular_costo(id, pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, {:calcular_costo, id})
  end

  def listar_envios(pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, :listar_envios)
  end

  def agendar_envio(id, pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, {:agendar_envio, id})
  end

  # Callbacks
  @impl true
  def init(_opts) do
    case Libremarket.Persistencia.leer_estado("envios") do
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

  @impl true
  def handle_call({:calcular_costo, id}, _from, state) do
    result = Libremarket.Envios.calcular_costo()

    # Enviar mensaje al servidor de compras
    GenServer.cast(
      {:global, Libremarket.Envios.MessageServer},
      {:send_message, "compras", {:actualizar_costo, id, result}}
    )

    nuevo_estado =
      Map.update(state, id, %{costo: result, agendado: false}, fn envio ->
        Map.put(envio, :costo, result)
      end)

    {:reply, result, nuevo_estado}
  end

  @impl true
  def handle_call({:agendar_envio, id}, _from, state) do
    result = Libremarket.Envios.agendar_envio(id)

    # Enviar mensaje al servidor de compras
    GenServer.cast(
      {:global, Libremarket.Envios.MessageServer},
      {:send_message, "compras", {:actualizar_envio, id, result}}
    )

    nuevo_estado =
      Map.update(state, id, %{costo: 0, agendado: true}, fn envio ->
        Map.put(envio, :agendado, true)
      end)

    {:reply, result, nuevo_estado}
  end

  @impl true
  def handle_call(:listar_envios, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:persistir_estado, state) do
    Libremarket.Persistencia.escribir_estado(state, "envios")

    Process.send_after(self(), :persistir_estado, 60_000)
    {:noreply, state}
  end
end
