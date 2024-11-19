defmodule Libremarket.Test do
  def comprar(id_compra, id_producto) do
    Libremarket.Compras.Server.generar_compra(id_compra)
    Process.sleep(:rand.uniform(3000) + 2000)
    Libremarket.Compras.Server.seleccionar_producto(id_compra, id_producto)
    Process.sleep(:rand.uniform(3000) + 2000)
    Libremarket.Compras.Server.seleccionar_forma_entrega(id_compra)
    Process.sleep(:rand.uniform(3000) + 2000)
    Libremarket.Compras.Server.seleccionar_medio_pago(id_compra)
    Process.sleep(:rand.uniform(3000) + 2000)
    Libremarket.Compras.Server.confirmar_compra(id_compra)
  end

  def simular_compras(cantidad) do
    simular_compras(0, cantidad)
  end

  # def simular_compras(id_compra, cantidad) do
  #   if cantidad > 0 do
  #     id_producto = :rand.uniform(1000)
  #     comprar(id_compra, id_producto)

  #     id_compra = id_compra + 1
  #     simular_compras(id_compra, cantidad - 1)
  #   end
  # end
  def simular_compras(id_compra, cantidad) do
    for id_compra <- 1..cantidad do
      spawn(fn ->
        id_producto = :rand.uniform(1000)
        comprar(id_compra, id_producto)
      end)
    end
  end
end
