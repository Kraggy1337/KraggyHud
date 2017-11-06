do return end	-- Disabled cause: WiP
KraggyHUD.Sync = KraggyHUD.Sync or {}
KraggyHUD.Sync.peers = KraggyHUD.Sync.peers or {false, false, false, false}
KraggyHUD.Sync.cache = KraggyHUD.Sync.cache or {}

local Net = _G.LuaNetworking

function KraggyHUD.Sync.table_to_string(tbl)
	return Net:TableToString(tbl) or ""
end

function KraggyHUD.Sync.string_to_table(str)
	return Net:StringToTable(str) or ""
end

-- Functions to send stuff
function KraggyHUD.Sync.send(id, data)
	if KraggyHUD.Sync.peers and data then
		managers.chat:feed_system_message(ChatManager.GAME, string.format("[%s] Syncing event %s.", id, data.event or "N/A"))	--TEST
		local exclusion = {}
		local send_data = KraggyHUD.Sync.table_to_string(data)
		for peer_id, enabled in pairs(KraggyHUD.Sync.peers) do
			if not enabled then
				table.insert(exclusion, peer_id)
			end
		end
		Net:SendToPeersExcept(exclusion, id, send_data)
	end
	if id == "KraggyHUD_Sync_Cache" then
		KraggyHUD.Sync.receive_cache_event(data)
	end
end

function KraggyHUD.Sync.gameinfo_ecm_feedback_event_sender(event, key, data)
	if KraggyHUD.Sync then
		local send_data = {
			source = "ecm",
			event = event,
			key = key,
			feedback_duration = data.feedback_duration,
			feedback_expire_t = data.feedback_expire_t
		}
		KraggyHUD.Sync.send("KraggyHUD_Sync_GameInfo_ecm_feedback", send_data)
	end
end

--receive and apply data
function KraggyHUD.Sync.receive_gameinfo_ecm_feedback_event(event_data)
	local source = data.source
	local event = event_data.event
	local key = event_data.key
	local data = { feedback_duration = event_data.feedback_duration, feedback_expire_t = data.feedback_expire_t }
	managers.chat:feed_system_message(ChatManager.GAME, string.format("[KraggyHUD_GameInfo] Received data, source: %s, event: %s.", source or "N/A", event or "N/A"))	--TEST
	if managers.gameinfo and source and key and data then
		managers.gameinfo:event(source, event, key, data)
	end
end

function KraggyHUD.Sync.receive_cache_event(event_data)
	local event = event_data.event
	local data = event_data.data
	managers.chat:feed_system_message(ChatManager.GAME, string.format("[KraggyHUD_Cache] Received data, event: %s.", event or "N/A"))	--TEST
	if KraggyHUD.Sync.cache and event and data then
		KraggyHUD.Sync.cache[event] = data
	end
end

function KraggyHUD.Sync.receive(event_data)
	local event = event_data.event
	local data = event_data.data
	managers.chat:feed_system_message(ChatManager.GAME, string.format("[KraggyHUD] Received data, event: %s.", event or "N/A"))	--TEST
	if event == "assault_lock_state" then
		if managers.hud and managers.hud._locked_assault and event and data then
			managers.hud:_locked_assault(data)
		end
	end
end

function KraggyHUD.Sync:getCache(id)
	if self.cache[id] then
		return self.cache[id]
	else
		return self.cache
	end
end

-- Manage Networking and list of peers to sync to...
Hooks:Add("NetworkReceivedData", "NetworkReceivedData_KraggyHUD", function(sender, messageType, data)
	if KraggyHUD.Sync then
		if peer then
			if messageType == "Using_KraggyHUD?" then
				Net:SendToPeer(sender, "Using_KraggyHUD!", "")
				KraggyHUD.Sync.peers[sender] = true		--Sync to peer, IDs of other peers using KraggyHUD?
				managers.chat:feed_system_message(ChatManager.GAME, "Host is using KraggyHUD ;)")	--TEST
			elseif messageType == "Using_KraggyHUD!" then
				KraggyHUD.Sync.peers[sender] = true		--Sync other peers, that new peer is using KraggyHUD?
				managers.chat:feed_system_message(ChatManager.GAME, "A Client is using KraggyHUD ;)")	--TEST
			else
				local receive_data = WoldHUD.Sync.string_to_table(data)
				if messageType == "KraggyHUD_Sync_GameInfo_ecm_feedback" then		-- receive and call gameinfo event
					managers.chat:feed_system_message(ChatManager.GAME, "Sync GameInfo event received!")	--TEST
					log("GameInfo event received!")
					KraggyHUD.Sync.receive_gameinfo_ecm_feedback_event(receive_data)
				elseif messageType == "KraggyHUD_Sync_Cache" then			-- Add data to cache
					managers.chat:feed_system_message(ChatManager.GAME, "Sync Cache event received!")	--TEST
					log("Sync Cache event received!")
					KraggyHUD.Sync.receive_cache_event(receive_data)
				elseif messageType == "KraggyHUD_Sync" then				-- Receive data that needs to be handled by data.event
					managers.chat:feed_system_message(ChatManager.GAME, "Sync event received!")	--TEST
					log("Sync event received!")
					KraggyHUD.Sync.receive(receive_data)
				end
			end
		end
	end
end)

Hooks:Add("BaseNetworkSessionOnPeerRemoved", "BaseNetworkSessionOnPeerRemoved_KraggyHUD", function(self, peer, peer_id, reason)
	if KraggyHUD.Sync and KraggyHUD.Sync.peers[peer_id] then
		KraggyHUD.Sync.peers[peer_id] = false
	end
end)

Hooks:Add("BaseNetworkSessionOnLoadComplete", "BaseNetworkSessionOnLoadComplete_KraggyHUD", function(local_peer, id)
	if KraggyHUD.Sync and Net:IsMultiplayer() then
		if Network:is_client() then
			Net:SendToPeer(managers.network:session():server_peer():id(), "Using_KraggyHUD?", "")
		else
			if managers.gameinfo then
				managers.gameinfo:register_listener("ecm_feedback_duration_listener", "ecm", "set_feedback_duration", callback(nil, KraggyHUD.Sync, "gameinfo_ecm_feedback_event_sender"))
			end
		end
	end
end)
