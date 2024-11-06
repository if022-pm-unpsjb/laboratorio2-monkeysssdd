defmodule Libremarket.Supervisor do
  use Supervisor

  @doc """
  Inicia el supervisor
  """
  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    topologies = [
      gossip: [
        strategy: Cluster.Strategy.Gossip,
        config: [
          port: 45892,
          if_addr: "0.0.0.0",
          multicast_addr: "127.0.0.255",
          broadcast_only: true,
          secret: "monkeys"
        ]
      ]
    ]

    children = [
      Libremarket.Compras.Server,
      Libremarket.Infracciones.Server,
      Libremarket.Envios.Server,
      Libremarket.Pagos.Server,
      Libremarket.Ventas.Server,
      Libremarket.Infracciones.MessageServer,
      Libremarket.Compras.MessageServer,
      {Cluster.Supervisor, [topologies, [name: MyApp.ClusterSupervisor]]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
