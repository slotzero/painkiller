--============================================================================
function IStakeGunGL:OnPrecache()
    Cache:PrecacheActor("StakeGunGL.CWeapon")
end
--============================================================================
function IStakeGunGL:OnInitTemplate()
    self._Synchronize = self.Synchronize
    self.Synchronize = nil
end
--============================================================================
function IStakeGunGL:OnCreateEntity()
    ENTITY.EnableNetworkSynchronization(self._Entity,true,true)
    --MDL.CreateShadowMap(self._Entity,64)

    local param  = "r"
    if self.Ammo.Stakes > self.Ammo.Grenades then param = "k" end
    ENTITY.SetSynchroString(self._Entity,"IStakeGunGL.CItem"..":"..param)

    self:AddTimer("GetWeaponUp", 0.1)
    self:Client_OnCreateEntity(self._Entity,param)
end
--============================================================================
function IStakeGunGL:Client_OnCreateEntity(entity,param)
    local e = ENTITY.Create(ETypes.Billboard,"Script","IStakeGunGL")
    local tex = "HUD/weapons/ikona_granat_rakieta"
    if param == "k" then
        tex = "HUD/weapons/ikona_kolki"
    end
    BILLBOARD.SetupCorona(e,1,0,0,0,0,0.25,0,0,0,tex,Color:New(255,255,255,0):Compose(),4,true)
    ENTITY.SetPosition(e,0,-0.7,0)
    ENTITY.RegisterChild(entity,e,true,0)
    WORLD.AddEntity(e)
end
--============================================================================
--function IStakeGunGL:OnRespawn()
--    local x,y,z = ENTITY.GetPosition(self._Entity)
--    AddObject("FX_ItemRespawn.CActor",1,Vector:New(x,y,z),nil,true)
--end
--============================================================================
--Slot Zero, 02-21-2006: Charge up weapon.
function IStakeGunGL:OnTake(player)
    if Game.GMode == GModes.SingleGame then
        self.TakeFX(player._Entity, self.Ammo.Stakes, self.Ammo.Grenades)
    else
        if not (Cfg.WeaponsStay and player.EnabledWeapons[self.SlotIndex] and not self.WeaponUp) then
            if self.Ammo.Stakes > 0 and player.Ammo.Stakes < CPlayer.s_SubClass.MPMaxAmmo.Stakes or
                    self.Ammo.Grenades > 0 and player.Ammo.Grenades < CPlayer.s_SubClass.MPMaxAmmo.Grenades or
                    not player.EnabledWeapons[self.SlotIndex] then
                self.TakeFX(player._Entity, self.Ammo.Stakes, self.Ammo.Grenades)
                maybe_offset_weapon_down(self)
            end
        end
        if Cfg.WeaponsStay then return true end
    end
end
--============================================================================
--Slot Zero, 02-21-2006: Charge up weapon.
function IStakeGunGL:GetWeaponUp()
    get_weapon_up(self)
end
--============================================================================
function IStakeGunGL:TakeFX(pe,aStakes,aGrenades)
    local player = EntityToObject[pe]
    local t = Templates["IStakeGunGL.CItem"]
    if player then
        player.EnabledWeapons[t.SlotIndex] = "StakeGunGL"
        player.Ammo.Stakes = player.Ammo.Stakes + aStakes
        player.Ammo.Grenades = player.Ammo.Grenades + aGrenades
        player:CheckMaxAmmo()
        if player == Player then
            player:Client_OnTakeWeapon(t.SlotIndex)
            player:PickupFX()
        end
    end

    t:SndEnt("pickup",pe)
end
Network:RegisterMethod("IStakeGunGL.TakeFX", NCallOn.ServerAndAllClients, NMode.Reliable, "euu")
--============================================================================
