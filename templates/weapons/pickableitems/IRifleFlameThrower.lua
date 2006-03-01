--============================================================================
function IRifleFlameThrower:OnPrecache()
    Cache:PrecacheActor("RifleFlameThrower.CWeapon")
end
--============================================================================
function IRifleFlameThrower:OnInitTemplate()
    self._Synchronize = self.Synchronize
    self.Synchronize = nil
end
--============================================================================
function IRifleFlameThrower:OnCreateEntity()
    ENTITY.EnableNetworkSynchronization(self._Entity,true,true)

    local param  = "r"
    if self.Ammo.FlameThrower > self.Ammo.Rifle then param = "f" end
    ENTITY.SetSynchroString(self._Entity,"IRifleFlameThrower.CItem"..":"..param)

    self:AddTimer("GetWeaponUp", 0.1)
    self:Client_OnCreateEntity(self._Entity,param)
end
--============================================================================
function IRifleFlameThrower:Client_OnCreateEntity(entity,param)
    local e = ENTITY.Create(ETypes.Billboard,"Script","IRifleFlameThrower")

    local tex = "HUD/weapons/ikona_szuriken"
    if param == "f" then
        tex = "HUD/weapons/ikona_electro"
    end
    BILLBOARD.SetupCorona(e,1,0,0,0,0,0.25,0,0,0,tex,Color:New(255,255,255,0):Compose(),4,true)
    ENTITY.SetPosition(e,0,-0.7,0)
    ENTITY.RegisterChild(entity,e,true,0)
    WORLD.AddEntity(e)
end
--============================================================================
--Slot Zero, 02-21-2006: Charge up weapon.
function IRifleFlameThrower:OnTake(player)
    if Game.GMode == GModes.SingleGame then
        self.TakeFX(player._Entity,self.Ammo.Rifle,self.Ammo.FlameThrower)
    else
        if not (Cfg.WeaponsStay and player.EnabledWeapons[self.SlotIndex] and not self.WeaponUp) then
            if self.Ammo.Rifle > 0 and player.Ammo.Rifle < CPlayer.s_SubClass.MPMaxAmmo.Rifle or
                    self.Ammo.FlameThrower > 0 and player.Ammo.FlameThrower < CPlayer.s_SubClass.MPMaxAmmo.FlameThrower or
                    not player.EnabledWeapons[self.SlotIndex] then
                self.TakeFX(player._Entity,self.Ammo.Rifle,self.Ammo.FlameThrower)
                maybe_offset_weapon_down(self)
            end
        end
        if Cfg.WeaponsStay then return true end
    end
end
--============================================================================
--Slot Zero, 02-21-2006: Charge up weapon.
function IRifleFlameThrower:GetWeaponUp()
    get_weapon_up(self)
end
--============================================================================
--function IRifleFlameThrower:OnRespawn()
--    local x,y,z = ENTITY.GetPosition(self._Entity)
--    AddObject("FX_ItemRespawn.CActor",1,Vector:New(x,y,z),nil,true)
--end
--============================================================================
function IRifleFlameThrower:TakeFX(pe,aRifle,aFlameThrower)
    local player = EntityToObject[pe]
    local t = Templates["IRifleFlameThrower.CItem"]
    if player then
        player.EnabledWeapons[t.SlotIndex] = "RifleFlameThrower"
        player.Ammo.Rifle = player.Ammo.Rifle + aRifle
        player.Ammo.FlameThrower = player.Ammo.FlameThrower + aFlameThrower
        player:CheckMaxAmmo()
        if player == Player then
            player:Client_OnTakeWeapon(t.SlotIndex)
            player:PickupFX()
        end
    end

    t:SndEnt("pickup",pe)
end
Network:RegisterMethod("IRifleFlameThrower.TakeFX", NCallOn.ServerAndAllClients, NMode.Reliable, "euu")
--============================================================================
