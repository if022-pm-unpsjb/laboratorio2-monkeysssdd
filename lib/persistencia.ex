defmodule Libremarket.Persistencia do
  def escribir_estado(estado, nombre_servidor) do
    File.write("data/estado_#{nombre_servidor}.txt", estado)
  end

  #esto es porque sino lee el archivo todo como string y no como un map y se rompe
  def leer_estado(nombre_servidor) do
    case File.read("data/estado_#{nombre_servidor}.txt") do
      {:ok, contenido} when contenido != "" ->
        {estado, _bindings} = Code.eval_string(contenido)
        {:ok, estado}

      {:ok, _} ->
        {:error, :empty_file}

      {:error, _} = error ->
        error
    end
  end
end
