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
    children = [
      # Libremarket.Compras.Server,
      # Libremarket.Infracciones.Server,
      # Libremarket.Envios.Server
      Libremarket.Pagos.Server,
      Libremarket.Ventas.Server
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
