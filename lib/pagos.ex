defmodule Libremarket.Pagos do
  def autorizarPago(id) do
    pago = :rand.uniform(100) <= 70

    if pago do
      :pago_autorizado
    else
      :pago_rechazado
    end
  end
end

defmodule Libremarket.Pagos.MessageServer do
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
    queue_name = "new_pagos_queue"
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
      {:autorizar_pago, id} ->
        # Realiza la llamada a autorizar pago
        GenServer.call(
          {:global, Libremarket.Pagos.Server},
          {:autorizar_pago, id}
        )

        IO.puts("Autorizando pago de #{id}...")
    end

    # IO.puts("Mensaje recibido en pagos: #{inspect(:erlang.binary_to_term(payload))}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:basic_consume_ok, _meta}, state) do
    # IO.puts("RECIBIDO EN PAGOS BASIC_CONSUME")
    # Ignorar el mensaje de confirmación de consumo
    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_message, server_name, message}, channel) do
    queue_name = "new_" <> server_name <> "_queue"
    exchange_name = ""
    Basic.publish(channel, exchange_name, queue_name, :erlang.term_to_binary(message))

    # IO.puts("Mensaje enviado desde pagos: #{inspect(message)}")
    {:noreply, channel}
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
    GenServer.start_link(__MODULE__, opts, name: {:global, __MODULE__})
  end

  def autorizarPago(id \\ 0, pid \\ __MODULE__) do
    GenServer.call({:global, __MODULE__}, {:autorizar_pago, id})
  end

  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """

  @impl true
  def init(_opts) do
    case Libremarket.Persistencia.leer_estado("pagos") do
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
  def handle_call({:autorizar_pago, id}, _from, state) do
    # Lógica de autorización del pago
    result = Libremarket.Pagos.autorizarPago(id)

    # Enviar el mensaje al MessageServer
    GenServer.cast(
      {:global, Libremarket.Pagos.MessageServer},
      {:send_message, "compra", {:actualizar_pago, id, result}}
    )

    # Devolver la respuesta y actualizar el estado
    {:reply, result, [{id, result} | state]}
  end

  @impl true
  def handle_info(:persistir_estado, state) do
    Libremarket.Persistencia.escribir_estado(state, "pagos")

    Process.send_after(self(), :persistir_estado, 60_000)
    {:noreply, state}
  end
end
