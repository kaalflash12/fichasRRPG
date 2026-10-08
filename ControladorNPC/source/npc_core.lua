local NDB=require('ndb.lua')
local GUI=require('gui.lua')
local M={version='1.0.1',characterType='MestreRPG.SWSE.Character'}
local names={'Normal','−1','−2','−5','−10 / metade do deslocamento','Inconsciente / indefeso'}
local penalties={0,-1,-2,-5,-10,-10}
local accents={['á']='a',['à']='a',['ã']='a',['â']='a',['ä']='a',['Á']='a',['À']='a',['Ã']='a',['Â']='a',['é']='e',['ê']='e',['É']='e',['Ê']='e',['í']='i',['Í']='i',['ó']='o',['ô']='o',['õ']='o',['Ó']='o',['Ô']='o',['Õ']='o',['ú']='u',['ü']='u',['Ú']='u',['Ü']='u',['ç']='c',['Ç']='c'}
function M.fold(value)
  local s=tostring(value or '')
  for a,b in pairs(accents) do s=s:gsub(a,b) end
  return s:lower()
end
local function integer(v)
  local n=tonumber(v)
  if not n or n~=n or n==math.huge or n==-math.huge or n~=math.floor(n) then return nil end
  return n
end
local function id(item) return tostring(item.codigoInterno or '') end
local function master(room)
  local me=room and (room.me or room.meuJogador)
  return me and me.isMestre==true and me.isCnxDormente~=true
end
M.isMaster=master
function M.eligible(room,item,onlyUnowned)
  if not master(room) or not item or item.tipo~='personagem' or item.dataType~=M.characterType then return false end
  local owner=tostring(item.ownerLogin or item.loginDono or '')
  local me=room.me or room.meuJogador
  return owner=='' or (not onlyUnowned and owner==tostring(me.login or ''))
end
function M.collect(room,onlyUnowned)
  if not master(room) then return {},'Este controlador é exclusivo do mestre (+mestre).' end
  local root=room.library or room.biblioteca
  if not root then return {},'A biblioteca da mesa ainda não está disponível.' end
  local rows,seen,stack={},{},{root}
  while #stack>0 do
    local item=table.remove(stack)
    local key=id(item)
    if key=='' then key=item end
    if not seen[key] then
      seen[key]=true
      if M.eligible(room,item,onlyUnowned) then rows[#rows+1]=item end
      if item.tipo=='biblioteca' or item.tipo=='diretorio' then
        for _,child in ipairs(item.children or item.filhos or {}) do stack[#stack+1]=child end
      end
    end
  end
  table.sort(rows,function(a,b)
    local x,y=M.fold(a.name or a.nome),M.fold(b.name or b.nome)
    if x==y then return (tonumber(id(a)) or 0)<(tonumber(id(b)) or 0) end
    return x<y
  end)
  return rows
end
function M.filter(rows,query)
  local result={};query=M.fold(query):gsub('^%s+',''):gsub('%s+$','')
  for _,item in ipairs(rows) do
    if query=='' or M.fold(item.name or item.nome):find(query,1,true) then result[#result+1]=item end
  end
  return result
end
function M.snapshot(node,item)
  local step=math.max(0,math.min(5,integer(node.conditionStep) or 0))
  local delta=penalties[step+1]-(tonumber(node.conditionPenalty) or penalties[step+1])
  local function adjusted(field)
    local value=tonumber(node[field]);return value and value+delta or nil
  end
  local dtDelta=tostring(node.backgroundName or '')=='Crippled' and 0 or delta
  return {id=id(item),name=tostring(node.nome or item.name or item.nome or 'NPC'),
    species=tostring(node.raca or ''),level=node.nep,health=tonumber(node.pvTotal),maximum=tonumber(node.pvMax),
    temporary=tonumber(node.pvTemporario) or 0,condition=step,conditionName=names[step+1],
    reflex=adjusted('trRef'),fortitude=adjusted('trFort'),will=adjusted('trVon'),
    threshold=tonumber(node.dvs) and tonumber(node.dvs)+dtDelta or nil,
    initiative=adjusted('iniciativa'),force=tonumber(node.forcePoints),destiny=tonumber(node.destinyPoints),
    state=tostring(node.defeatedState or ''),statBlock=tostring(node.statBlockText or '')}
end
function M.new(room,options)
  options=options or {}
  local db=options.ndb or NDB
  local store=options.store
  if not master(room) then return nil,'Este controlador é exclusivo do mestre (+mestre).' end
  if not store then
    local login=tostring((room.me or room.meuJogador).login or ''):gsub('[^%w_.-]','_')
    store=db.load('NPC_'..login..'_'..tostring(room.codigoInterno)..'.xml')
  end
  local s={room=room,store=store,node=nil,selected=nil,rows={},dead=false,generation=0,undo=nil,onlyUnowned=false}
  function s:entry(item,create)
    local key='npc_'..id(item)
    if key=='npc_' then return nil end
    if self.store[key]==nil and create then db.createChildNode(self.store,key) end
    return self.store[key]
  end
  function s:liveItem(item)
    if self.dead or not M.eligible(self.room,item,self.onlyUnowned) then return false end
    local ok,current=pcall(function() return self.room:findBibliotecaItem(tonumber(id(item))) end)
    return ok and current==item
  end
  function s:refresh()
    if self.dead then return {} end
    local rows,err=M.collect(self.room,self.onlyUnowned)
    self.rows=rows
    if self.selected and not self:liveItem(self.selected) then self:clear() end
    return rows,err
  end
  function s:clear()
    self.generation=self.generation+1;self.node=nil;self.selected=nil;self.undo=nil
  end
  function s:select(item,done)
    self:clear()
    if not self:liveItem(item) then done(nil,'NPC indisponível ou sem acesso.');return false end
    self.selected=item
    local generation=self.generation
    local function failure(err)
      if self.dead or self.generation~=generation then return end
      self.node=nil;done(nil,'Não foi possível carregar a ficha: '..tostring(err))
    end
    local ok,promise=pcall(function() return item:asyncOpenNDB() end)
    if not ok then failure(promise);return false end
    local success,err=pcall(function()
      promise:thenDo(function(node)
        if self.dead or self.generation~=generation then return end
        if not self:liveItem(item) or not node then failure('NPC indisponível.');return end
        self.node=node;done(M.snapshot(node,item))
      end,failure)
    end)
    if not success then failure(err);return false end
    return true
  end
  function s:view()
    if not self.selected or not self.node or not self:liveItem(self.selected) then return nil end
    return M.snapshot(self.node,self.selected)
  end
  function s:canWrite()
    if not self.node or not self:liveItem(self.selected) then return false,'Selecione um NPC disponível.' end
    if self.selected.editionBlocked==true or self.selected.escritaBloqueada==true then return false,'A edição desta ficha está bloqueada no Firecast.' end
    local ok,allowed=pcall(db.testPermission,self.node,'write')
    if not ok or not allowed then return false,'Você não tem permissão de escrita nesta ficha.' end
    return true
  end
  function s:apply(changes)
    local allowed,err=self:canWrite();if not allowed then return false,err end
    local before,after={},{}
    for k,v in pairs(changes) do before[k]={value=self.node[k]};after[k]=v end
    local ok,failure=pcall(function() for k,v in pairs(changes) do self.node[k]=v end end)
    if not ok then
      pcall(function() for k,v in pairs(before) do self.node[k]=v.value end end)
      return false,'Não foi possível salvar: '..tostring(failure)
    end
    self.undo={node=self.node,before=before,after=after}
    return true
  end
  function s:setHealth(value)
    value=integer(value)
    if not value or value<0 then return false,'Informe um número inteiro de PV, a partir de zero.' end
    local view=self:view();if not view then return false,'Selecione um NPC.' end
    if view.maximum and value>view.maximum then return false,'Os PV não podem exceder o máximo da ficha.' end
    return self:apply({pvTotal=value})
  end
  function s:adjustHealth(amount,healing)
    amount=integer(amount)
    if not amount or amount<=0 then return false,'Informe uma quantidade inteira maior que zero.' end
    local view=self:view();if not view or not view.health then return false,'O NPC não possui PV atuais válidos.' end
    if healing then
      if not view.maximum then return false,'Defina os PV máximos na ficha completa.' end
      return self:apply({pvTotal=math.min(view.maximum,view.health+amount)})
    end
    local consumed=math.min(math.max(0,view.temporary),amount)
    return self:apply({pvTotal=math.max(0,view.health-(amount-consumed)),pvTemporario=math.max(0,view.temporary)-consumed})
  end
  function s:setCondition(value)
    value=integer(value)
    if not value or value<0 or value>5 then return false,'Escolha uma condição entre 0 e 5.' end
    return self:apply({conditionStep=value})
  end
  function s:undoLast()
    local allowed,err=self:canWrite();if not allowed then return false,err end
    local last=self.undo
    if not last or last.node~=self.node then return false,'Não há ajuste para desfazer neste NPC.' end
    for k,v in pairs(last.after) do
      if self.node[k]~=v then return false,'A ficha mudou depois do ajuste. Atualize os dados antes de desfazer.' end
    end
    local ok,failure=pcall(function() for k,v in pairs(last.before) do self.node[k]=v.value end end)
    if not ok then
      pcall(function() for k,v in pairs(last.after) do self.node[k]=v end end)
      return false,'Não foi possível desfazer: '..tostring(failure)
    end
    self.undo=nil;return true
  end
  function s:openSheet()
    if not self:liveItem(self.selected) then return false,'Selecione um NPC disponível.' end
    local uri=self.selected.firecastURI
    if type(uri)~='string' or uri=='' then return false,'A ficha não possui um endereço Firecast.' end
    return pcall(function() return (options.openURI or GUI.asyncOpenFirecastURI)(uri,{newTab=true,autoFocus=false,canReplace=false}) end)
  end
  function s:addEncounter(initiative)
    if not self:liveItem(self.selected) then return false,'Selecione um NPC disponível.' end
    initiative=integer(initiative)
    if initiative==nil then return false,'Informe a iniciativa (inteiro, inclusive zero).' end
    local e=self:entry(self.selected,true);e.inEncounter=true;e.initiative=initiative
    if not self.store.round then self.store.round=1 end
    return true
  end
  function s:removeEncounter()
    if not self:liveItem(self.selected) then return false,'Selecione um NPC disponível.' end
    local e=self:entry(self.selected,false);if e then e.inEncounter=false end
    if tostring(self.store.activeId or '')==id(self.selected) then self.store.activeId=nil end
    return true
  end
  function s:encounter()
    if not master(self.room) or self.dead then return {} end
    local rows={}
    for _,item in ipairs(self.rows) do
      local e=self:entry(item,false)
      if self:liveItem(item) and e and e.inEncounter==true then
        rows[#rows+1]={id=id(item),name=tostring(item.name or item.nome or 'NPC'),initiative=tonumber(e.initiative) or 0,item=item}
      end
    end
    table.sort(rows,function(a,b)
      if a.initiative~=b.initiative then return a.initiative>b.initiative end
      return (tonumber(a.id) or 0)<(tonumber(b.id) or 0)
    end)
    return rows
  end
  function s:nextTurn()
    if not master(self.room) or self.dead then return false,'Apenas o mestre pode avançar a iniciativa.' end
    local rows=self:encounter();if #rows==0 then return false,'Adicione NPCs ao encontro.' end
    local current=tostring(self.store.activeId or '');local index=0
    for i,row in ipairs(rows) do if row.id==current then index=i;break end end
    local nextIndex=index+1
    if nextIndex>#rows then nextIndex=1;self.store.round=(integer(self.store.round) or 1)+1 end
    if not self.store.round then self.store.round=1 end
    self.store.activeId=rows[nextIndex].id
    return true,rows[nextIndex]
  end
  function s:saveNotes(text)
    if not self:liveItem(self.selected) then return false,'Selecione um NPC disponível.' end
    text=tostring(text or '')
    if #text>16000 then return false,'Use até 16.000 bytes de anotações por NPC.' end
    self:entry(self.selected,true).notes=text;return true
  end
  function s:destroy() self:clear();self.dead=true end
  s:refresh()
  return s
end
return M
