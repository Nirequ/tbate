-- Client initialization script
--
-- The Lua-side UI builders (SlotSelectionUI / CharacterEditorUI) have
-- been removed; the player-facing UI is now expected to live in
-- StarterGui as hand-built ScreenGuis (Studio UI Editor). This file
-- only initialises the data-layer controller so the rest of the code
-- on the client can still talk to the server.
--
-- Helpers that don't build UI but might be useful when wiring the
-- hand-built UI to the game state remain available:
--
--   require(script.controllers.CharacterController)
--     thin wrapper around the slot-management RemoteFunctions
--     (GetCharacterSlots / CreateCharacter / LoadCharacter /
--     UnlockSlot / TeleportToMainGame / ResetCharacterSlots).
--
--   require(script.controllers.CharacterEditorUI.HumanoidBuilder)
--     pure helpers for turning a selection table into a
--     HumanoidDescription and for spawning an R6 rig coloured to it.
--
--   require(script.controllers.CharacterEditorUI.PreviewSpawn)
--     resolves the Workspace.PreviewSpot anchor and stands a rig on
--     top of it without it sinking through the floor or floating.
--
--   require(script.controllers.CharacterEditorUI.OrbitCamera)
--     mouse-drag orbit + scroll-zoom around a preview character.
--
-- These can be required directly from LocalScripts attached to the
-- hand-built UI; nothing in this init.client.lua needs to drive them.

print("=== TBATE RPG Client Starting ===")

local Players = game:GetService("Players")

local player = Players.LocalPlayer
player:WaitForChild("PlayerGui")

local CharacterController = require(script.controllers.CharacterController)
CharacterController.Init()

print("=== TBATE RPG Client Ready ===")
