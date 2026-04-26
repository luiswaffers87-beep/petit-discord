defmodule MiniDiscord.Salon do
  use GenServer

  def start_link(name) do
    GenServer.start_link(__MODULE__, %{name: name, clients: [], historique: [], password: nil},
      name: via(name))
  end

  def rejoindre(salon, pid, password \\ nil), do: GenServer.call(via(salon), {:rejoindre, pid, password})
  def quitter(salon, pid),   do: GenServer.call(via(salon), {:quitter, pid})
  def broadcast(salon, msg), do: GenServer.cast(via(salon), {:broadcast, msg})
  def definir_password(salon, password), do: GenServer.call(via(salon), {:password, password})
  def has_password?(salon), do: GenServer.call(via(salon), :has_password)
  def lister do
    Registry.select(MiniDiscord.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  def init(state), do: {:ok, state}

  def handle_call({:rejoindre, pid, password}, _from, state) do
    # Vérifier le mot de passe si défini
    if state.password != nil and :crypto.hash(:sha256, password || "") != state.password do
      {:reply, {:error, :wrong_password}, state}
    else
      Process.monitor(pid)
      new_state = %{state | clients: [pid | state.clients]}
      send(pid, {:historique, state.historique})
      {:reply, :ok, new_state}
    end
  end

  def handle_call({:password, password}, _from, state) do
    hashed_password = :crypto.hash(:sha256, password)
    new_state = %{state | password: hashed_password}
    {:reply, :ok, new_state}
  end

  def handle_call(:has_password, _from, state) do
    {:reply, state.password != nil, state}
  end

  def handle_call({:quitter, pid}, _from, state) do
# TODO : Retourner {:reply, :ok, nouvel_état} avec pid retiré de state.clients
    nouvel_état = %{state | clients: List.delete(state.clients, pid)}
    {:reply, :ok, nouvel_état}
  end

  def handle_cast({:broadcast, msg}, state) do
# TODO : Envoyer {:message, msg} à chaque pid dans state.clients
    Enum.each(state.clients, fn client -> send(client, {:message, msg}) end)
# TODO : Retourner {:noreply, state}
    nouvel_historique = Enum.take([msg | state.historique], 10)
    nouvel_état = %{state | historique: nouvel_historique}
    {:noreply, nouvel_état}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
# TODO : Retirer pid de state.clients (il s'est déconnecté)
    nouvel_état = %{state | clients: List.delete(state.clients, pid)}
# TODO : Retourner {:noreply, nouvel_état}
    {:noreply, nouvel_état}
  end

  defp via(name), do: {:via, Registry, {MiniDiscord.Registry, name}}
end
