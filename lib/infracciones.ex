defmodule Libremarket.Infracciones do

  def detectar_infracciones() do
    {:ok}
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
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def detectar_infracciones(pid \\ __MODULE__) do
    GenServer.call(pid, :detectar_infracciones)
  end

  # Callbacks

  @doc """
  Inicializa el estado del servidor
  """
  @impl true
  def init(state) do
    {:ok, state}
  end

  @doc """
  Callback para un call :comprar
  """
  @impl true
  def handle_call(:detectar_infracciones, _from, state) do
    result = Libremarket.Infracciones.detectar_infracciones
    {:reply, result, state}
  end

end
