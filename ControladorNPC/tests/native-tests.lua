-- Run in a separate QA module with the official SDK. All rooms and NPCs below are fixtures.
local N=require('ndb.lua');local V=require('vhd.lua');local GUI=require('gui.lua')
local Core=require('npc_core.lua');local UI=require('npc_ui.lua')
local objects=require('rrpgObjs.lua');local oldAdd=objects.addEventListener;local events={}
objects.addEventListener=function(object,event,callback)
 local id=oldAdd(object,event,callback);events[object]=events[object] or {};events[object][event]=callback;return id
end
local out=N.newMemNodeDatabase();out.state='RUNNING';out.nativeUI=0;out.failed=0
local function save()
 local xml=N.exportXML(out);local f=assert(V.openFile('native_npc.xml','w+'))
 local bytes={};for i=1,#xml do bytes[i]=xml:byte(i) end;f:write(bytes,#bytes);f:close()
end
local function check(name,fn)
 local ok,err=pcall(fn)
 if ok then out.nativeUI=(tonumber(out.nativeUI) or 0)+1 else
  out.failed=(tonumber(out.failed) or 0)+1;out['failure'..out.failed]=name..': '..tostring(err)
 end
end
local ok,count=pcall(function() return require('core-tests.lua') end)
if ok then out.nativeCore=count else out.failed=out.failed+1;out.coreError=tostring(count) end
local room={codigoInterno=700002,me={login='FixtureGM',isMestre=true}}
local node=N.newMemNodeDatabase();node.nome='NPC de teste';node.pvTotal=20;node.pvMax=30;node.pvTemporario=4;node.conditionStep=0;node.conditionPenalty=0
node.trRef=15;node.trFort=14;node.trVon=13;node.dvs=14;node.iniciativa='+3'
local opens=0;local lookup={}
local item={codigoInterno=700012,tipo='personagem',dataType=Core.characterType,name='NPC de teste',ownerLogin='',firecastURI='https://vtt.firecast.app/artifacts/rooms/700002/library/700012'}
function item:asyncOpenNDB()
 opens=opens+1
 return {thenDo=function(_,done) done(node) end}
end
room.library={codigoInterno=700011,tipo='biblioteca',children={item}};lookup[item.codigoInterno]=item
function room:findBibliotecaItem(id) return lookup[id] end
local openedURI=nil;local openedSettings=nil
local f=nil;local sheet=nil;local row=nil
local function cleanup() for _,form in ipairs({f,sheet,row}) do if form then pcall(function() if form.npcStop then form:npcStop() end;form:setNodeObject(nil);form:destroy() end) end end end
check('detached dock constructor',function() require('NPCDock.lfm.lua');f=assert(GUI.newForm('frmSWSENPCDock'));assert(not f.isShowing) end)
check('detached alternative sheet constructor',function() require('NPCSheet.lfm.lua');sheet=assert(GUI.newForm('frmSWSENPCSheet'));assert(not sheet.isShowing);sheet:setNodeObject(N.newMemNodeDatabase());assert(sheet._npcState.core==nil) end)
check('detached row constructor',function() require('NPCRow.lfm.lua');row=assert(GUI.newForm('frmSWSENPCRow'));assert(not row.isShowing) end)
objects.addEventListener=oldAdd
check('both compiled forms register lifecycle events',function()
 for _,form in ipairs({f,sheet}) do for _,event in ipairs({'onShow','onHide','onNodeReady','onNodeUnready'}) do assert(events[form] and events[form][event],event..' not compiled') end end
end)
check('native controller starts through compiled onShow with metadata only',function()
 UI.bind(f,{room=room,coreOptions={store=N.newMemNodeDatabase(),openURI=function(u,p) openedURI=u;openedSettings=p;return {thenDo=function(_,done) done() end} end}})
 events[f].onShow();assert(f._npcOpen==true);assert(opens==0);assert(f._npcState.core and f.npcCount.text=='1 NPCs')
end)
check('native memory record list bound',function() assert(#N.getChildNodes(f._npcState.listNode.items)==1);assert(N.getChildNodes(f._npcState.listNode.items)[1].characterId=='700012') end)
check('selection opens one fixture NDB',function() assert(f:npcSelectId(700012));assert(opens==1);assert(f.npcDetail.visible and f.npcName.text=='NPC de teste') end)
check('native current health displayed',function() assert(f.npcHealth.text:find('20 / 30 PV',1,true));assert(f.npcHealthInput.text=='20') end)
check('health setter through native form',function() f.npcHealthInput.text='18';f:npcApply('set');assert(node.pvTotal==18) end)
check('temporary health consumed through native form',function() f.npcAmount.text='7';f:npcApply('damage');assert(node.pvTotal==15 and node.pvTemporario==0) end)
check('undo through native form',function() f:npcApply('undo');assert(node.pvTotal==18 and node.pvTemporario==4) end)
check('condition change through native selector',function() f.npcCondition.value='2';f:npcApply('condition');assert(node.conditionStep==2);assert(f.npcDefenses.text:find('REF 13',1,true)) end)
check('private note isolated from character',function() f.npcNotes.text='Anotacao privada de teste';f:npcSaveNotes();assert(f._npcState.core.store.npc_700012.notes=='Anotacao privada de teste' and node.notes==nil) end)
check('native initiative accepts zero',function() f.npcInitiativeInput.text='0';f:npcEncounter('add');assert(f._npcState.core.store.npc_700012.initiative==0);assert(f.npcEncounterList.text:find('NPC de teste',1,true)) end)
check('native turn and round control',function() f:npcEncounter('next');assert(f._npcState.core.store.activeId=='700012');f:npcEncounter('next');assert(f.npcRound.text=='RODADA 2') end)
check('sheet-opening requests preserve current tab',function() f:npcOpenSheet();assert(openedURI==item.firecastURI and openedSettings.autoFocus==false and openedSettings.canReplace==false) end)
check('native blocked editor disabled',function() item.editionBlocked=true;f:npcPaint();assert(not f.npcDamage.enabled and not f.npcSetHealth.enabled);item.editionBlocked=false;f:npcPaint() end)
check('list page bounded at sixty',function()
 for i=1,80 do local x={codigoInterno=701000+i,tipo='personagem',dataType=Core.characterType,name='NPC '..i,ownerLogin=''};lookup[x.codigoInterno]=x;room.library.children[#room.library.children+1]=x end
 f:npcRefresh();assert(#N.getChildNodes(f._npcState.listNode.items)==60);f:npcChangePage(1);assert(#N.getChildNodes(f._npcState.listNode.items)==21)
end)
check('search filters names using metadata',function() f.npcSearch.text='teste';f:npcRebuildList();assert(f.npcCount.text=='1 NPCs' and opens==1) end)
check('compiled onHide releases NPC and scopes',function() events[f].onHide();assert(f._npcOpen==false);assert(f._npcState.core==nil and f.npcNodeWatch.node==nil and f.npcListScope.node==nil) end)
check('non-GM panel does not expose NPC data',function()
 room.me.isMestre=false;UI.bind(sheet,{room=room,coreOptions={store=N.newMemNodeDatabase()}})
 assert(not sheet:npcStart());assert(not sheet.npcShell.visible and sheet.npcAccessMessage.visible);room.me.isMestre=true
end)
check('compiled onNodeReady retries while the opening event is pending',function()
 f._npcOpen=true;assert(not f.isShowing);events[f].onNodeReady();assert(f._npcState.core and f.npcShell.visible)
end)
check('compiled onNodeUnready releases the old sheet',function() events[f].onNodeUnready();assert(f._npcState.core==nil and f.npcListScope.node==nil) end)
check('compiled RECARREGAR starts an uninitialized controller',function() events[f.npcRefreshButton].onClick();assert(f._npcState.core and f.npcShell.visible);events[f].onHide() end)
cleanup()
out.version='1.0.1';out.module='MestreRPG.SWSE.NPCController'
out.screenControlUsed=false;out.characterDataChanged=false;out.realRoomUsed=false
out.state=out.nativeCore==42 and out.nativeUI==24 and out.failed==0 and 'PASS' or 'FAIL';save()
return true
