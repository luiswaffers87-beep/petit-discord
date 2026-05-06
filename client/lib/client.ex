defmodule MiniDiscord.Client do

  # Clé partagée avec le serveur — 32 octets pour AES-256
  @cle "MiniDiscordSecretKey1234567890AB"

  @doc """
  Point d'entrée principal du client.
  host : nom type 'xxxbore.pub'
  port : entier ex: 4040
  """
  def start(host, port) do
    connect_with_retry(host, port, 1)
  end

  defp connect_with_retry(host, port, attempt) do
    # TODO : Tenter :gen_tcp.connect avec les bonnes options
    case :gen_tcp.connect(to_charlist(host), port, [:binary, packet: :line, active: false]) do
      # TODO : Si {:ok, socket} -> handshake(socket) puis lancer les deux loops
      {:ok, socket} ->
        rencontre(socket)
        t_recv = Task.async(fn -> receive_loop(socket, host, port) end)
        _t_send = Task.async(fn -> send_loop(socket) end)
        Task.await(t_recv, :infinity)
      # TODO : Si {:error, reason} ->
      # TODO :   Afficher "Tentative #{attempt} échouée : #{reason}"
      # TODO :   Attendre 2 secondes avec :timer.sleep(2000)
      # TODO :   Rappeler connect_with_retry(host, port, attempt + 1)
      {:error, reason} ->
        IO.puts("Tentative #{attempt} échouée : #{reason}")
        :timer.sleep(2000)
        connect_with_retry(host, port, attempt + 1)
    end
  end

  defp rencontre(socket) do
    # TODO : Lire les messages du serveur avec recv_print(socket)
    recv_print(socket)  # "Bienvenue sur MiniDiscord!"
    # TODO : Envoyer le pseudo choisi par l'utilisateur avec IO.gets/1
    # Gère le cas où le pseudo est déjà pris (boucle côté serveur)
    choisir_pseudo_client(socket)  # "Entre ton pseudo :" + éventuelles erreurs + "Salons disponibles"
    # TODO : Lire la suite (liste des salons)
    recv_print(socket)  # "Rejoins un salon :"
    # TODO : Envoyer le nom du salon
    salon = IO.gets("")
    :gen_tcp.send(socket, salon)
    # TODO : Lire la confirmation
    recv_print(socket)  # "Tu es dans #salon"
  end

  defp choisir_pseudo_client(socket) do
    recv_print(socket)  # "Entre ton pseudo :"
    pseudo = IO.gets("")
    :gen_tcp.send(socket, pseudo)
    # La réponse est soit "Ce pseudo est déjà pris..." soit "Salons disponibles..."
    case :gen_tcp.recv(socket, 0) do
      {:ok, msg} ->
        IO.write(msg)
        if String.contains?(msg, "déjà pris") do
          choisir_pseudo_client(socket)
        end
      {:error, _} ->
        IO.puts("Déconnecté")
    end
  end

  defp recv_print(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, msg} -> IO.write(msg)
      {:error, _} -> IO.puts("Déconnecté")
    end
  end

  defp receive_loop(socket, host, port) do
    case :gen_tcp.recv(socket, 0) do
      # TODO : Si {:ok, msg} -> afficher avec IO.write/1 et rappeler receive_loop
      {:ok, msg} ->
        IO.write(decrypt(msg))
        receive_loop(socket, host, port)
      {:error, reason} ->
        IO.puts("\nConnexion perdue (#{reason}). Reconnexion...")
        # TODO : Fermer proprement la socket avec :gen_tcp.close/1
        :gen_tcp.close(socket)
        # TODO : Rappeler connect_with_retry(host, port, 1)
        connect_with_retry(host, port, 1)
    end
  end

  defp send_loop(socket) do
    # TODO : Lire depuis le clavier avec IO.gets("")
    case IO.gets("") do
      :eof -> :ok
      msg ->
        # TODO : Envoyer au serveur avec :gen_tcp.send/2
        case valider_message(String.trim(msg)) do
          {:ok, _} ->
            case :gen_tcp.send(socket, encrypt(String.trim(msg))) do
              :ok -> send_loop(socket)
              {:error, _} -> :ok
            end
          {:error, raison} ->
            IO.puts("Message refusé : #{raison}")
            send_loop(socket)
        end
    end
  end

  defp encrypt(msg) do
    iv = :crypto.strong_rand_bytes(16)
    chiffre = :crypto.crypto_one_time(:aes_256_ctr, @cle, iv, msg, true)
    Base.encode64(iv <> chiffre) <> "\r\n"
  end

  defp decrypt(line) do
    case Base.decode64(String.trim(line)) do
      {:ok, <<iv::binary-size(16), chiffre::binary>>} ->
        :crypto.crypto_one_time(:aes_256_ctr, @cle, iv, chiffre, false)
      _ ->
        line
    end
  end

  @mots_interdits ~w(spam insulte connard merde puto)

  defp valider_message(msg) do
    msg_lower = String.downcase(msg)
    cond do
      String.length(msg) == 0 ->
        {:error, "Message vide"}
      String.length(msg) > 500 ->
        {:error, "Message trop long (max 500 chars)"}
      String.match?(msg, ~r/[\\?<>]/) ->
        {:error, "Caractères interdits"}
      Enum.any?(@mots_interdits, &String.contains?(msg_lower, &1)) ->
        {:error, "Message contient un mot interdit"}
      true ->
        {:ok, msg}
    end
  end

end
