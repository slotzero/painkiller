GameStates =
{
    WarmUp   = 1,
    Counting = 2,
    Playing  = 3,
    Finished = 4
}

MPCfg =
{
    GameMode         = "Free For All", -- "Free For All", "Team Deathmatch", "People Can Fly", "Voosh", "The Light Bearer", "Capture The Flag", "Last Man Standing", "Duel"
    GameState        = GameStates.Finished, -- "Counting", "Playing", "Finished"
    TeamDamage       = true,
    AllowBrightskins = true,
    FragLimit        = 0,
    TimeLimit        = 0,
    CaptureLimit	 = 0,
    LMSLives         = 5,
    ClientConsoleLockdown = false,
}

MPGameRules =
{
    ["Free For All"] =
    {
        StartState = GameStates.Counting,
        AutoRespawnAfterCountdown = false,
        Teams = false,
    },
    Voosh =
    {
        StartState = GameStates.Counting,
        AutoRespawnAfterCountdown = false,
        Teams = false,
    },
    ["The Light Bearer"] =
    {
        StartState = GameStates.Counting,
        AutoRespawnAfterCountdown = false,
        Teams = false,
    },
    ["People Can Fly"] =
    {
        StartState = GameStates.WarmUp,
        AutoRespawnAfterCountdown = true,
        Teams = false,
    },
    ["Team Deathmatch"] =
    {
        StartState = GameStates.WarmUp,
        AutoRespawnAfterCountdown = true,
        Teams = true,
    },
    ["Capture The Flag"] =
    {
        StartState = GameStates.WarmUp,
        AutoRespawnAfterCountdown = true,
        Teams = true,
    },
    ["Last Man Standing"] =
    {
        StartState = GameStates.WarmUp,
        AutoRespawnAfterCountdown = true,
        Teams = false,
    },
    ["Duel"] =
    {
        StartState = GameStates.WarmUp,
        AutoRespawnAfterCountdown = true,
        Teams = false,
        PlayerLimit = 2,
    },
}

MPCfgBackup = {}
--============================================================================
-- MULTIPLAYER
--============================================================================
function Game:IsServer()
    if self.GMode == GModes.MultiplayerServer or self.GMode == GModes.DedicatedServer then
        return true
    end
    return false
end
--============================================================================
-- [ENGINE - COMMON] --
function Game:OnSwitchToState(mode)
    self.GMode = mode
    if mode == GModes.MultiplayerClient then
        self.WaitForServer = true
        WORLD.SetGameVisible(false)
    end
    if mode ~= GModes.SingleGame then
		Game:Print(">> BeforeChangeGameType, preload templates "..mode)
		self:InitTemplates()
		self._onSwitch = true
		Game:Print(">> BeforeChangeGameType, preload templates end")
        MPCfg.GameMode = "Free For All"
    else
        MPCfg.GameMode = ""
    end
    MPCfg.ClientConsoleLockdown = false
    self.Active = false
end
--============================================================================
-- [ENGINE - COMMON] --
function Game:BeforeChangeGameType(mode)
    --Log("---------------------------------- START ----------------------------------\n")
    if self.GMode == GModes.DedicatedServer then
        Editor.Enabled = false
    end
end
--============================================================================
-- [ENGINE - COMMON] --
function Game:AfterChangeGameType()
    if self.GMode ~= GModes.SingleGame then
        GOD = false

        PHYSICS.SetGravity(Tweak.GlobalData.MPGravity)

        if Cfg.AllowBunnyhopping then
            PHYSICS.SetBunnyHopAcceleration(Tweak.MultiPlayerMove.BunnyHopAcceleration)
        else
            PHYSICS.SetBunnyHopAcceleration(0)
        end

        self._emptyServerTime = 0
    else
        PHYSICS.SetBunnyHopAcceleration(Tweak.PlayerMove.BunnyHopAcceleration)
        PHYSICS.SetGravity(Tweak.GlobalData.Gravity)
    end
end
--============================================================================
-- [ENGINE - COMMON] --
function Game:AfterWorldSynchronization(mapName,levelName)

    Game:Print("AfterWorldSynchronization")
    Game._countTimer = 0
    Game._countTimerStart = nil

    if Game:IsServer() then
        local maxplayers = Cfg.MaxPlayers
        if Cfg.GameMode == "Duel" then maxplayers = 2 end
        local gameState = "playing"
        if MPCfg.GameState == GameStates.WarmUp then
			gameState = "warmup"
		elseif MPCfg.GameState == GameStates.Counting then
			gameState = "counting"
		elseif MPCfg.GameState == GameStates.Finished then
			gameState = "finished"
		end
		local numPlayers = 0
		local numSpecs = 0
		for id,ps in Game.PlayerStats do
			if ps.Spectator == 0 then
				numPlayers = numPlayers + 1
			else
				numSpecs = numSpecs + 1
			end
		end
        GAMESPY.SetServerInfo(
			PK_VERSION,
            Cfg.ServerName,
            Cfg.ServerPassword,
            levelName,
            Cfg.GameMode,
            maxplayers,
            Cfg.MaxSpectators,
            Cfg.FragLimit,
            Cfg.TimeLimit,
--            Cfg.TimeLimit * 60
			Game._TimeLimitOut,
			gameState,
			numPlayers,
			numSpecs
        )

        if Cfg.AllowBunnyhopping then
            PHYSICS.SetBunnyHopAcceleration(Tweak.MultiPlayerMove.BunnyHopAcceleration)
        else
            PHYSICS.SetBunnyHopAcceleration(0)
        end

        MPCfg.GameState = MPGameRules[Cfg.GameMode].StartState
        if Cfg.NoWarmup then MPCfg.GameState = GameStates.Counting end
        Game.SetConfiguration(Cfg.AllowBrightskins, Cfg.GameMode, Cfg.FragLimit, Cfg.CaptureLimit, Cfg.LMSLives, Cfg.TeamDamage, Cfg.ClientConsoleLockdown)
        Game.SetTimeLimit(Cfg.TimeLimit,0,Cfg.WarmUpTime)
        Game.VooshCurWeapon = math.random(1,5)
        GAMESPY.SetGameMode(2)
    else
        -- reset ping
        NET.ClientPingReset()
    end

    -- zglaszam request stworzenia mojego playera na serwerze
    if Game.GMode == GModes.MultiplayerServer or Game.GMode == GModes.MultiplayerClient then

        local pn = "Player_"..NET.GetClientID()
        if Cfg.PlayerName then pn = Cfg.PlayerName end

        if not NET.IsSpectator(NET.GetClientID()) then
            -- wysylam do serwera zadanie stworzenia mojego playera w swiecie gry
            self.NewPlayerRequest(NET.GetClientID(),pn,Cfg.PlayerModel,Cfg.Team,0,0)
        else
            self.NewPlayerRequest(NET.GetClientID(),pn,Cfg.PlayerModel,Cfg.Team,0,1)
        end
    end

--    if (self.GMode == GModes.DedicatedServer and Cfg.LimitServerFPS) or self.GMode == GModes.MultiplayerServer then
--        WORLD.SetMaxFPS(Cfg.ServerFPS)
--    end

    self.VooshTick = 0
    Game.WaitForServer = nil
    Game.Active = true
    WORLD.SetGameVisible(true)
    INP.Reset()
    MOUSE.Lock()
end
--============================================================================
-- [ENGINE - SERVER ONLY - BEFORE SERVER STARTUP] --
function Game_SetupCustomGameSpyVariables()

--  MODDERS: use NET.SetupGameSpyVariable( name, isString, startValue ) for every
--  misc variable you want reported to GameSpy.
--  name is variable name - string.
--  isString is bool. variable can be sent as string or int.
--  startValue is the starting value of the variable. given as string, is
--  converted to int in engine as neccessary.

--  You can use NET.SetGameSpyVariable( name, value ) to change value of the
--  variable at any time later.

end
--============================================================================
-- [ENGINE - SERVER & CLIENTS - ALSO FOR MODDERS] --
function Game_InterpretVariable(name,value)

--  MODDERS: this functions will receive every (name,value) string pair you
--  send from the other host using NET.SendVariable( clientId, name, value )

end
--============================================================================
-- [ENGINE - SERVER ONLY] --
function Game:AfterNewClientConnected(clientID)

    if Game.PlayerStats[clientID] then return end -- ten klient juz sie podlaczyl
    -- send config values

    SendNetMethod(Game.SetConfiguration,clientID, true, true, Cfg.AllowBrightskins, Cfg.GameMode, Cfg.FragLimit, Cfg.CaptureLimit, Cfg.LMSLives, Cfg.TeamDamage, Cfg.ClientConsoleLockdown)
    SendNetMethod(Game.SetGameState,clientID, true, true, MPCfg.GameState)

    Game:Print("AfterNewClientConnected: "..clientID)
    -- do nowego klienta musze wyslac liste aktualnych graczy na serwerze
    for i,o in self.Players do
        if o.ClientID ~= clientID then -- bez informacji o sobie, ktora bedzie niezaleznie wyslana do wszystkich klientow
            local ps = Game.PlayerStats[o.ClientID]
            if ps then -- ?????? wywalilo kiedys dedicated
                local pu_state = 0 -- power ups
                if o.HasQuad           then pu_state = AddBitFlag(pu_state, 2) end -- quad
                if o.HasWeaponModifier then pu_state = AddBitFlag(pu_state, 4) end -- weapon modifier
                if o.HasFlag           then pu_state = AddBitFlag(pu_state, 8) end -- flag
                SendNetMethod(Game.OnNewPlayerInGame, clientID, true, true, o.ClientID, o._Entity, ps.Name, ps.Score, ps.Kills, ps.Deaths, pu_state ,INP.GetTime()-ps._starttime, ps.Team, ps.State, ps.Spectator)
            end
        end
    end
    -- send limits info & current time
    SendNetMethod(Game.SetTimeLimit,clientID, true, true,MPCfg.TimeLimit,Game._TimeLimitOut,Game._countTimer)
    -- reset ping
    NET.ClientPingReset(clientID)
    --Slot Zero, 03-04-2006: Added welcome message.
    SendNetMethod(Game.ConsoleMessage,clientID,true,true,"#4Welcome #4to Shmack's Painkiller #4server!")
end
--============================================================================
-- [ENGINE - SERVER ONLY]
function Game:AfterClientDisconnected(clientID)
    Game:Print("AfterClientDisconnected: "..clientID)
    -- powiadamiamy o tym wszystkich klientow
    Game.OnPlayerLeaveGame(clientID)

    if Game._voteCmd ~= "" then
		Game.PlayerVoteRequest(clientID,0)
	end

    if MPCfg.GameState == GameStates.Playing then
        CPlayer:Common_UpdateStats(true,-1,-1,0,0)
    end
end
--============================================================================
function Game:SyncCounter(sec)
    Game._countTimer = sec
    local s = math.floor(sec)+1
    if s>=2 and s <=4  then
        SOUND.Play2D(string.format("multiplayer/lucifer/Lucifer_time%02d",s-1),100,true,true)
    end
    if s >= 4 and s <= 11 then
        SOUND.Play2D("multiplayer/clock-tick",100,true,true)
    end
    --CONSOLE.AddMessage(sec)
end
Network:RegisterMethod("Game.SyncCounter", NCallOn.AllClients, NMode.Unreliable, "f")
--============================================================================
-- [ENGINE - SERVER ONLY]
Game.PingTick = 0
--Game.YawTick = 0
Game.VooshTick = 0
Game.VooshCurWeapon = 0
Game.LastGameSpyReport = 0
function Game:OnMultiplayerServerTick(delta)

    if MPCfg.GameState == GameStates.Counting then

        if not self._countTimerLast then
            self._countTimerLast = INP.GetTime()
        end

        local tm = INP.GetTime()
        self._countTimer = self._countTimer - ( tm - self._countTimerLast)
        self._countTimerLast = tm

        local s = math.floor(self._countTimer)+1
        if s and self._countTimerInt ~= s then
            Game.SyncCounter(self._countTimer)
            self._countTimerInt = s
        end
    else
        self._countTimerLast = nil
    end

    if MPCfg.GameState ~= GameStates.Finished then
        if MPCfg.GameMode == "Voosh" then
            self.VooshTick = self.VooshTick + delta
            if not Game._bimSound and  self.VooshTick >= 23 then
                Game.BimBam()
                Game._bimSound = true
            end
            if self.VooshTick >= 25 then
                Game._bimSound = nil
                self.VooshTick = 0
                local w = Game.VooshCurWeapon
                while w == Game.VooshCurWeapon do
                    Game.VooshCurWeapon = math.random(1,5)
                end
                for i,o in self.Players do
                    if not o._died then
                        CPlayer.WeaponChangeConfirmation(o.ClientID,o._Entity,Game.VooshCurWeapon)
                    end
                end
            end
        end

        if MPCfg.GameState == GameStates.Counting then
            if self._countTimer <= 0 then
                Game.SetGameState(GameStates.Playing)
                if MPGameRules[MPCfg.GameMode].AutoRespawnAfterCountdown then -- autorespawn
                    local items = GObjects:GetAllObjectsByClass("CItem")
                    for i,o in items do
                        o:TryToRespawn(true)
                    end
                    for i,o in GObjects.Elements do
                        if o._mpWarmUp then GObjects:ToKill(o) end
                    end
                    WORLD.DeleteDyingEntities()
                    -- reset all players first
                    for i,o in Game.PlayerStats do
                        if o.Spectator == 0 then
                            Game.ResetPlayer(o.ClientID)
                        end
                    end
                    -- and respawn all players
                    for i,o in Game.PlayerStats do
                        if o.Spectator == 0 then
                            Game.PlayerRespawnRequest(o.ClientID)
                        end
                    end

                end
                Game._countTimerInt = nil
            end
        end
    end

    self.PingTick = self.PingTick +  delta
    --self.YawTick = self.YawTick +  delta

    local pc = table.getn(self.Players)
    if pc > 0 then
        -- send ping info - nie czesciej niz co 2 sec
        if self.PingTick >= 2 then
            local j = 1
            local marg = {}
            for i,o in self.Players do
                marg[j] = o.ClientID
                marg[j+1] = NET.GetClientPing(o.ClientID)
                if marg[j+1] > 255 then marg[j+1] = 255 end -- max byte
                marg[j+2] = NET.GetClientPacketLoss(o.ClientID)
                if marg[j+2] > 255 then marg[j+2] = 255 end -- max byte
                j = j + 3
            end
            self.PlayerPingInfo(table.getn(self.Players),unpack(marg))
            self.PingTick = 0
        end

        -- send players camera  - nie czesciej niz 15 razy na sec
        self._emptyServerTime = -1
    else
		if self._emptyServerTime == -1 then
			self._emptyServerTime = INP.GetTime()
		elseif self._emptyServerTime > 0 then
			if INP.GetTime() - self._emptyServerTime > 30 then
				Game_RestoreServerSettings()
				self._emptyServerTime = 0
			end
		end
    end

	if INP.GetTime() - self.LastGameSpyReport >= 1 then
		local maxplayers = Cfg.MaxPlayers
		if Cfg.GameMode == "Duel" then maxplayers = 2 end
		local gameState = "playing"
        if MPCfg.GameState == GameStates.WarmUp then
			gameState = "warmup"
		elseif MPCfg.GameState == GameStates.Counting then
			gameState = "counting"
		elseif MPCfg.GameState == GameStates.Finished then
			gameState = "finished"
		end
		local numPlayers = 0
		local numSpecs = 0
		for id,ps in Game.PlayerStats do
			if ps.Spectator == 0 then
				numPlayers = numPlayers + 1
			else
				numSpecs = numSpecs + 1
			end
		end
		GAMESPY.SetServerInfo(
			PK_VERSION.."+",
			Cfg.ServerName,
			Cfg.ServerPassword,
			Lev._Name,
			Cfg.GameMode,
			maxplayers,
			Cfg.MaxSpectators,
			Cfg.FragLimit,
			Cfg.TimeLimit,
			self._TimeLimitOut,
			gameState,
			numPlayers,
			numSpecs
		)

		Game:GameSpy_UpdatePlayers()

		self.LastGameSpyReport = INP.GetTime()
--		CONSOLE.AddMessage("GAMESPY updated ("..Lev._Name..") "..self._TimeLimitOut)
	end
end
--============================================================================
function Game:BimBam()
    SOUND.Play2D("multiplayer/voosh_weapon_change",100,true,true)
end
Network:RegisterMethod("Game.BimBam", NCallOn.AllClients, NMode.Unreliable, "")
--============================================================================
-- [ENGINE - CLIENT ONLY]
function Game:OnMultiplayerClientTick(delta)
    if not self._procStats then
		if MPCfg.GameState == GameStates.WarmUp then
			if INP.UIAction(UIActions.Scoreboard) then
				local t = nil
				if MPGameRules[MPCfg.GameMode].StartState == GameStates.WarmUp then t = 2  end
				Game._procStats = GObjects:Add(TempObjName(),Templates["EndOfMatch.CProcess"]:New(t))
                INP.RemoveUIAction(UIActions.Scoreboard)
			end
		else
			if INP.UIAction(UIActions.Scoreboard) then
				MPSTATS.Show()
			else
				MPSTATS.Hide()
			end
		end
    else
		if INP.UIAction(UIActions.Scoreboard) and
		   (MPCfg.GameState == GameStates.WarmUp or (MPCfg.GameState == GameStates.Counting and (MPGameRules[MPCfg.GameMode].StartState == GameStates.WarmUp))) then
			GObjects:ToKill(Game._procStats)
            Game._procStats = nil
            Hud.Enabled = true
            MPSTATS.Hide()
            INP.RemoveUIAction(UIActions.Scoreboard)
		end
    end
end
--============================================================================
-- [ENGINE - COMMON]
function Game:OnMultiplayerCommonTick(delta)
    if MPCfg.GameState ~= GameStates.Playing then return end

    -- time out
    if MPCfg.TimeLimit > 0 and self._TimeLimitOut >= 0 and MPCfg.GameState ~= GameStates.Finished then
        local tm = INP.GetTime()
        self._TimeLimitOut = self._TimeLimitOut + (tm - self._LastTime)
        self._LastTime = tm
        if self._TimeLimitOut >= MPCfg.TimeLimit * 60 then
            if Game:IsServer() then StringToDo = "Game.EndOfMatch()" end
            MPSTATS.SetTimeLeft("00:00")
            SOUND.Play2D("multiplayer/clock-bell-bigger",100,true,true)
            self._TimeLimitOut = -1 -- koniec
        else
            local tm = (MPCfg.TimeLimit*60 - self._TimeLimitOut) / 60
            local m = math.floor(tm)
            local s = math.floor((tm - m) * 60)
            MPSTATS.SetTimeLeft(m..":"..string.format("%02d",s))
            if self._lasts and self._lasts ~= s then
                if m == 0 and s <= 10 then
                    if math.mod(s,2) == 0 then
                        SOUND.Play2D("multiplayer/clock-tick",100,true,true)
                    else
                        SOUND.Play2D("multiplayer/clock-tock",100,true,true)
                    end
                    if s == 10 or s == 6 or s == 2 then SOUND.Play2D("multiplayer/clock-bell-bigger",100,true,true) end
                    if s == 8 or  s == 4 or s == 0 then SOUND.Play2D("multiplayer/clock-bell",100,true,true) end
                else
                    if s == 0 then

                        SOUND.Play2D("multiplayer/clock-tick",100,true,true)
                        CONSOLE.AddMessage(Languages.Texts[393]..": "..m.." "..Languages.Texts[729])

                        if m>=1 and m <=10  then
                            SOUND.Play2D(string.format("multiplayer/lucifer/Lucifer_time%02d",m),100,true,true)
                        elseif m == 15 then
                            SOUND.Play2D("multiplayer/lucifer/Lucifer_time15",100,true,true)
                        elseif m == 20 then
                            SOUND.Play2D("multiplayer/lucifer/Lucifer_time20",100,true,true)
                        elseif m == 25 then
                            SOUND.Play2D("multiplayer/lucifer/Lucifer_time25",100,true,true)
                        else
                            SOUND.Play2D("multiplayer/clock-bell-bigger",100,true,true)
                        end
                    end
                end
            end
            self._lasts = s
        end
    end
end
--============================================================================
-- [ENGINE - SERVER ONLY]
function Game:NewPlayerRequest(clientID,name,model,team,state,spectator)
    Game:Print("NewPlayerRequest")
    if MPCfg.GameMode == "Last Man Standing" and (MPCfg.GameState == GameStates.Playing or MPCfg.GameState == GameStates.Finished) then
        spectator = 1
    end
    -- powiadamiam wszystkich klientow oraz serwer o nowym playerze
--    local t1, t2 = MPSTATS.GetTeamsScore()
    Game.OnNewPlayerInGame(clientID,nil,name,0,0,0,AddBitFlag(0,1),0, team, state, spectator, Game._team1Score, Game._team2Score)
    if MPCfg.GameState == GameStates.Finished then
        SendNetMethod(Game.EndOfMatch,clientID,true,true)
    end
    -- warmup respawn
    Game.PlayerStats[clientID].Model = MPModels[model] -- pamietam na serwerze jakim modelem bedzie gral
    if MPCfg.GameState == GameStates.WarmUp and spectator == 0 then
        Game.PlayerRespawnRequest(clientID)
    end
end
Network:RegisterMethod("Game.NewPlayerRequest", NCallOn.Server, NMode.Reliable, "bsbbbb")
--============================================================================
-- [NET - SERVER & ALL CLIENTS]
function Game:OnNewPlayerInGame(clientID,entity,name,score,kills,deaths,pu_state,playtime,team,state,spectator,t1score,t2score)
    Game:Print("OnNewPlayerInGame: "..clientID)
    local player = nil

    if spectator == 0 then
        -- tworze obiekty logiczne tego gracza na serwerze oraz na kliencie, ktory bedzie nim sterowal
        if Game:IsServer() or clientID == NET.GetClientID() then
            player = Game:AddPlayer(nil,name,"player") -- na razie bez entity
            player:ResetStatus()
            player.ClientID = clientID
            player._died = true -- na dzien dobry
            player.Team = team
        end
        if clientID == NET.GetClientID() then -- to moj player
            GObjects:ToKill(Game._procSpec)
            Game._procSpec = nil
        end
    else
        if clientID == NET.GetClientID() then -- to moj player
            Game._procSpec = GObjects:Add(TempObjName(),Templates["PSpectatorControler.CProcess"]:New())
            Game._procSpec:Init()
            if Game._procStats  then -- kasuje okienko statystki
                GObjects:ToKill(Game._procStats)
                Game._procStats = nil
            end
        end
    end

    NET.SetSpectator(clientID,spectator)

    -- tworze statystyke dla nowego playera
    Game.PlayerStats[clientID] = {ClientID = clientID, Name = name, Score = score, Kills = kills, Deaths = deaths, Ping = 0, PacketLoss = 0, Team = team, State = state, Spectator = spectator}
    local ps = Game.PlayerStats[clientID]
    MPSTATS.Update(ps.ClientID,ps.Name, ps.Score, ps.Kills, ps.Deaths, ps.Ping, ps.PacketLoss, ps.Team, ps.State, ps.Spectator)
    ps._Entity = entity
    ps.Player = player
    ps._respawned = false
    MPSTATS.SetPlayerGameTime(ps.ClientID,playtime)
    ps._starttime = INP.GetTime()

    if spectator == 0 then

        -- dodaje proces animujacy postac gracza
        if Game.GMode ~= GModes.DedicatedServer then
            local p = GObjects:Add(TempObjName(),Templates["PPlayerAnimation.CProcess"]:New(nil,clientID))
            ps._animproc = p -- zapamietuje referencje do procesu animujacego playera
            ps._animproc._Entity = entity -- juz byl na serwerze
        end

        -- odblokowuje gra na wlasciwym kliencie
        if clientID == NET.GetClientID() then -- to moj player
            Player = player
            Player._Entity = entity
            --INP.Reinit(true)
            MOUSE.Lock(true)
            -- zaczynam w trybie statystyki
            local t = nil
            if MPGameRules[MPCfg.GameMode].StartState == GameStates.WarmUp then t = 2  end
            Game._procStats = GObjects:Add(TempObjName(),Templates["EndOfMatch.CProcess"]:New(t))
        else
            -- ten player aktualnie gra na serwerze, wiec musze go widziec
            ENTITY.PO_SetFriction(entity,0.7)
            ENTITY.EnableDraw(entity,true)
            --MDL.CreateShadowMap(entity,64)
            MDL.SetAnim(entity,"idle",true)
            MDL.SetMeshVisibility(entity,"rl",false)
            if IsBitFlag(pu_state,1) then -- new player
                local txt = string.gsub(TXT.Multiplayer.PlayerJoined, "$PLAYER", Game.PlayerStats[clientID].Name)
                CONSOLE.AddMessage(txt)
                SOUND.Play2D("multiplayer/newplayerjoinedserver")
            end
        end
        Game:BrightSkin(entity,true,team)

        Game._team1Score = t1score
        Game._team2Score = t2score
        MPSTATS.SetTeamsScore(t1score,t2score)
    end

    if IsBitFlag(pu_state,2) then RawCallMethod(Templates["Quad.CItem"].TakeFX, entity, 0) end
    if IsBitFlag(pu_state,4) then RawCallMethod(Templates["WeaponModifier.CItem"].TakeFX, entity, 0) end
    if IsBitFlag(pu_state,8) then RawCallMethod(Templates["Flag.CItem"].TakeFX, entity, 0) end

    Game:GameSpy_UpdatePlayers()
    Game:CheckWarmUpStatus()
end
Network:RegisterMethod("Game.OnNewPlayerInGame", NCallOn.ServerAndAllClients, NMode.Reliable, "besiuubfbbbii")
--============================================================================
function Game:ResetPlayer(clientID)

    local player = Game:FindPlayerByClientID(clientID)
    if player then
        player:FreeBlockedObjects()
        player:ResetStatusAfterDeath()
        if Game:IsServer() then ENTITY.Release(player._Entity) end
        player._Entity = nil
    end

    local ps = Game.PlayerStats[clientID]
    if ps then
        if ps._animproc then ps._animproc:Reset() end
        if ps._Entity then
            EntityToObject[ps._Entity] = nil
            ps._Entity = nil
        end
    end
end
Network:RegisterMethod("Game.ResetPlayer", NCallOn.ServerAndAllClients, NMode.Reliable, "b")
--============================================================================
-- [NET - SERVER & ALL CLIENTS]
function Game:SetTimeLimit(timelimit,timeout,counter)
    MPCfg.TimeLimit = timelimit
    Game._TimeLimitOut = timeout

    if MPCfg.TimeLimit > 0 then
        MPSTATS.SetTimeLeft(MPCfg.TimeLimit)
    else
        MPSTATS.SetTimeLeft(0)
    end

    Game._countTimer = counter
    Game._LastTime = INP.GetTime()
    --CONSOLE.AddMessage("[Game Limits:]   Frags: "..fraglimit.."  Time: "..timelimit)
end
Network:RegisterMethod("Game.SetTimeLimit", NCallOn.ServerAndAllClients, NMode.Reliable, "fff")
--============================================================================
-- [NET - SERVER & ALL CLIENTS]
function Game:OnPlayerLeaveGame(clientID)
    Game:Print("OnPlayerLeaveGame: "..clientID)

    -- kasuje rozlaczonego gracza na serwerze i na wlasciwym kliencie
    for i,o in Game.Players do
        if o.ClientID == clientID then
            if Game:IsServer() then ENTITY.Release(o._Entity) end
            GObjects:ToKill(o)
            table.remove(Game.Players,i)
            if o == Player then Player = nil end
            if o == Game._spectatorRecordingPlayer then Game._spectatorRecordingPlayer = nil end
            break
        end
    end

    -- kasuje ze statystyk
    local ps = Game.PlayerStats[clientID]
    if not ps then return end -- juz wyszedl

    local txt = string.gsub(TXT.Multiplayer.PlayerLeft, "$PLAYER", ps.Name)
    CONSOLE.AddMessage(txt)

    -- usuwam procesy zwiazane z tym graczem
    local pcs = GObjects:GetElementsWithFieldValue("_Class","CProcess*")
    for i,p in pcs do
        if p.ClientID == clientID then GObjects:ToKill(p) end
    end

    if ps._Entity then EntityToObject[ps._Entity] = nil end

    MPSTATS.RemovePlayer(clientID)

    Game.PlayerStats[clientID] = nil
    --(odpalic dzwiek,wyswietlic komunikat)
    SOUND.Play2D("hero/hero_gib3")
    Game:GameSpy_UpdatePlayers()
    Game:CheckWarmUpStatus()
end
Network:RegisterMethod("Game.OnPlayerLeaveGame", NCallOn.ServerAndAllClients, NMode.Reliable, "b")
--============================================================================
-- [ENGINE - SERVER ONLY]
function Game:PlayerKill(clientID)
	local player = Game:FindPlayerByClientID(clientID)
	if player then
        if player.LastSuicide < INP.GetTime() then
		    player:OnDamage(999999,nil,AttackTypes.ConsoleKill)
            player.LastSuicide = INP.GetTime() + 30
        else
            SendNetMethod(Game.ConsoleMessage,clientID,true,true,"You can only suicide once every 30 seconds")
        end
	end
end
Network:RegisterMethod("Game.PlayerKill", NCallOn.Server, NMode.Reliable, "b")
--============================================================================
-- [ENGINE - SERVER ONLY]
function Game:PlayerSpectatorRequest(clientID,spectator)

    if MPCfg.GameState == GameStates.Finished then return end

    local ps = Game.PlayerStats[clientID]
    if ps and ps.Spectator == spectator then return end

    local can = NET.CanConnectNewClient(spectator)

    if MPCfg.GameMode == "Last Man Standing" and (MPCfg.GameState == GameStates.Playing or MPCfg.GameState == GameStates.Finished) then
        can = true
    end

    if can then
        Game:AfterClientDisconnected(clientID)
        Game.PlayerSpectatorConfirmation(clientID,spectator)
    else
        SendNetMethod(Game.ConsoleMessage, clientID, true, true, "Server can't change client mode [spectator<->player]")
    end
end
Network:RegisterMethod("Game.PlayerSpectatorRequest", NCallOn.Server, NMode.Reliable, "bb")
--============================================================================
-- [ENGINE - CLIENT ONLY]
function Game:PlayerSpectatorConfirmation(spectator)
    Game.NewPlayerRequest(NET.GetClientID(),Cfg.PlayerName,Cfg.PlayerModel,Cfg.Team,0,spectator)
end
Network:RegisterMethod("Game.PlayerSpectatorConfirmation", NCallOn.SingleClient, NMode.Reliable, "b")
--============================================================================
-- [NET - SERVER ONLY]
function Game:PlayerRespawnRequest(clientID)

    if not (MPCfg.GameState == GameStates.Playing or MPCfg.GameState == GameStates.WarmUp) then return end

    local player = Game:FindPlayerByClientID(clientID)
    if player and not player._Entity then
        Game:Print("PlayerRespawnRequest: "..clientID)
        player._timeToRespawn = -1

        local exist,x,y,z,a,pt = player:FindFreeRespawnPoint(player._lastRespawnPoint)
        if not exist then return end
        player._lastRespawnPoint = pt

        -- za kazdym razem tworze nowe entity, poniewaz stare zostaje na levelu
        player._Entity = CreatePlayer(Game.PlayerStats[clientID].Model,true)
        ENTITY.SetSynchroString(player._Entity,"CPlayer") -- for ENTITY_CREATE callback
        ENTITY.EnableDeathZoneTest(player._Entity,true)
        ENTITY.PO_SetMovedByExplosions(player._Entity,true)
        ENTITY.EnableNetworkSynchronization(player._Entity,true,false,0,clientID,3)

        player:Respawn(x,y,z,a)
        -- respawn na serwerze

        -- informacja o respawnie do wszystkich klientow
        local weapon = 3
        if Cfg.StartupWeapon > 0 and Cfg.StartupWeapon <= 7 then
            weapon = Cfg.StartupWeapon
        end
        if MPCfg.GameMode == "Voosh" then weapon = Game.VooshCurWeapon end
        if MPCfg.GameMode == "People Can Fly" then weapon = 4 end
        Game.PlayerRespawnConfirmation(clientID,player._Entity,ENTITY.GetOrientation(player._Entity),weapon)

        -- telefrag ?
        player:CheckTeleFrag()

        -- send limits info & current time
        SendNetMethod(Game.SetTimeLimit,clientID, true, true,MPCfg.TimeLimit,Game._TimeLimitOut)
    end
end
Network:RegisterMethod("Game.PlayerRespawnRequest", NCallOn.Server, NMode.Reliable, "b")
--============================================================================
-- [NET - SERVER]
function Game:NewPlayerNameRequest(clientID,name)
    Game.NewPlayerNameConfirmation(clientID,name)
end
Network:RegisterMethod("Game.NewPlayerNameRequest", NCallOn.Server, NMode.Reliable, "bs")
--============================================================================
-- [NET - SERVER AND ALL CLIENTS]
function Game:NewPlayerNameConfirmation(clientID,name)
    local ps = Game.PlayerStats[clientID]
    if ps then
        CONSOLE.AddMessage(ps.Name.." is now "..name..".")
        ps.Name = name
        MPSTATS.Update(ps.ClientID,ps.Name, ps.Score, ps.Kills, ps.Deaths, ps.Ping, ps.PacketLoss, ps.Team, ps.State, ps.Spectator)
    end
end
Network:RegisterMethod("Game.NewPlayerNameConfirmation", NCallOn.ServerAndAllClients, NMode.Reliable, "bs")
--============================================================================
-- [NET - SERVER]
function Game:NewPlayerTeamRequest(clientID,team)
    if MPGameRules[MPCfg.GameMode].Teams then
        Game.NewPlayerTeamConfirmation(clientID,team)
        local ps = Game.PlayerStats[clientID]
        if MPCfg.GameState == GameStates.Playing and ps and ps.Spectator == 0 and ps.State == 1 then
            Game.ResetPlayer(clientID)
            Game.PlayerRespawnRequest(clientID)
        end
    end
end
Network:RegisterMethod("Game.NewPlayerTeamRequest", NCallOn.Server, NMode.Reliable, "bb")
--============================================================================
-- [NET - SERVER AND ALL CLIENTS]
function Game:NewPlayerTeamConfirmation(clientID,team)
    local ps = Game.PlayerStats[clientID]
    if ps then
        --if (MPCfg.GameState == GameStates.Playing and ps._respawned) or MPCfg.GameState == GameStates.Finished then
        --    CONSOLE.AddMessage("Cannot change team during the match!")
        --else
            local tname = "Blue"
            if team == 1 then tname = "Red" end
            CONSOLE.AddMessage(ps.Name.." is now in team: "..tname..".")
            ps.Team  = team
            if ps.Player then ps.Player.Team = team end
            ps.Score = 0
            ps.Kills = 0
            ps.Deaths = 0
            MPSTATS.Update(ps.ClientID,ps.Name, ps.Score, ps.Kills, ps.Deaths, ps.Ping, ps.PacketLoss, ps.Team, ps.State, ps.Spectator)
        --end
    end
    if Player and Player.ClientID == clientID then
        Cfg.Team = team
    end
    for i,o in Game.PlayerStats do
		Game:BrightSkin( o._Entity, MPCfg.AllowBrightskins, o.Team )
	end
    Game:CheckWarmUpStatus()
end
Network:RegisterMethod("Game.NewPlayerTeamConfirmation", NCallOn.ServerAndAllClients, NMode.Reliable, "bb")
--============================================================================
-- [NET - SERVER]
function Game:SetStateRequest(clientID, state)
    local ps = Game.PlayerStats[clientID]
    if ps and ps.Spectator == 1 then return end
    Game.SetStateConfirmation(clientID,state)
end
Network:RegisterMethod("Game.SetStateRequest", NCallOn.Server, NMode.Reliable, "bb")
--============================================================================
-- [NET - ALLCLIENTS CLIENT]
function Game:SetStateConfirmation(clientID, state)
    local ps = Game.PlayerStats[clientID]
    if ps then
        ps.State  = state
        if ps.State == 1 and (MPCfg.GameState == GameStates.WarmUp or MPCfg.GameState == GameStates.Counting) then
            CONSOLE.AddMessage(ps.Name.." is ready.")
        end
        if ps.State == 0 and (MPCfg.GameState == GameStates.WarmUp or MPCfg.GameState == GameStates.Counting) then
            CONSOLE.AddMessage(ps.Name.." is unready.")
        end
        if ps.State == 2 and (MPCfg.GameState == GameStates.Playing) then
            CONSOLE.AddMessage(ps.Name.." wants to break match.")
        end
        MPSTATS.Update(ps.ClientID,ps.Name, ps.Score, ps.Kills, ps.Deaths, ps.Ping, ps.PacketLoss, ps.Team, ps.State, ps.Spectator)
    end
    Game:CheckWarmUpStatus()
end
Network:RegisterMethod("Game.SetStateConfirmation", NCallOn.ServerAndAllClients, NMode.Reliable, "bb")
--============================================================================
function Game:CheckWarmUpStatus()

    if MPCfg.GameState == GameStates.Finished then return end

    local n = 0
    for i,o in Game.PlayerStats do
        if o.Spectator == 0 then
            n = n + 1
        end
    end

    local reds = 0
    local blues = 0
    local punready = 0
    local pbreak = 0
    for i,o in Game.PlayerStats do
        if o.Spectator == 0 then
            if o.State ~= 1 then
                if o.State == 0 then  punready = punready + 1 end
                if o.State == 2 then  pbreak = pbreak + 1 end
            end
            if o.Team == 1 then reds = reds + 1 end
            if o.Team == 0 then blues = blues + 1 end
        end
    end

    -- START
    if MPCfg.GameState == GameStates.WarmUp and pbreak == 0 and punready == 0 then
        if n > 1 then
            if not MPGameRules[Cfg.GameMode].Teams or (blues~=0 and reds~=0) then
                MPCfg.GameState = GameStates.Counting
                Game._countTimer = 4.99
                CONSOLE.AddMessage("Match begins in 5 seconds.")
            else
                CONSOLE.AddMessage("Waiting for other team.")
            end
        else
            CONSOLE.AddMessage("Waiting for other players.")
        end
    end

    -- BREAK WHEN COUNTING
    -- if MPCfg.GameState == GameStates.Counting and (pbreak > 0 or punready > 0) then
    --    MPCfg.GameState = GameStates.WarmUp
    -- end

    -- BREAK WHEN PLAYING
    if Game:IsServer() then
        if MPCfg.GameState == GameStates.Playing and
           (pbreak >= n/2 or (MPGameRules[Cfg.GameMode].Teams and Cfg.StopMatchOnTeamQuit and (blues==0 or reds==0)))
        then
            StringToDo = "Game.EndOfMatch()"
        end
    end
end
--============================================================================
-- [NET - SERVER]
function Game:StartVotingRequest(clientID,cmd,params)
	local allowed = false

	if (cmd == "kick" or cmd == "kickid") and Cfg.UserKick then
		allowed = true
	elseif (cmd == "bankick" or cmd == "bankickid") and Cfg.UserBankick then
		allowed = true
	elseif cmd == "maxplayers" and Cfg.UserMaxPlayers then
		allowed = true
	elseif cmd == "maxspectators" and Cfg.UserMaxSpectators then
		allowed = true
	elseif cmd == "powerupdrop" and Cfg.UserPowerupDrop then
		allowed = true
	elseif cmd == "powerups" and Cfg.UserPowerups then
		allowed = true
	elseif cmd == "weaponsstay" and Cfg.UserWeaponsStay then
		allowed = true
	elseif cmd == "teamdamage" and Cfg.UserTeamDamage then
		allowed = true
	elseif cmd == "allowbunnyhopping" and Cfg.UserAllowBunnyhopping then
		allowed = true
	elseif cmd == "allowbrightskins" and Cfg.UserAllowBrightskins then
		allowed = true
	elseif cmd == "allowforwardrj" and Cfg.UserAllowForwardRJ then
		allowed = true
	elseif cmd == "reloadmap" and Cfg.UserReloadMap then
		allowed = true
	elseif cmd == "gamemode" and Cfg.UserGameMode then
		allowed = true
	elseif cmd == "map" and Cfg.UserMapChange then
		allowed = true
	elseif cmd == "timelimit" and Cfg.UserTimeLimit then
		allowed = true
	elseif cmd == "fraglimit" and Cfg.UserFragLimit then
		allowed = true
	elseif cmd == "capturelimit" and Cfg.UserCaptureLimit then
		allowed = true
	elseif cmd == "lmslives" and Cfg.UserLMSLives then
		allowed = true
	elseif cmd == "weaponrespawntime" and Cfg.UserWeaponRespawnTime then
		allowed = true
	elseif cmd == "startupweapon" and Cfg.StartupWeapon then
		allowed = true
	end

	if allowed then
		Game.StartVotingConfirmation(clientID,cmd,params)
	else
		Game.ConsoleMessageAll( "Voting on "..cmd.." is disabled on this server" )
	end
end
Network:RegisterMethod("Game.StartVotingRequest", NCallOn.Server, NMode.Reliable, "bss")
--============================================================================
-- [NET - SERVER AND ALL CLIENTS]
function Game:StartVotingConfirmation(clientID,cmd,params)
	local ps = Game.PlayerStats[clientID]
	if ps and ps.Name then
		SOUND.Play2D("menu/menu/back-accept_alt",100,true)
		CONSOLE.AddMessage(ps.Name.." calls for voting - '"..cmd.." "..params.."'",R3D.RGB(200,200,200))
		ps._vote = 1
	end

	Game._voteTimeLeft = 60
	Game._voteCmd = cmd
	Game._voteParams = params

	Game:CheckVotingStatus()
end
Network:RegisterMethod("Game.StartVotingConfirmation", NCallOn.ServerAndAllClients, NMode.Reliable, "bss")
--============================================================================
-- [NET - SERVER]
function Game:PlayerVoteRequest(clientID,vote)
	Game.PlayerVoteConfirmation(clientID,vote)
end
Network:RegisterMethod("Game.PlayerVoteRequest", NCallOn.Server, NMode.Reliable, "bb")
--============================================================================
-- [NET - SERVER CLIENT]
function Game:PlayerVoteConfirmation(clientID,vote)
	local ps = Game.PlayerStats[clientID]
    if ps then
		ps._vote = vote
    end

	Game:CheckVotingStatus()
end
Network:RegisterMethod("Game.PlayerVoteConfirmation", NCallOn.ServerAndAllClients, NMode.Reliable, "bb")
--============================================================================
function Game:CheckVotingStatus()
	if Game._voteTimeLeft <= 0 and Game._voteCmd ~= "" then
		SOUND.Play2D("menu/menu/option-mark_map",100,true)
		CONSOLE.AddMessage( "Voting Timeout" )
		for i,o in Game.PlayerStats do
			if o._vote then o._vote = nil end
		end
		Game._voteTimeLeft = 0
		Game._voteCmd = ""
		Game._voteParams = ""
		return
	end

	local numPlayers = 0
	local yesVotes = 0
	local noVotes = 0
	for i,o in Game.PlayerStats do
		if o._vote and o.Spectator == 0 then
			if o._vote == 1 then
				yesVotes = yesVotes + 1
			elseif o._vote == 0 then
				noVotes = noVotes + 1
			end
		end
		if o.Spectator == 0 then
			numPlayers = numPlayers + 1
		end
	end

	if numPlayers < 1 then
		SOUND.Play2D("menu/menu/option-mark_map",100,true)
		CONSOLE.AddMessage( "Voting aborted. Not enough players." )
		for i,o in Game.PlayerStats do
			if o._vote then o._vote = nil end
		end
		Game._voteTimeLeft = 0
		Game._voteCmd = ""
		Game._voteParams = ""
	elseif yesVotes > numPlayers / 2 then
		SOUND.Play2D("menu/menu/back-accept_alt",100,true)
		CONSOLE.AddMessage( "Voting finished. More than half players voted 'YES' - "..yesVotes.."/"..numPlayers )
		if Game:IsServer() and Game._voteCmd ~= "" then
			Console:OnCommand("\\"..Game._voteCmd.." "..Game._voteParams)
		end

		for i,o in Game.PlayerStats do
			if o._vote then o._vote = nil end
		end
		Game._voteTimeLeft = 0
		Game._voteCmd = ""
		Game._voteParams = ""
	elseif noVotes >= numPlayers / 2 then
		SOUND.Play2D("menu/menu/option-mark_map",100,true)
		CONSOLE.AddMessage( "Voting finished. Less than half players voted 'YES' - "..noVotes.."/"..numPlayers )
		for i,o in Game.PlayerStats do
			if o._vote then o._vote = nil end
		end
		Game._voteTimeLeft = 0
		Game._voteCmd = ""
		Game._voteParams = ""
	else
		SOUND.Play2D("menu/menu/click_alt",100,true)
		CONSOLE.AddMessage("Current votes: YES - "..yesVotes..", NO - "..noVotes)
	end
end
--============================================================================
function Game:SetGameState(state)

    if MPCfg.GameState == state then return end
    MPCfg.GameState = state

    if MPCfg.GameState == GameStates.Playing then -- start playing
        Game._TimeLimitOut = 0
        Game._LastTime = INP.GetTime()
    end
end
Network:RegisterMethod("Game.SetGameState", NCallOn.ServerAndAllClients, NMode.Reliable, "b")
--============================================================================
-- [NET - ALLCLIENTS CLIENT]
function Game:PlayerRespawnConfirmation(clientID,newe,a,weapon)

    Game:Print("PlayerRespawnConfirmation")
    local player = Game:FindPlayerByClientID(clientID)
    local ps = Game.PlayerStats[clientID]

    -- update statystyk i procesu animujacego tego playera (nowe entity)
    if ps then
        ps._Entity = newe
        if ps._animproc then
            ps._animproc:Reset()
            ps._animproc._Entity = newe
        end
        ps._respawned = true
    end

    local myplayer = false

    if player then
        EntityToObject[newe] = player
        player._Entity = newe
        player:ResetStatus(weapon)
        ENTITY.PO_Enable(player._Entity,true)
        if Player == player then
            myplayer = true
            if Game._procStats  then -- kasuje okienko statystki
                GObjects:ToKill(Game._procStats)
                Game._procStats = nil
                Hud.Enabled = true
                MPSTATS.Hide()
            end
            -- ustawiam kamere pod katem z respawnu
            Game.CameraFromPlayer = true
            CAM.SetAng(-a / (math.pi/180) - 180, 0, 0)
        end
        if MPCfg.GameMode == "People Can Fly" then
            vx = math.sin(a)
            vz = math.cos(a)
            local x,y,z = ENTITY.GetPosition(newe)
            ENTITY.PO_Hit(newe,x,y,z,vx*625,625,vz*625)
        end
    end

    local x,y,z = ENTITY.GetPosition(newe)
    if myplayer then
        if Game.GMode == GModes.MultiplayerClient then
            collectgarbage(0)
        end
        ENTITY.EnableDraw(newe,false) -- siebie nie widze
        if ps and ps.Deaths == 0 then
            if math.random(0,1) == 1 then
                SOUND.Play2D("multiplayer/lucifer/Lucifer_fight")
            else
                SOUND.Play2D("multiplayer/lucifer/lucifer-comemychildren")
            end
        else
            SOUND.Play2D("specials/respawns/respawn_m"..math.random(1,6))
        end
        --INP.Reset()
    else
        ENTITY.PO_SetFriction(newe,0.7)
        ENTITY.EnableDraw(newe,true)
        --MDL.CreateShadowMap(newe,64)
        MDL.SetAnim(newe,"idle",true)
        -- respawn fx
        local x,y,z = ENTITY.GetPosition(newe)
        local fx,fy,fz = CAM.GetForwardVector()
        AddObject("FX_Spawn.CActor",0.6,Vector:New(x-fx/3,y,z-fz/3),Quaternion:New_FromNormalY(fx,0,fz),true)
        SOUND.Play3D("specials/respawns/respawn_m"..math.random(1,6),x,y,z,25,40)
        --
    end
    if ps then Game:BrightSkin(newe,true,ps.Team) end
    if not Game:IsServer() then ENTITY.RemoveRagdoll(newe) end
end
Network:RegisterMethod("Game.PlayerRespawnConfirmation", NCallOn.ServerAndAllClients, NMode.Reliable, "befb")
--============================================================================
function Game:BrightSkin(entity, enable, team)

    local teams = false
    if MPGameRules[MPCfg.GameMode] and MPGameRules[MPCfg.GameMode].Teams then teams = true end

    ENTITY.KillAllChildrenByName(entity,"teammateIcon")

    if entity and entity > 0 and not PMENU.Active() and teams and team == Cfg.Team and (not Player or entity ~= Player._Entity) then
        local ei = ENTITY.Create(ETypes.Billboard,"Script","teammateIcon")
        BILLBOARD.SetupCorona(ei,0.9,0,0,0,0,
        0.5,0,0,0,"hud/teammate",Color:New(255,255,255,255):Compose(),1,true)
        ENTITY.SetPosition(ei,0,2.7,0)
        WORLD.AddEntity(ei)
        ENTITY.RegisterChild(entity,ei)
    end

    if enable and MPCfg.AllowBrightskins then
        local color

        --if MPCfg.GameMode == "Capture The Flag" then
        --end

        if (teams and Cfg.Team == team and not Cfg.FixedColors) or (Cfg.FixedColors and teams and team == 0) or (not teams and Player and entity == Player._Entity) then
            color = Color:New(0,0,255)
            -- NEW BIT
            if(Cfg.BrightskinTeam == "White")then color = Color:New(255,255,255) end
            if(Cfg.BrightskinTeam == "Red")then color = Color:New(255,0,0) end
            if(Cfg.BrightskinTeam == "Blue")then color = Color:New(0,0,255) end
            if(Cfg.BrightskinTeam == "Green")then color = Color:New(0,255,0) end
            if(Cfg.BrightskinTeam == "Black")then color = Color:New(0,0,0) end
            if(Cfg.BrightskinTeam == "Cyan")then color = Color:New(0,255,255) end
            if(Cfg.BrightskinTeam == "Magenta")then color = Color:New(255,0,255) end
            if(Cfg.BrightskinTeam == "Yellow")then color = Color:New(255,255,0) end
            -- END OF NEW BIT
        else
            color = Color:New(255,0,0)
            -- NEW BIT
            if(Cfg.BrightskinEnemy == "White")then color = Color:New(255,255,255) end
            if(Cfg.BrightskinEnemy == "Red")then color = Color:New(255,0,0) end
            if(Cfg.BrightskinEnemy == "Blue")then color = Color:New(0,0,255) end
            if(Cfg.BrightskinEnemy == "Green")then color = Color:New(0,255,0) end
            if(Cfg.BrightskinEnemy == "Black")then color = Color:New(0,0,0) end
            if(Cfg.BrightskinEnemy == "Cyan")then color = Color:New(0,255,255) end
            if(Cfg.BrightskinEnemy == "Magenta")then color = Color:New(255,0,255) end
            if(Cfg.BrightskinEnemy == "Yellow")then color = Color:New(255,255,0) end
            -- END OF NEW BIT
        end
        MDL.SetMeshLighting(entity,"*",false,color.R,color.G,color.B)
        if not PMENU.Active() then
			MATERIAL.Replace("models/mp-model-fallenangel/mpplayer1texture1","models/mp-model-fallenangel/mpplayer1texture1_brightskin")
			MATERIAL.Replace("models/mp-model-fallenangel/mpplayer1texture2","models/mp-model-fallenangel/mpplayer1texture2_brightskin")
			MATERIAL.Replace("models/mp-model-fallenangel/mpplayer1texture3","models/mp-model-fallenangel/mpplayer1texture3_brightskin")
			MATERIAL.Replace("models/mp-model-demon/mp_player_2_tex_1","models/mp-model-demon/mp_player_2_tex_1_brightskin")
			MATERIAL.Replace("models/mp-model-demon/mp_player_2_tex_2","models/mp-model-demon/mp_player_2_tex_2_brightskin")
			MATERIAL.Replace("models/mp-model-beast/mpplayer5_texture_1","models/mp-model-beast/mpplayer5_texture_1_brightskin")
			MATERIAL.Replace("models/mp-model-beast/mpplayer5_texture_2","models/mp-model-beast/mpplayer5_texture_2_brightskin")
			MATERIAL.Replace("models/mp-model-painkiller/PAINPLAYER_texture1","models/mp-model-painkiller/PAINPLAYER_texture1_brightskin")
			MATERIAL.Replace("models/mp-model-painkiller/PAINPLAYER_texture2","models/mp-model-painkiller/PAINPLAYER_texture2_brightskin")
			MATERIAL.Replace("models/mp-model-painkiller/PAINPLAYER_texture3","models/mp-model-painkiller/PAINPLAYER_texture3_brightskin")
			MATERIAL.Replace("models/mp-model-knight/templar_tex_1","models/mp-model-knight/templar_tex_1_brightskin")
			MATERIAL.Replace("models/mp-model-knight/templar_tex_2","models/mp-model-knight/templar_tex_2_brightskin")
			MATERIAL.Replace("models/mp-model-knight/templar_tex_3","models/mp-model-knight/templar_tex_3_brightskin")
			MATERIAL.Replace("models/mp-model-player6/mpplayer6_texture1","models/mp-model-player6/mpplayer6_texture_brightskin")
			MATERIAL.Replace("models/mp-model-player7/labcomando_texture1","models/mp-model-player7/mpplayer7_texture_brightskin")
        end
    else
        MDL.SetMeshLighting(entity,"*",true)
		if teams then
			if Cfg.Team ~= team then
				MDL.SetTexture(entity,"mpplayer5_texture_1_add","mpplayer5_texture_1_red")
				MDL.SetTexture(entity,"mpplayer5_texture_2_add","mpplayer5_texture_2_red")
				MDL.SetTexture(entity,"mp_player_2_tex_1_add","mp_player_2_tex_1_red")
				MDL.SetTexture(entity,"mp_player_2_tex_2_add","mp_player_2_tex_2_red")
				MDL.SetTexture(entity,"mpplayer1texture2_add","mpplayer1texture2_red")
				MDL.SetTexture(entity,"mpplayer1texture3_add","mpplayer1texture3_red")
				MDL.SetTexture(entity,"templar_tex_2_add","templar_tex_2_red")
				MDL.SetTexture(entity,"templar_tex_3_add","templar_tex_3_red")
				MDL.SetTexture(entity,"painplayer_texture1_add","painplayer_texture1_red")
				MDL.SetTexture(entity,"painplayer_texture2_add","painplayer_texture2_red")
				MDL.SetTexture(entity,"painplayer_texture3_add","painplayer_texture3_red")
				MDL.SetTexture(entity,"mpplayer6_texture1_add","mpplayer6_texture1_red")
				MDL.SetTexture(entity,"labcomando_texture1_add","labcomando_texture1_red")
			else
				MDL.SetTexture(entity,"mpplayer5_texture_1_add","mpplayer5_texture_1_white")
				MDL.SetTexture(entity,"mpplayer5_texture_2_add","mpplayer5_texture_2_white")
				MDL.SetTexture(entity,"mp_player_2_tex_1_add","mp_player_2_tex_1_white")
				MDL.SetTexture(entity,"mp_player_2_tex_2_add","mp_player_2_tex_2_white")
				MDL.SetTexture(entity,"mpplayer1texture2_add","mpplayer1texture2_white")
				MDL.SetTexture(entity,"mpplayer1texture3_add","mpplayer1texture3_white")
				MDL.SetTexture(entity,"templar_tex_2_add","templar_tex_2_white")
				MDL.SetTexture(entity,"templar_tex_3_add","templar_tex_3_white")
				MDL.SetTexture(entity,"painplayer_texture1_add","painplayer_texture1_white")
				MDL.SetTexture(entity,"painplayer_texture2_add","painplayer_texture2_white")
				MDL.SetTexture(entity,"painplayer_texture3_add","painplayer_texture3_white")
				MDL.SetTexture(entity,"mpplayer6_texture1_add","mpplayer6_texture1_white")
				MDL.SetTexture(entity,"labcomando_texture1_add","labcomando_texture1_white")
			end
		end
        MATERIAL.Replace("models/mp-model-fallenangel/mpplayer1texture1","models/mp-model-fallenangel/mpplayer1texture1")
        MATERIAL.Replace("models/mp-model-fallenangel/mpplayer1texture2","models/mp-model-fallenangel/mpplayer1texture2")
        MATERIAL.Replace("models/mp-model-fallenangel/mpplayer1texture3","models/mp-model-fallenangel/mpplayer1texture3")
        MATERIAL.Replace("models/mp-model-demon/mp_player_2_tex_1","models/mp-model-demon/mp_player_2_tex_1")
        MATERIAL.Replace("models/mp-model-demon/mp_player_2_tex_2","models/mp-model-demon/mp_player_2_tex_2")
        MATERIAL.Replace("models/mp-model-beast/mpplayer5_texture_1","models/mp-model-beast/mpplayer5_texture_1")
        MATERIAL.Replace("models/mp-model-beast/mpplayer5_texture_2","models/mp-model-beast/mpplayer5_texture_2")
        MATERIAL.Replace("models/mp-model-painkiller/PAINPLAYER_texture1","models/mp-model-painkiller/PAINPLAYER_texture1")
        MATERIAL.Replace("models/mp-model-painkiller/PAINPLAYER_texture2","models/mp-model-painkiller/PAINPLAYER_texture2")
        MATERIAL.Replace("models/mp-model-painkiller/PAINPLAYER_texture3","models/mp-model-painkiller/PAINPLAYER_texture3")
        MATERIAL.Replace("models/mp-model-knight/templar_tex_1","models/mp-model-knight/templar_tex_1")
        MATERIAL.Replace("models/mp-model-knight/templar_tex_2","models/mp-model-knight/templar_tex_2")
        MATERIAL.Replace("models/mp-model-knight/templar_tex_3","models/mp-model-knight/templar_tex_3")
        MATERIAL.Replace("models/mp-model-player6/mpplayer6_texture1","models/mp-model-player6/mpplayer6_texture1")
        MATERIAL.Replace("models/mp-model-player7/labcomando_texture1","models/mp-model-player7/labcomando_texture1")
    end
end
--============================================================================
-- [NET - SERVER & ALL CLIENTS]
function Game:ReloadBrightskins()
	for i,o in Game.PlayerStats do
		Game:BrightSkin( o._Entity, MPCfg.AllowBrightskins, o.Team )
		if MPCfg.AllowBrightskins then
			CONSOLE.AddMessage("Brightskins enabled")
		else
			CONSOLE.AddMessage("Brightskins disabled")
		end
	end
end
Network:RegisterMethod("Game.ReloadBrightskins", NCallOn.ServerAndAllClients, NMode.Reliable, "")
--============================================================================
-- [NET - SERVER & ALL CLIENTS]
function Game:EnableBunnyhopping(enable)
	PHYSICS.SetGravity(Tweak.GlobalData.MPGravity)
	if enable then
        PHYSICS.SetBunnyHopAcceleration(Tweak.MultiPlayerMove.BunnyHopAcceleration)
        CONSOLE.AddMessage("Bunnyhopping enabled")
    else
        PHYSICS.SetBunnyHopAcceleration(0)
        CONSOLE.AddMessage("Bunnyhopping disabled")
    end
end
Network:RegisterMethod("Game.EnableBunnyhopping", NCallOn.ServerAndAllClients, NMode.Reliable, "B")
--============================================================================
-- [NET - SERVER & ALL CLIENTS]
function Game:PlayerPingInfo(cnt,...)
    local i = 1
    while arg[i] do
        local ps = Game.PlayerStats[arg[i]]
        if ps then
            ps.Ping = arg[i+1]
            ps.PacketLoss = arg[i+2]
            MPSTATS.Update(ps.ClientID,ps.Name, ps.Score, ps.Kills, ps.Deaths, ps.Ping, ps.PacketLoss, ps.Team, ps.State, ps.Spectator)
        end
        i = i + 3
    end
end
Network:RegisterMethod("Game.PlayerPingInfo", NCallOn.ServerAndAllClients, NMode.Unreliable, "xbbb")
--============================================================================
-- [NET - SERVER] --
function Game:SayToAll(clientID,txt,color)
    local ps = Game.PlayerStats[clientID]
    if not ps and not (clientID == ServerID and IsDedicatedServer()) then return end -- juz wyszedl

    --Slot Zero, 03-08-2006: Chat spam protection.
    local player = Game:FindPlayerByClientID(clientID)
    local timestamp = INP.GetTime()
    local spam = false

    if player.ChatMsgBlock > timestamp then
        local time = math.ceil(player.ChatMsgBlock - timestamp)
        local seconds = " seconds"
        if time == 1 then seconds = " second" end
        SendNetMethod(Game.ConsoleMessage,clientID,true,true,"You will be allowed to speak in "..time..seconds)
        return
    end

    player.ChatMsgCount = player.ChatMsgCount + 1
    player.ChatMsgBlock = 0

    if player.ChatMsgCount >= 5 then
        spam = true
    elseif player.ChatMsgCount >= 3 and (timestamp - player.ChatMsgTime) <= 1 then
        spam = true
    elseif player.ChatMsgCount >= 2 and string.len(txt) > 10 and (timestamp - player.ChatMsgTime) <= 0.75 then
        spam = true
    end

    if spam then
        player.ChatMsgBlock = timestamp + 15
        SendNetMethod(Game.ConsoleMessage,clientID,true,true,"** CHAT SPAM DETECTED -- YOU CANNOT SPEAK FOR 15 SECONDS **")
        return
    end

    player.ChatMsgTime = timestamp

    --Slot Zero, 02-27-2006: Ignore PK++ command.
    if (txt == "CMD:UPDATESTATSALL") then return end

    Game.ConsoleClientMessage(clientID,txt,color)
end
Network:RegisterMethod("Game.SayToAll", NCallOn.Server, NMode.Reliable, "bsi")
--============================================================================
function Game:SayToTeam(clientID,txt,color)
    local ps = Game.PlayerStats[clientID]
    if not ps or ps.Spectator == 1 then return end

    for i,o in Game.PlayerStats do
        if o.Team == ps.Team then
            if o.ClientID == ServerID then
                RawCallMethod(Game.ConsoleClientMessage,clientID,txt,color)
            else
                SendNetMethod(Game.ConsoleClientMessage, o.ClientID, true, true, clientID,txt,color)
            end
        end
    end
end
Network:RegisterMethod("Game.SayToTeam", NCallOn.Server, NMode.Reliable, "bsi")
--============================================================================
-- [NET - ALL CLIENTS] --
function Game:ConsoleClientMessage(clientID,txt,color)
    local ps = Game.PlayerStats[clientID]

    if clientID == ServerID and not ps then
        ps = {Name = "Dedicated Admin"}
    end

    if not ps then return end -- juz wyszedl

	if color == nil or color == 0 then
		CONSOLE.AddMessage(ps.Name .. ": "..txt,R3D.RGB(255,0,0))
	else
		CONSOLE.AddMessage(ps.Name .. ": "..txt,color)
	end
    SOUND.Play2D("menu/magicboard/wrong_place",100,true,true)
end
Network:RegisterMethod("Game.ConsoleClientMessage", NCallOn.ServerAndAllClients, NMode.Reliable, "bsi")
--============================================================================
-- [NET - ALL CLIENTS] --
function Game:ConsoleMessage(txt)
    CONSOLE.AddMessage(txt,R3D.RGB(255,0,0))
    SOUND.Play2D("menu/magicboard/wrong_place",100,true,true)
end
Network:RegisterMethod("Game.ConsoleMessage", NCallOn.ServerAndAllClients, NMode.Reliable, "s")
--============================================================================
function Game:LoadNextMap()

    local maps =  PainMenu.mapsOnServer
    if maps and table.getn(maps) > 0 then
        for i=1,table.getn(maps) do
            --MsgBox("+"..maps[i].."+")
            if string.upper(maps[i]) == string.upper(Lev._Name) then
                if maps[i+1]  then
                    --MsgBox("Laduje:"..maps[i+1])
                    NET.LoadMapOnServer(maps[i+1])
                else
                    --MsgBox("Laduje:"..maps[1])
                    NET.LoadMapOnServer(maps[1])
                end
                return
            end
        end
        -- jezeli byla mapa spoza kolejki to wraca do pierwszej
        NET.LoadMapOnServer(maps[1])
        return
    end

    NET.LoadMapOnServer(Lev._Name)
end
--============================================================================
-- [ NET - SERVER & ALL CLIENTS ]
function Game:EndOfMatch()

    MPCfg.GameState = GameStates.Finished

    GObjects:ToKill(Game._procSpec)
    Game._procSpec = nil

    Log("EndOfMatch - 1\n")
    if Game._procStats then GObjects:ToKill(Game._procStats) end

    Log("EndOfMatch - 1.5\n")
    MPSTATS.SetTimeLeft("00:00")

    Log("EndOfMatch - 2\n")

    for i,o in Game.Players do
        if not o._died then
            o._died = true
            o:ResetStatusAfterDeath()
            Log("SetTimeToDie 1\n")
            if Game:IsServer() then  ENTITY.SetTimeToDie(o._Entity,5) end
            --if Game:IsServer() then  ENTITY.Release(o._Entity) end
            Log("SetTimeToDie 2\n")
            o._Entity = nil
        end
    end

    Log("EndOfMatch - 3\n")
    for i,o in Game.PlayerStats do
        if MPCfg.GameMode == "Last Man Standing" then
            NET.SetSpectator(i,0)
        end
        Log("4")
        ENTITY.SetVelocity(o._Entity,0,0,0)
        ENTITY.PO_Enable(o._Entity,false)
        MDL.SetAnim(o._Entity,"idle",true)
        ENTITY.EnableDraw(o._Entity,true)
        if o._animproc then o._animproc:Reset() end
        ENTITY.KillAllChildren(o._Entity)
        if o._Entity then
			Log(" E \n")
			EntityToObject[o._Entity] = nil
		end
        o._Entity = nil
    end
    Log("EndOfMatch - 4\n")

    Game._procStats = GObjects:Add(TempObjName(),Templates["EndOfMatch.CProcess"]:New(1))

    Log("EndOfMatch - 5\n")

end
Network:RegisterMethod("Game.EndOfMatch", NCallOn.ServerAndAllClients, NMode.Reliable, "")
--============================================================================
-- [ NET - ALL CLIENTS ]
function Game:SetConfiguration(brightskins,gamemode,fraglimit,capturelimit, lmslives,teamdamage,lockconsole)
    MPCfg.AllowBrightskins = brightskins
    MPCfg.TeamDamage = teamdamage
    MPCfg.FragLimit = fraglimit
    MPCfg.GameMode = gamemode
    MPCfg.CaptureLimit = capturelimit
    MPCfg.LMSLives = lmslives
    MPCfg.ClientConsoleLockdown = lockconsole

    MPSTATS.SetFragLimit(MPCfg.FragLimit)
    MPSTATS.SetCaptureLimit(MPCfg.CaptureLimit)
    MPSTATS.SetLMSLives(MPCfg.LMSLives)

    CONSOLE.AddMessage(gamemode)
end
Network:RegisterMethod("Game.SetConfiguration", NCallOn.ServerAndAllClients, NMode.Reliable, "BsfffBB")
--============================================================================
-- [ NET - SERVER & ALL CLIENTS ]
function Game:ConsoleMessageAll(msg)
	CONSOLE.AddMessage(msg)
end
Network:RegisterMethod("Game.ConsoleMessageAll", NCallOn.ServerAndAllClients, NMode.Reliable, "s")
--============================================================================
-- [ NET - SERVER ]
function Game:ServerInfoRequest(clientID)
	local ded = false
	if Game.GMode == GModes.DedicatedServer then ded = true end
	local fps = "Not limited"
	if Cfg.LimitServerFPS then fps = ""..Cfg.ServerFPS end
	Game.ServerInfoConfirmation(clientID,Cfg.ServerName,ded,Lev._Name,MPCfg.GameMode,fps)
end
Network:RegisterMethod("Game.ServerInfoRequest", NCallOn.Server, NMode.Reliable, "b")
--============================================================================
-- [ NET - SINGLE CLIENT ]
function Game:ServerInfoConfirmation(name,isDedicated,map,mode,fps)
	CONSOLE.AddMessage("Server: "..name)
	local type = "Listen"
	if isDedicated then type = "Dedicated" end
	CONSOLE.AddMessage( "Type: "..type )
	CONSOLE.AddMessage( "Map: "..map )
	CONSOLE.AddMessage( "Mode: "..mode )
	CONSOLE.AddMessage( "FPS: "..fps )
end
Network:RegisterMethod("Game.ServerInfoConfirmation", NCallOn.SingleClient, NMode.Reliable, "sBsss")
--============================================================================
function Game:FindPlayerStatsByEntity(entity)
    for i,o in Game.PlayerStats do
        if o._Entity == entity then return o end
    end
    return nil
end
--============================================================================
function Game:FindPlayerByClientID(clientID)
    for i,o in Game.Players do
        if o.ClientID == clientID then return o end
    end
    return nil
end
--============================================================================
function Game:GameSpy_UpdatePlayers()
    if not Game:IsServer() then return end
    local i=0
    GAMESPY.RemoveAllPlayers()
    for id,ps in Game.PlayerStats do
		if ps.Spectator == 0 then
			GAMESPY.SetPlayerInfo(i,ps.Name, ps.Score, ps.Ping, ps.Deaths, ps.Team)
			i = i + 1
		end
    end
end
--============================================================================
function GetPlayerEntityByClient(clientID)
    local ps = Game.PlayerStats[clientID]
    if ps and ps._Entity then
        --Log("*GetPlayerEntityByClient = "..ps._Entity.." \n")
        return ps._Entity
    end
    --Log("*GetPlayerEntityByClient = 0 \n")
    return 0
end
--============================================================================
function Game_BackupServerSettings()
	MPCfgBackup.MaxPlayers = Cfg.MaxPlayers
	MPCfgBackup.MaxSpectators = Cfg.MaxSpectators
	MPCfgBackup.FragLimit = Cfg.FragLimit
	MPCfgBackup.TimeLimit = Cfg.TimeLimit
	MPCfgBackup.CaptureLimit = Cfg.CaptureLimit
	MPCfgBackup.LMSLives = Cfg.LMSLives
	MPCfgBackup.GameMode = Cfg.GameMode
	MPCfgBackup.Powerups = Cfg.Powerups
	MPCfgBackup.PowerupDrop = Cfg.PowerupDrop
	MPCfgBackup.WeaponsStay = Cfg.WeaponsStay
	MPCfgBackup.WeaponRespawnTime = Cfg.WeaponRespawnTime
	MPCfgBackup.TeamDamage = Cfg.TeamDamage
	MPCfgBackup.AllowBrightskins = Cfg.AllowBrightskins
	MPCfgBackup.AllowBunnyhopping = Cfg.AllowBunnyhopping
	MPCfgBackup.AllowForwardRJ = Cfg.AllowForwardRJ
	MPCfgBackup.StartupWeapon = Cfg.StartupWeapon
	MPCfgBackup.Map = Cfg.ServerMaps[1]
end
--============================================================================
function Game_RestoreServerSettings()
	Console:Cmd_FRAGLIMIT( MPCfgBackup.FragLimit )
	Console:Cmd_TIMELIMIT( MPCfgBackup.TimeLimit )
	Console:Cmd_CAPTURELIMIT( MPCfgBackup.CaptureLimit )
	Console:Cmd_MAXPLAYERS( MPCfgBackup.MaxPlayers )
	Console:Cmd_MAXSPECTATORS( MPCfgBackup.MaxSpectators )
	Console:Cmd_POWERUPS( MPCfgBackup.Powerups )
	Console:Cmd_POWERUPDROP( MPCfgBackup.PowerupDrop )
	Console:Cmd_WEAPONSSTAY( MPCfgBackup.WeaponsStay )
	Console:Cmd_WEAPONRESPAWNTIME( MPCfgBackup.WeaponRespawnTime )
	Console:Cmd_TEAMDAMAGE( MPCfgBackup.TeamDamage )
	Console:Cmd_ALLOWBRIGHTSKINS( MPCfgBackup.AllowBrightskins )
	Console:Cmd_ALLOWBUNNYHOPPING( MPCfgBackup.AllowBunnyhopping )
	Console:Cmd_ALLOWFORWARDRJ( MPCfgBackup.AllowForwardRJ )
	Console:Cmd_STARTUPWEAPON( MPCfgBackup.StartupWeapon )
	if MPCfg.GameMode ~= MPCfgBackup.GameMode then
		Console:Cmd_GAMEMODE( MPCfgBackup.GameMode )
	end
	if Lev._Name ~= MPCfgBackup.Map then
		Console:Cmd_MAP(MPCfgBackup.Map)
	end
end
--============================================================================
