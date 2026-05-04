-- Trainfitter — sh_trainfitter.lua
-- Made by SellingVika.

Trainfitter         = Trainfitter or {}
Trainfitter.Version = "2.3.0"

if SERVER then
    AddCSLuaFile("trainfitter/sh_integrity.lua")
    AddCSLuaFile("trainfitter/sh_config.lua")
    AddCSLuaFile("trainfitter/sh_lang.lua")
    AddCSLuaFile("trainfitter/sh_gma_scan.lua")
    AddCSLuaFile("trainfitter/sh_banner.lua")
    AddCSLuaFile("autorun/client/cl_trainfitter.lua")
    AddCSLuaFile("autorun/client/cl_trainfitter_desktop.lua")
    AddCSLuaFile("autorun/client/cl_trainfitter_menu.lua")
    AddCSLuaFile("autorun/client/cl_trainfitter_browser.lua")
end

include("trainfitter/sh_integrity.lua")
include("trainfitter/sh_config.lua")
include("trainfitter/sh_lang.lua")
include("trainfitter/sh_gma_scan.lua")
include("trainfitter/sh_banner.lua")
