-- Runs with either the lightweight SDK mock or native memory NodeDatabases.
local Core=require('npc_core.lua')
local N=require('ndb.lua')
local passed=0
local function test(name,fn)
  local ok,err=pcall(fn)
  if not ok then error(name..': '..tostring(err)) end
  passed=passed+1
end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function promise(deferred)
  local p={deferred=deferred}
  function p:thenDo(ok,fail)
    self.ok=ok;self.fail=fail
    if not self.deferred then ok(self.value) end
    return self
  end
  function p:resolve(value) self.ok(value) end
  function p:reject(value) self.fail(value) end
  return p
end
local room={codigoInterno=700001,me={login='MestreTeste',isMestre=true}}
local items={}
function room:findBibliotecaItem(key) return items[key] end
local opens=0
local function character(key,name,owner,datatype)
  local node=N.newMemNodeDatabase()
  node.nome=name;node.pvTotal=20;node.pvMax=30;node.pvTemporario=4;node.conditionStep=0;node.conditionPenalty=0
  node.trRef=15;node.trFort=14;node.trVon=13;node.dvs=14;node.iniciativa='+3'
  local item={codigoInterno=key,tipo='personagem',name=name,ownerLogin=owner or '',dataType=datatype or Core.characterType,firecastURI='https://vtt.firecast.app/artifacts/rooms/700001/library/'..key,room=room,_node=node}
  function item:asyncOpenNDB()
    opens=opens+1
    local p=self._promise or promise();p.value=node
    return p
  end
  items[key]=item;return item
end
local a=character(2,'Capitão Alfa')
local b=character(3,'Soldado Beta')
local mine=character(4,'Oficial do Mestre','MestreTeste')
local player=character(5,'PC de jogador','JogadorOffline')
local other=character(6,'Outro sistema','','Other.Sheet')
room.library={codigoInterno=1,tipo='biblioteca',children={a,{codigoInterno=10,tipo='diretorio',children={b,mine,player,other}}}}
local store=N.newMemNodeDatabase()
local s=assert(Core.new(room,{store=store}))
local function select(item) local result;s:select(item,function(view,err) assert(view,err);result=view end);return result end
test('isolated GM construction',function() eq(opens,0);eq(#s.rows,3) end)
test('no players or foreign sheets',function() for _,x in ipairs(s.rows) do assert(x~=player and x~=other) end end)
test('unowned filter',function() eq(#Core.collect(room,true),2) end)
test('accent insensitive name search',function() eq(Core.filter(s.rows,' CAPITAO ')[1],a) end)
test('literal search',function() eq(#Core.filter(s.rows,'['),0);eq(#Core.filter(s.rows,'.'),0) end)
test('empty search',function() eq(#Core.filter(s.rows,''),3) end)
test('cycle protected tree',function() room.library.children[#room.library.children+1]=room.library;eq(#Core.collect(room),3);table.remove(room.library.children) end)
test('GM access required',function() room.me.isMestre=false;eq(#Core.collect(room),0);eq(Core.new(room,{store=store}),nil);room.me.isMestre=true end)
test('disconnected GM denied',function() room.me.isCnxDormente=true;eq(#Core.collect(room),0);room.me.isCnxDormente=false end)
test('select opens only chosen NPC',function() local v=select(a);eq(v.health,20);eq(opens,1);eq(s.node,a._node) end)
test('damage consumes temporary HP',function() assert(s:adjustHealth(7,false));eq(a._node.pvTemporario,0);eq(a._node.pvTotal,17) end)
test('undo restores affected fields',function() assert(s:undoLast());eq(a._node.pvTemporario,4);eq(a._node.pvTotal,20) end)
test('healing capped at max',function() assert(s:adjustHealth(99,true));eq(a._node.pvTotal,30) end)
test('zero HP is valid',function() assert(s:setHealth(0));eq(a._node.pvTotal,0) end)
test('above max rejected',function() eq(s:setHealth(31),false);eq(a._node.pvTotal,0) end)
test('invalid HP rejected',function() for _,v in ipairs({-1,0.5,'invalid',math.huge}) do eq(s:setHealth(v),false) end;eq(a._node.pvTotal,0) end)
test('invalid adjustments rejected',function() for _,v in ipairs({-1,0,0.5,'invalid',math.huge}) do eq(s:adjustHealth(v,false),false) end end)
test('condition saved in character',function() assert(s:setCondition(3));eq(a._node.conditionStep,3) end)
test('condition preview adjusted without cached stat writes',function() local v=s:view();eq(v.reflex,10);eq(v.fortitude,9);eq(v.initiative,-2);eq(v.threshold,9);eq(a._node.trRef,15);eq(a._node.conditionPenalty,0) end)
test('Crippled threshold preserved',function() a._node.backgroundName='Crippled';eq(s:view().threshold,14);a._node.backgroundName=nil end)
test('invalid conditions rejected',function() for _,v in ipairs({-1,6,0.5,'invalid'}) do eq(s:setCondition(v),false) end end)
test('blocked character rejects write',function() a.editionBlocked=true;eq(s:setHealth(10),false);eq(a._node.pvTotal,0);a.editionBlocked=false end)
test('server node write permission checked',function()
  local denied={};for k,v in pairs(N) do denied[k]=v end;denied.testPermission=function() return false end
  local state=assert(Core.new(room,{store=N.newMemNodeDatabase(),ndb=denied}))
  state:select(a,function() end);eq(state:setHealth(10),false);state:destroy()
end)
test('lost GM permission blocks actions',function() room.me.isMestre=false;eq(s:setHealth(10),false);eq(s:saveNotes('secret'),false);eq(s:addEncounter(2),false);room.me.isMestre=true end)
test('ownership reassignment blocks writes',function() a.ownerLogin='OtherPlayer';eq(s:setHealth(10),false);a.ownerLogin='' end)
test('removed NPC blocked',function() items[2]=nil;eq(s:setHealth(10),false);items[2]=a end)
test('undo refuses concurrent changes',function() assert(s:setHealth(10));a._node.pvTotal=11;eq(s:undoLast(),false);eq(a._node.pvTotal,11) end)
test('select does not mutate NPC',function() local before=N.exportXML(b._node);select(b);eq(N.exportXML(b._node),before) end)
test('private notes persist in local store',function() assert(s:saveNotes('Nota privada de teste'));eq(store.npc_3.notes,'Nota privada de teste');eq(b._node.notes,nil) end)
test('oversize notes rejected',function() eq(s:saveNotes(string.rep('x',16001)),false);eq(store.npc_3.notes,'Nota privada de teste') end)
test('zero initiative accepted',function() assert(s:addEncounter(0));eq(store.npc_3.initiative,0) end)
test('negative initiative accepted',function() select(a);assert(s:addEncounter(-1));eq(s:encounter()[1].id,'3') end)
test('initiative tiebreak deterministic',function() assert(s:addEncounter(0));eq(s:encounter()[1].id,'2') end)
test('first turn stays in first round',function() local ok,row=s:nextTurn();assert(ok);eq(row.id,'2');eq(store.round,1) end)
test('turn advances',function() local ok,row=s:nextTurn();assert(ok);eq(row.id,'3');eq(store.round,1) end)
test('round wraps',function() local ok,row=s:nextTurn();assert(ok);eq(row.id,'2');eq(store.round,2) end)
test('remove from encounter never deletes NPC',function() assert(s:removeEncounter());eq(#s:encounter(),1);eq(items[2],a);eq(store.activeId,nil) end)
test('private encounter and notes survive controller reopen',function() local nextState=assert(Core.new(room,{store=store}));eq(#nextState:encounter(),1);eq(nextState.store.npc_3.notes,'Nota privada de teste');nextState:destroy() end)
test('opening sheet does not force focus',function()
  local uri,settings
  local state=assert(Core.new(room,{store=N.newMemNodeDatabase(),openURI=function(u,p) uri=u;settings=p;return promise() end}))
  state:select(a,function() end);assert(state:openSheet());eq(uri,a.firecastURI);eq(settings.autoFocus,false);eq(settings.canReplace,false);state:destroy()
end)
test('late selection callback ignored',function()
  a._promise=promise(true);s:select(a,function() error('stale callback') end)
  select(b);a._promise:resolve(a._node);eq(s.node,b._node);a._promise=nil
end)
test('failed old selection ignored',function()
  a._promise=promise(true);s:select(a,function() error('stale failure') end)
  select(b);a._promise:reject('failure');eq(s.node,b._node);a._promise=nil
end)
test('close invalidates pending callbacks',function()
  a._promise=promise(true);s:select(a,function() error('callback after destroy') end)
  s:destroy();a._promise:resolve(a._node);eq(s.node,nil);a._promise=nil;eq(s:setHealth(10),false)
end)
return passed
