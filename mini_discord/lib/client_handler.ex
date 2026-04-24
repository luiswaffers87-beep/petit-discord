defmodule MiniDiscord.ClientHandler do
  require Logger

  def start(socket) do
    :gen_tcp.send(socket, "Bienvenue sur MiniDiscord!\r\n")
    pseudo = choisir_pseudo(socket)

    :gen_tcp.send(socket, "Salons disponibles : #{salons_dispo()}\r\n")
    :gen_tcp.send(socket, "Rejoins un salon (ex: general) : ")
    {:ok, salon} = :gen_tcp.recv(socket, 0)
    salon = String.trim(salon)

    rejoindre_salon(socket, pseudo, salon)
  end

  defp rejoindre_salon(socket, pseudo, salon) do
    case Registry.lookup(MiniDiscord.Registry, salon) do
      [] ->
        DynamicSupervisor.start_child(
          MiniDiscord.SalonSupervisor,
          {MiniDiscord.Salon, salon})
      _ -> :ok
    end

    MiniDiscord.Salon.rejoindre(salon, self())
    MiniDiscord.Salon.broadcast(salon, "📢 #{pseudo} a rejoint ##{salon}\r\n")
    :gen_tcp.send(socket, "Tu es dans ##{salon} — écris tes messages !\r\n")

    loop(socket, pseudo, salon)
  end

  defp loop(socket, pseudo, salon) do
    receive do
      {:message, msg} ->
        :gen_tcp.send(socket, msg)
      {:historique, historique} ->
        :gen_tcp.send(socket, "\r\n📜 Historique du salon :\r\n")
        Enum.each(Enum.reverse(historique), fn msg ->
          :gen_tcp.send(socket, msg)
        end)
        :gen_tcp.send(socket, "\r\n")
    after 0 -> :ok
    end

    case :gen_tcp.recv(socket, 0, 100) do
      {:ok, msg} ->
        msg = String.trim(msg)
        MiniDiscord.Salon.broadcast(salon, "[#{pseudo}] #{msg}\r\n")
        loop(socket, pseudo, salon)

      {:error, :timeout} ->
        loop(socket, pseudo, salon)

      {:error, reason} ->
        Logger.info("Client déconnecté : #{inspect(reason)}")
        MiniDiscord.Salon.broadcast(salon, "👋 #{pseudo} a quitté ##{salon}\r\n")
        MiniDiscord.Salon.quitter(salon, self())
        liberer_pseudo(pseudo)
    end
  end

  defp salons_dispo do
    case MiniDiscord.Salon.lister() do
      [] -> "aucun (tu seras le premier !)"
      salons -> Enum.join(salons, ", ")
    end
  end

  defp choisir_pseudo(socket) do
    :gen_tcp.send(socket, "Entre ton pseudo : ")
    {:ok, pseudo} = :gen_tcp.recv(socket, 0)
    pseudo = String.trim(pseudo)
# TODO : Si pseudo_disponible?(pseudo) -> reserver_pseudo(pseudo) et retourner pseudo
    if pseudo_disponible?(pseudo) do
      reserver_pseudo(pseudo)
      pseudo
# TODO : Sinon -> envoyer un message d'erreur et rappeler choisir_pseudo(socket)
    else
      :gen_tcp.send(socket, "Ce pseudo est déjà pris, choisis-en un autre.\r\n")
      choisir_pseudo(socket)
    end
  end

  defp pseudo_disponible?(pseudo) do
# TODO : Vérifier avec :ets.lookup(:pseudos, pseudo) 
# :ets.lookup retorna una lista. Si está vacía [], el pseudo es disponible
# Retornar true si disponible, false sinon
    :ets.lookup(:pseudos, pseudo) == []
  end

  defp reserver_pseudo(pseudo) do
# TODO : Insérer dans :ets avec :ets.insert(:pseudos, {pseudo, self()})
# self() es el PID del cliente actual
  :ets.insert(:pseudos, {pseudo, self()})
  end

  defp liberer_pseudo(pseudo) do
# TODO : Supprimer de :ets avec :ets.delete(:pseudos, pseudo)
  :ets.delete(:pseudos, pseudo)
  end

end
