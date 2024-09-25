defmodule Libremarket.Persistencia do
  def escribir_estado(estado, modulo) do
    File.write("estado_#{modulo}.txt", estado)
  end

  def leer_estado(modulo) do
    case File.read("estado_#{modulo}.txt") do
      {:ok, contenido} ->
        {:ok, contenido}
      {:error, _} = error ->
        error
    end
  end
end
