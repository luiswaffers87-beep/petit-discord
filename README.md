# petit-discord
TP - Programmation fonctionnelle
Luis Angel Garcia Muñoz 

Phase 1 — GenServer

Q1. Pourquoi utilise-t-on Process.monitor/1 dans handle_call({:rejoindre}) ? 

- Une fois qu'un utilisateur s'est connecté, et qu'on l'a ajouté à la liste des clients, on dois vérifier en permanance s'il est toujours là pour continuer à lui envoyer les messages du salon ou pas.  

Q2. Que se passe-t-il si on n'implémente pas handle_info({:DOWN, ...}) ? 

- Si on n'implémente pas handle_info(...) on aurait des clients "zombie" dans notre liste de clients. Ceux qui se sont déconnecté sans passer par handle_call({:quitter, ...}) ne seront jamais retirés de la liste de clients.  

Q3. Quelle est la différence entre handle_call et handle_cast ? Pourquoi broadcast est un cast ?

- handle_call est un appel synchrone, elle attends une réponse 
- handle_cast est un appel asynchrone, elle n'attends pas de réponse
- C'est pour ça qu'on utilise handle_call pour joindre et quitter un salon, l'état change et handle_cast pour envoyer un message, on envoie des messages aux clients connectés sans changer l'état. 


Phase 2 — Supervision et robustesse

Q4. Le salon redémarre-t-il après le kill ? Pourquoi ?

- Oui, le salon redémarre automatiquement parce que le DynamicSupervisor utilise la stratégie :one_for_one, qui redémarre seulement le processus défaillant sans affecter les autres processus.

Q5. Quelle est la différence entre les stratégies :one_for_one et :one_for_all ?

- :one_for_one : Redémarre seulement le processus qui a échoué.
- :one_for_all : Redémarre tous les enfants du superviseur si l'un d'eux échoue.