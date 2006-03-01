--============================================================================
function IDriverElectro:OnPrecache()
    Cache:PrecacheActor("DriverElectro.CWeapon")
end
--============================================================================
function IDriverElectro:OnInitTemplate()
    self._Synchronize = self.Synchronize
    self.Synchronize = nil
end
--============================================================================
function IDriverElectro:OnCreateEntity()
    ENTITY.EnableNetworkSynchronization(self._Entity,true,true)

    local param  = "e"
    if self.Ammo.Shurikens > self.Ammo.Electro then param = "s" end
    ENTITY.SetSynchroString(self._Entity,"IDriverElectro.CItem"..":"..param)

    self:AddTimer("GetWeaponUp", 0.1)
    self:Client_OnCreateEntity(self._Entity,param)
end
--============================================================================
function IDriverElectro:Client_OnCreateEntity(entity,param)
    local e = ENTITY.Create(ETypes.Billboard,"Script","IDriverElectro")
    local tex = "HUD/weapons/ikona_electro"
    if param == "s" then
        tex = "HUD/weapons/ikona_szuriken"
    end
    BILLBOARD.SetupCorona(e,1,0,0,0,0,0.25,0,0,0,tex,Color:New(255,255,255,0):Compose(),4,true)
    ENTITY.SetPosition(e,0,-0.7,0)
    ENTITY.RegisterChild(entity,e,true,0)
    WORLD.AddEntity(e)
end
--============================================================================
--Slot Zero, 02-21-2006: Charge up weapon.
function IDriverElectro:OnTake(player)
    if Game.GMode == GModes.SingleGame then
        self.TakeFX(player._Entity,self.Ammo.Shurikens,self.Ammo.Electro)
    else
        if not (Cfg.WeaponsStay and player.EnabledWeapons[self.SlotIndex] and not self.WeaponUp) then
            if self.Ammo.Shurikens > 0 and player.Ammo.Shurikens < CPlayer.s_SubClass.MPMaxAmmo.Shurikens or
                    self.Ammo.Electro > 0 and player.Ammo.Electro < CPlayer.s_SubClass.MPMaxAmmo.Electro or
                    not player.EnabledWeapons[self.SlotIndex] then
                self.TakeFX(player._Entity,self.Ammo.Shurikens,self.Ammo.Electro)
                maybe_offset_weapon_down(self)
            end
        end
        if Cfg.WeaponsStay then return true end
    end
end
--============================================================================
--Slot Zero, 02-21-2006: Charge up weapon.
function IDriverElectro:GetWeaponUp()
    get_weapon_up(self)
end
--============================================================================
--function IDriverElectro:OnRespawn()
--    local x,y,z = ENTITY.GetPosition(self._Entity)
--    AddObject("FX_ItemRespawn.CActor",1,Vector:New(x,y,z),nil,true)
--end
--============================================================================
function IDriverElectro:TakeFX(pe,aShurikens,aElectro)
    local player = EntityToObject[pe]
    local t = Templates["IDriverElectro.CItem"]
    if player then
        player.EnabledWeapons[t.SlotIndex] = "DriverElectro"
        player.Ammo.Shurikens = player.Ammo.Shurikens + aShurikens
        player.Ammo.Electro = player.Ammo.Electro + aElectro
        player:CheckMaxAmmo()
        if player == Player then
            player:Client_OnTakeWeapon(t.SlotIndex)
            player:PickupFX()
        end
    end

    t:SndEnt("pickup",pe)
end
Network:RegisterMethod("IDriverElectro.TakeFX", NCallOn.ServerAndAllClients, NMode.Reliable, "euu")
--============================================================================
