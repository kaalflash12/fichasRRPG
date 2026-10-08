-- Independent plugin. Installing it never opens a window or alters a character.
for _,name in ipairs({'npc_core.lua','npc_ui.lua','npc_updater.lua'}) do
  package.loaded[name]=nil
  package.loaded[name:gsub('%.lua$','')]=nil
end
return true
