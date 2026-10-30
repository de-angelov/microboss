-- microboss init.lua
--
-- Micro 2.0.13 has no built-in soft-wrap toggle action, so Alt+Z calls this
-- helper through the binding "lua:initlua.toggle_softwrap" in bindings.json.

local micro = import("micro")

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
