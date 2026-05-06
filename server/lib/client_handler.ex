defmodule MiniDiscord.ClientHandler do
  require Logger

  def start(socket) do
    :gen_tcp.send(socket, "Bienvenue sur MiniDiscord!\r\n")
    pseudo = choisir_pseudo(socket)

    choisir_salon(socket, pseudo)
  end

  defp choisir_salon(socket, pseudo) do
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

    # Demander le mot de passe si nécessaire
    password = if MiniDiscord.Salon.has_password?(salon) do
      :gen_tcp.send(socket, "Ce salon est protégé par un mot de passe : ")
      {:ok, pwd} = :gen_tcp.recv(socket, 0)
      String.trim(pwd)
    else
      nil
    end

    case MiniDiscord.Salon.rejoindre(salon, self(), password) do
      :ok ->
        MiniDiscord.Salon.broadcast(salon, "📢 #{pseudo} a rejoint ##{salon}\r\n")
        :gen_tcp.send(socket, "Tu es dans ##{salon} — écris tes messages !\r\n")
        loop(socket, pseudo, salon)
      {:error, :wrong_password} ->
        :gen_tcp.send(socket, "Mot de passe incorrect. Veux-tu réessayer (r) ou choisir un autre salon (c) ? ")
        {:ok, choix} = :gen_tcp.recv(socket, 0)
        choix = String.trim(choix)
        case choix do
          "r" -> rejoindre_salon(socket, pseudo, salon)  # Réessayer avec le même salon
          "c" -> choisir_salon(socket, pseudo)  # Choisir un autre salon
          _ ->
            :gen_tcp.send(socket, "Choix invalide. Retour au menu principal.\r\n")
            start(socket)  # Redémarrer complètement
        end
    end
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
        if String.starts_with?(msg, "/") do
          gerer_commande(socket, pseudo, salon, msg)
        else
          MiniDiscord.Salon.broadcast(salon, "[#{pseudo}] #{msg}\r\n")
          loop(socket, pseudo, salon)
        end

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
    :ets.delete(:pseudos, pseudo)
  end

  defp gerer_commande(socket, pseudo, salon, commande) do
    case commande do
      "/list" ->
        salons = MiniDiscord.Salon.lister()
        liste = if salons == [], do: "Aucun salon actif", else: Enum.join(salons, ", ")
        :gen_tcp.send(socket, "Salons actifs : #{liste}\r\n")
        loop(socket, pseudo, salon)

      "/join " <> nouveau_salon ->
        nouveau_salon = String.trim(nouveau_salon)
        if nouveau_salon == "" do
          :gen_tcp.send(socket, "Usage : /join <nom_du_salon>\r\n")
          loop(socket, pseudo, salon)
        else
          # Quitter l'ancien salon
          MiniDiscord.Salon.quitter(salon, self())
          MiniDiscord.Salon.broadcast(salon, "👋 #{pseudo} a quitté ##{salon}\r\n")

          # Créer/rejoindre le nouveau salon
          case Registry.lookup(MiniDiscord.Registry, nouveau_salon) do
            [] ->
              DynamicSupervisor.start_child(
                MiniDiscord.SalonSupervisor,
                {MiniDiscord.Salon, nouveau_salon})
            _ -> :ok
          end

          # Demander le mot de passe si nécessaire
          password = if MiniDiscord.Salon.has_password?(nouveau_salon) do
            :gen_tcp.send(socket, "Mot de passe pour ##{nouveau_salon} : ")
            {:ok, pwd} = :gen_tcp.recv(socket, 0)
            String.trim(pwd)
          else
            nil
          end

          case MiniDiscord.Salon.rejoindre(nouveau_salon, self(), password) do
            :ok ->
              MiniDiscord.Salon.broadcast(nouveau_salon, "📢 #{pseudo} a rejoint ##{nouveau_salon}\r\n")
              :gen_tcp.send(socket, "Tu es maintenant dans ##{nouveau_salon}\r\n")
              loop(socket, pseudo, nouveau_salon)
            {:error, :wrong_password} ->
              :gen_tcp.send(socket, "Mot de passe incorrect. Retour à ##{salon}\r\n")
              # Rejoindre l'ancien salon sans mot de passe (il n'en a pas normalement)
              MiniDiscord.Salon.rejoindre(salon, self())
              loop(socket, pseudo, salon)
          end
        end

      "/quit" ->
        MiniDiscord.Salon.broadcast(salon, "👋 #{pseudo} s'est déconnecté\r\n")
        MiniDiscord.Salon.quitter(salon, self())
        liberer_pseudo(pseudo)
        :gen_tcp.send(socket, "Au revoir !\r\n")
        :gen_tcp.close(socket)

      "/password " <> new_password ->
        new_password = String.trim(new_password)
        if new_password == "" do
          :gen_tcp.send(socket, "Usage : /password <mot_de_passe>\r\n")
          loop(socket, pseudo, salon)
        else
          MiniDiscord.Salon.definir_password(salon, new_password)
          :gen_tcp.send(socket, "Mot de passe défini pour ##{salon}\r\n")
          loop(socket, pseudo, salon)
        end

      _ ->
        :gen_tcp.send(socket, "Commande inconnue. Commandes disponibles : /list, /join <salon>, /password <mdp>, /quit\r\n")
        loop(socket, pseudo, salon)
    end
  end
end
