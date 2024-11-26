defmodule Libremarket.Compras do
  def seleccionar_producto(id_compra, id) do
    # infraccion = Libremarket.Infracciones.Server.detectar_infracciones(id)
    # Libremarket.Compras.MessageServer.send_message({:detectar_infracciones, id_compra, id})

    GenServer.cast(
      {:global, Libremarket.Compras.MessageServer},
      {:send_message, "infracciones", {:detectar_infracciones, id_compra, id}}
    )

    # infraccion = Libremarket.Compras.MessageServer.receive_message()
    GenServer.cast(
      {:global, Libremarket.Compras.MessageServer},
      {:send_message, "ventas", {:reservar_producto, id_compra, id}}
    )

    # reservado = Libremarket.Ventas.Server.reservar_producto(id)
    %{"producto" => %{"id" => id, "infraccion" => nil}}
  end

  def seleccionar_forma_entrega(id_compra) do
    forma = :rand.uniform(100) <= 80

    if forma do
      forma = :correo

      GenServer.cast(
        {:global, Libremarket.Compras.MessageServer},
        {:send_message, "envios", {:calcular_costo, id_compra}}
      )

      # costo = Libremarket.Envios.Server.calcular_costo(id_compra)
      %{"forma_entrega" => forma, "costo_envio" => nil}
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

  def confirmar_compra3(id, state) do
    if Map.get(Map.get(state, "producto"), "infraccion") == nil do
      :waiting
    else
      hay_infraccion = Map.get(Map.get(state, "producto"), "infraccion") == :hay_infraccion

      if hay_infraccion do
        informar_infraccion(id)
        %{"estado" => :error}
      else
        # pago_autorizado = elem(Libremarket.Pagos.Server.autorizarPago(id), 0)
        GenServer.cast(
          {:global, Libremarket.Compras.MessageServer},
          {:send_message, "pagos", {:autorizar_pago, id}}
        )

        %{}
      end
    end
  end

  def confirmar_compra(id, state) do
    hay_infraccion = Map.get(Map.get(state, "producto"), "infraccion") == :hay_infraccion

    IO.puts(inspect(Map.get(Map.get(state, "producto"), "infraccion")))

    if hay_infraccion do
      informar_infraccion(id)
      %{"estado" => :error}
    else
      # pago_autorizado = elem(Libremarket.Pagos.Server.autorizarPago(id), 0)
      GenServer.cast(
        {:global, Libremarket.Compras.MessageServer},
        {:send_message, "pagos", {:autorizar_pago, id}}
      )

      %{}
    end
  end

  def confirmar_compra2(id, state) do
    hay_infraccion = Map.get(Map.get(state, "producto"), "new_infracciones") == :error

    if hay_infraccion do
      informar_infraccion(id)
      %{"estado" => :error}
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
    queue_name = "new_compras_queue"
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

    # IO.puts("Mensaje enviado desde compras: #{inspect(message)}")
    # IO.puts(queue_name)
    {:noreply, channel}
  end

  def handle_info({:basic_deliver, payload, _meta}, state) do
    eval_payload = :erlang.binary_to_term(payload)

    case eval_payload do
      {:actualizar_infracciones, id_compra, infraccion} ->
        # Realiza la llamada a detectar infracciones
        GenServer.call(
          {:global, Libremarket.Compras.Server},
          {:actualizar_infracciones, id_compra, infraccion}
        )

        IO.puts("Actualizando infracción #{inspect(id_compra)}: #{inspect(infraccion)}")

      {:actualizar_costo, id_compra, result} ->
        GenServer.call(
          {:global, Libremarket.Compras.Server},
          {:actualizar_costo, id_compra, result}
        )

        IO.puts("Actualizando costo #{inspect(id_compra)}: #{inspect(result)}")

      {:actualizar_pago, id_compra, result} ->
        GenServer.call(
          {:global, Libremarket.Compras.Server},
          {:actualizar_pago, id_compra, result}
        )

        IO.puts("Actualizando pago #{inspect(id_compra)}: #{inspect(result)}")
    end

    # IO.puts("RECIBIDO EN COMPRAS #{inspect(eval_payload)}")
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

  def confirmar_compra3(id_compra, pid \\ __MODULE__) do
    GenServer.cast({:global, __MODULE__}, {:confirmar_compra3, id_compra})
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
  def handle_call({:actualizar_costo, id_compra, result}, _from, state) do
    compra_state = Map.get(state, id_compra)
    new_compra_state = Map.merge(compra_state, %{"costo_envio" => result})
    new_state = Map.put(state, id_compra, new_compra_state)
    {:reply, state, new_state}
  end

  @impl true
  def handle_call({:actualizar_pago, id_compra, pago_autorizado}, _from, state) do
    result =
      case pago_autorizado do
        :pago_rechazado ->
          :error

        _ ->
          case Map.get(state, "estado") do
            :error ->
              :error

            _ ->
              :confirmada
          end
      end

    if pago_autorizado == :pago_rechazado do
      Libremarket.Compras.informar_pago_rechazado(id_compra)
      # result = :pago_rechazado
    else
      correo = Map.get(state, "forma_entrega") == :correo

      if correo do
        # Libremarket.Envios.Server.agendar_envio(id)
        GenServer.cast(
          {:global, Libremarket.Compras.MessageServer},
          {:send_message, "envios", {:agendar_envio, id_compra}}
        )
      end

      Libremarket.Compras.informar_confirmar_compra(id_compra)
      # result = :confirmada
    end

    compra_state = Map.get(state, id_compra)
    new_compra_state = Map.merge(compra_state, %{"estado" => result})
    newer_compra_state = Map.put(new_compra_state, "estado_pago", pago_autorizado)
    new_state = Map.put(state, id_compra, newer_compra_state)
    {:reply, state, new_state}
  end

  @impl true
  def handle_call({:actualizar_infracciones, id_compra, infraccion}, _from, state) do
    actual_compra_state =
      case elem(infraccion, 0) do
        :hay_infraccion ->
          :error

        _ ->
          :en_proceso
      end

    compra_state = Map.get(state, id_compra)
    producto_state = Map.get(compra_state, "producto")
    new_producto_state = Map.merge(producto_state, %{"infraccion" => elem(infraccion, 0)})
    n_compra_state = Map.put(compra_state, "estado", actual_compra_state)
    new_compra_state = Map.put(n_compra_state, "producto", new_producto_state)
    new_state = Map.put(state, id_compra, new_compra_state)
    {:reply, state, new_state}
  end

  @impl true
  def handle_call({:generar_compra, id}, _from, state) do
    new_state = Map.put(state, id, %{"estado" => :en_proceso})
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:seleccionar_producto, id_compra, id_producto}, _from, state) do
    result = Libremarket.Compras.seleccionar_producto(id_compra, id_producto)
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
  def handle_cast({:confirmar_compra3, id_compra}, state) do
    actual_item_state = Map.get(state, id_compra)
    result = Libremarket.Compras.confirmar_compra3(id_compra, actual_item_state)

    if result == :waiting do
      Process.sleep(200)
      #IO.puts("Esperando")
      GenServer.cast({:global, __MODULE__}, {:confirmar_compra3, id_compra})

      {:noreply, state}
    else
      new_item_state = Map.merge(actual_item_state, result)
      new_state = Map.put(state, id_compra, new_item_state)

      {:noreply, new_state}
    end
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
