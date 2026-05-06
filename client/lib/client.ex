defmodule MiniDiscord.Client do

  @doc """
  Point d'entrée principal du client.
  host : nom type 'xxxbore.pub'
  port : entier ex: 4040
  """
  def start(host, port) do
    case :gen_tcp.connect(to_charlist(host), port, [:binary, packet: :line, active: false]) do
      {:error, reason} ->
        IO.puts("Erreur de connexion : #{inspect(reason)}")
        System.halt(1)
      {:ok, socket} ->
        rencontre(socket)
        t_recv = Task.async(fn -> receive_loop(socket) end)
        t_send = Task.async(fn -> send_loop(socket) end)
        Task.await(t_recv, :infinity)
        Task.await(t_send, :infinity)
    end
  end

  defp rencontre(socket) do
    # "Bienvenue sur MiniDiscord!\r\n"
    recv_print(socket)
    # "Entre ton pseudo : " reste en buffer (pas de \n)
    pseudo = IO.gets("")
    :gen_tcp.send(socket, pseudo)
    # "Entre ton pseudo : Salons disponibles : ...\r\n" (concaténé car pas de \n sur le prompt)
    recv_print(socket)
    # "Rejoins un salon (ex: general) : " reste en buffer (pas de \n)
    salon = IO.gets("")
    :gen_tcp.send(socket, salon)
    # "Rejoins un salon... Tu es dans #salon\r\n" (concaténé)
    recv_print(socket)
  end

  defp recv_print(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, msg} -> IO.write(msg)
      {:error, _} -> IO.puts("Déconnecté")
    end
  end

  defp receive_loop(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, msg} ->
        IO.write(msg)
        receive_loop(socket)
      {:error, _} ->
        IO.puts("Déconnecté")
    end
  end

  defp send_loop(socket) do
    case IO.gets("") do
      :eof -> :ok
      msg ->
        :gen_tcp.send(socket, msg)
        send_loop(socket)
    end
  end

end
