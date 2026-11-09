-- microboss init.lua
--
-- Micro 2.0.13 has no built-in soft-wrap toggle action, so Alt+Z calls this
-- helper through the binding "lua:initlua.toggle_softwrap" in bindings.json.
--
-- The vendored filemanager plugin focuses its new tree pane when it opens. The
-- wrapper below restores focus to the editor and is installed as the `tree`
-- command after every plugin's init() has run.

local micro = import("micro")
local config = import("micro/config")
local os = import("os")

function toggle_softwrap(bp)
    local enabled = bp.Buf.Settings["softwrap"]
    bp.Buf.Settings["softwrap"] = not enabled
    if enabled then
        micro.InfoBar():Message("Soft wrap off")
    else
        micro.InfoBar():Message("Soft wrap on")
    end
    return true
end

function toggle_filemanager()
    if type(filemanager) ~= "table" or type(filemanager.toggle_tree) ~= "function" then
        micro.InfoBar():Error("filemanager plugin is not loaded")
        return
    end

    filemanager.toggle_tree()

    local pane = micro.CurPane()
    if pane ~= nil and pane.Buf ~= nil and pane.Buf.Path == "filemanager" then
        pane:PreviousSplit()
    end
end

function smart_enter(bp)
    if bp.Buf.Path == "filemanager" then
        filemanager.try_open_at_cursor()
        return true
    end
    return bp:InsertNewline()
end

-- postinit runs after every plugin's init(), so this replaces filemanager's
-- own `tree` command without patching the vendored plugin.
function postinit()
    config.MakeCommand("tree", toggle_filemanager, config.NoComplete)
    local openTree = os.Getenv("MICROBOSS_OPEN_TREE")
    if openTree == "1" then
        toggle_filemanager()
    end
end
