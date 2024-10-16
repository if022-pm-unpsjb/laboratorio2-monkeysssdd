defmodule Libremarket.Persistencia do
  @dets_file "../data/estado_compras.dets"
  @dets_file "../data/estado_envios.dets"
  @dets_file "../data/estado_infracciones.dets"
  @dets_file "../data/estado_pagos.dets"
  @dets_file "../data/estado_ventas.dets"


  defp ensure_data_dir do
    unless File.exists?("data") do
      File.mkdir("data")
    end
  end

  def abrir_dets(nombre_servidor) do
    ensure_data_dir()
    :dets.open_file(String.to_atom("./data/"<>nombre_servidor<>".dets"), [type: :set])
  end

  def cerrar_dets(dets_ref) do
    :dets.close(dets_ref)
  end

  def escribir_estado(estado, nombre_servidor) do
    # IO.puts("hola")
    # IO.puts(abrir_dets(nombre_servidor))
    case abrir_dets(nombre_servidor) do
      {:ok, dets_ref} ->
        :dets.insert(dets_ref, {nombre_servidor, estado})
        cerrar_dets(dets_ref)

      {:error, reason} ->
        IO.puts("Error al abrir archivo DETS: #{inspect(reason)}")
    end
  end

  def leer_estado(nombre_servidor) do
    case abrir_dets(nombre_servidor) do
      {:ok, dets_ref} ->
        case :dets.lookup(dets_ref, nombre_servidor) do
          [{_nombre, estado}] -> state = {:ok, estado}
          [] -> state = {:error, :no_data}
          cerrar_dets(dets_ref)
          state
        end


      {:error, reason} ->
        IO.puts("Error al abrir archivo DETS: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
