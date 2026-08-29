--[[
	WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
]]
-- This script uses SynSaveInstance to save a Roblox game or specific parts to your computer.
-- It's great for backing up places, models, or scripts. This code is written to be easy for beginners!

-- Load the SynSaveInstance script from its online source (GitHub)
-- This grabs the latest code from the internet and runs it
local saveScript = loadstring(game:HttpGet("https://raw.githubusercontent.com/luau/SynSaveInstance/main/saveinstance.luau", true), "saveinstance")()

-- Create a configuration table to customize how the game is saved
-- You can change these settings to control what gets saved and how
local SaveConfig = {
    -- Debug settings
    __DEBUG_MODE = false, -- Set to true to see extra messages in the console about any issues during saving (helps find bugs)
    
    -- File output settings
    ReadMe = true, -- Creates a README file with info about what was saved
    FilePath = false, -- Custom file name (no extension, like ".rbxl"). Leave as false for default name
    AlternativeWritefile = true, -- Writes file in smaller chunks to avoid crashes (might not work on all executors)
    
    -- Safety and performance
    SafeMode = false, -- Kicks you from the game before saving to avoid anti-cheat detection
    ShutdownWhenDone = false, -- Closes Roblox after saving is done
    AntiIdle = true, -- Prevents Roblox from kicking you for being idle (AFK) during long saves
    
    -- Privacy
    Anonymous = false, -- RISKY: Removes your username/UserID from the file to hide identity (can mess up unrelated strings/numbers)
    -- Example for Anonymous as table: {UserId = "123456", Name = "PlayerName"} to specify custom values to remove
    
    -- Progress display
    ShowStatus = true, -- Shows a progress bar or updates while saving
    
    -- Advanced output control
    Callback = false, -- Set a function to receive saved data instead of writing to a file (advanced)
    mode = "optimized", -- Save mode: "full" (everything), "optimized" (smaller file), "scripts" (only scripts), or "invalid" (only ExtraInstances)
    
    -- Script handling
    noscripts = false, -- Skips saving scripts (alias: Decompile)
    scriptcache = true, -- Uses pre-decompiled scripts if available
    decomptype = "", -- DEPRECATED: Don't use; relies on your executor's decompiler
    timeout = 10, -- Seconds to allow for decompiling each script (-1 for no limit, but unreliable; alias: DecompileTimeout)
    DecompileJobless = false, -- Only uses already decompiled scripts, doesn't decompile new ones
    SaveBytecode = false, -- Saves raw script bytecode for later decompiling
    
    -- Ignoring specific items
    DecompileIgnore = {TextChatService = true}, -- Ignores specific instances/classes when decompiling scripts
    -- Example: {"Chat"} ignores Chat class; {Players = {"MyName"}} ignores specific player; [workspace] = false ignores only workspace
    IgnoreList = {CoreGui = true, CorePackages = true}, -- Ignores instances/classes when saving (includes descendants by default)
    IgnoreProperties = {}, -- List of property names to ignore (e.g., {"Transparency"})
    IgnoreDefaultProperties = true, -- Skips properties at default values to reduce file size (alias: IgnoreDefaultProps)
    IgnoreNotArchivable = true, -- Saves non-archivable instances (alias: IgnoreArchivable)
    IgnorePropertiesOfNotScriptsOnScriptsMode = false, -- In "scripts" mode, skips properties of non-script instances
    IgnoreSpecialProperties = false, -- Avoids special property getters to prevent crashes (use if files corrupt)
    
    -- Specific instance handling
    Object = false, -- Instance to save (e.g., game.Workspace). Saves as .rbxmx (model) or .rbxl if game. Must be a real reference
    IsModel = false, -- Forces model file (.rbxmx) if Object is set (auto-true unless you set false)
    ExtraInstances = {}, -- List of specific instances to save (used with invalid mode)
    NilInstances = false, -- Saves instances with no parent (parented to nil)
    NilInstancesFixes = {Animator = function() end, AdPortal = function() end, BaseWrap = function() end, Attachment = function() end}, -- Fixes for nil-parented classes (set to false to skip fix for a class)
    
    -- Player-related settings
    IsolateLocalPlayer = false, -- Saves your player's stuff in a separate folder, skips others with your name
    IsolateStarterPlayer = false, -- Clears StarterPlayer and saves its contents in folders
    IsolateLocalPlayerCharacter = false, -- Saves your character's stuff in a separate folder, skips others with your name
    RemovePlayerCharacters = true, -- Skips all player characters (enables SaveNotCreatable; alias: inverse SavePlayerCharacters)
    IsolatePlayers = false, -- Saves players but hides them in Studio (view in text editor; alias: SavePlayers)
    IgnoreDefaultPlayerScripts = true, -- RISKY: Skips default scripts like PlayerModule to avoid crashes
    
    -- Special cases and fixes
    SaveNotCreatable = false, -- Saves non-creatable instances as folders (alias: SaveNonCreatable)
    NotCreatableFixes = {"", "Player", "PlayerScripts", "PlayerGui", "TouchTransmitter"}, -- Defines fixes for non-creatable classes (e.g., Player = "Folder")
    IgnoreSharedStrings = true, -- RISKY: Skips shared strings to fix crashes (test disabling if issues)
    SharedStringOverwrite = false, -- RISKY: Overwrites shared strings for smaller files (can break if saving crashes)
    TreatUnionsAsParts = false, -- RISKY: Converts UnionOperations to Parts for visibility if your executor can't handle unions (true on Solara)
    
    -- Performance
    SaveCacheInterval = 0x1600 * 10, -- How often to save progress (lower = more frequent, slower performance)
}

saveScript(SaveConfig)