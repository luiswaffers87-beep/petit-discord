defmodule MiniDiscord.Salon do
  use GenServer

  def start_link(name) do
    GenServer.start_link(__MODULE__, %{name: name, clients: [], historique: []},
      name: via(name))
  end

  def rejoindre(salon, pid), do: GenServer.call(via(salon), {:rejoindre, pid})
  def quitter(salon, pid),   do: GenServer.call(via(salon), {:quitter, pid})
  def broadcast(salon, msg), do: GenServer.cast(via(salon), {:broadcast, msg})
  def lister do
    Registry.select(MiniDiscord.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  def init(state), do: {:ok, state}

  def handle_call({:rejoindre, pid}, _from, state) do
# TODO : Monitorer le pid avec Process.monitor/1
    Process.monitor(pid)
# TODO : Retourner {:reply, :ok, nouvel_état} avec pid ajouté à state.clients
    nouvel_état = %{state | clients: [pid | state.clients]}
    send(pid, {:historique, state.historique})
    {:reply, :ok, nouvel_état}
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
