defmodule MiniDiscord.Client do

  @doc """
  Point d'entrée principal du client.
  host : nom type 'xxxbore.pub'
  port : entier ex: 4040
  """
  def start(host, port) do
      # TODO : Connecter la socket avec :gen_tcp.connect/3
      # TODO : Options : [:binary, packet: :line, active: false]
      # TODO : En cas d'erreur {:error, reason} -> afficher l'erreur et quitter
      # TODO : Appeler la fonction rencontre(socket) pour le pseudo et le salon
      # TODO : Lancer le receiver dans un Task.async : fn -> receive_loop(socket) end
      # TODO : Lancer le sender dans un Task.async : fn -> send_loop(socket) end
      # TODO : Attendre les deux tasks avec Task.await/2 (timeout: :infinity)
  end

  defp rencontre(socket) do
      # TODO : Lire les messages du serveur avec recv_print(socket)
      # TODO : Envoyer le pseudo choisi par l'utilisateur avec IO.gets/1
      # TODO : Lire la suite (liste des salons)
      # TODO : Envoyer le nom du salon
      # TODO : Lire la confirmation
  end

  defp receive_loop(socket) do
      # TODO : Appeler :gen_tcp.recv(socket, 0) — bloquant jusqu'à réception
      # TODO : Si {:ok, msg} -> afficher avec IO.write/1 et rappeler receive_loop
      # TODO : Si {:error, _} -> afficher "Déconnecté" et arrêter
  end

  defp send_loop(socket) do
      # TODO : Lire depuis le clavier avec IO.gets("")
      # TODO : Envoyer au serveur avec :gen_tcp.send/2
      # TODO : Rappeler send_loop(socket)
  end

end