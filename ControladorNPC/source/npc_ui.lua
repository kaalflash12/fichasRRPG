local Core=require('npc_core.lua')
local Firecast=require('firecast.lua')
local NDB=require('ndb.lua')
local Updater=require('npc_updater.lua')
local M={}
local function display(v) return v==nil and '—' or tostring(v) end
function M.bind(form,options)
  options=options or {}
  if form._npcState and form.npcStop then form:npcStop() end
  local state={core=nil,queryTimer=nil,loadTimer=nil,page=1,pageSize=60,rendering=false,rows={},listNode=nil}
  form._npcState=state
  local function status(text) if form.npcStatus then form.npcStatus.text=text end end
  local function timers()
    for _,k in ipairs({'queryTimer','loadTimer'}) do
      if state[k] then clearTimeout(state[k]);state[k]=nil end
    end
  end
  function form:npcStop()
    timers();Updater.cancel(self)
    if state.core then state.core:destroy();state.core=nil end
    if self.npcNodeWatch then self.npcNodeWatch.node=nil end
    if self.npcListScope then self.npcListScope.node=nil end
    state.listNode=nil;state.rows={}
  end
  function form:npcResize()
    if not self.npcShell or not self.npcIndex then return end
    if self.npcShell.width<760 then
      self.npcIndex.align='top';self.npcIndex.height=224;self.npcIndex.margins={bottom=8}
    else self.npcIndex.align='left';self.npcIndex.width=286;self.npcIndex.margins={right=8} end
    if self.npcHeaderTitle then self.npcHeaderTitle.visible=self.width>=590 end
    if self.npcList then
      for _,item in ipairs(self.npcList:getChildren()) do
        if item.name=='frmSWSENPCRow' then item.width=math.max(40,self.npcList.width-18) end
      end
    end
  end
  function form:npcStart()
    self:npcStop()
    local room=options.room or Firecast.getRoomOf(self) or Firecast.getRoomOf(self.sheet)
    local success,core,err=pcall(Core.new,room,options.coreOptions)
    if not success then err='Não foi possível abrir o controlador: '..tostring(core);core=nil end
    if not core then
      self.npcShell.visible=false;self.npcAccessMessage.visible=true
      self.npcAccessMessage.text=err..'\n\nAbra este painel dentro da mesa como mestre.'
      status(err);return false
    end
    state.core=core;self.npcShell.visible=true;self.npcAccessMessage.visible=false
    self:npcRefresh();self:npcResize();return true
  end
  function form:npcRefresh(recover)
    if not state.core then
      if recover then return self:npcStart() end
      return
    end
    state.core.onlyUnowned=self.npcFilter.value=='unowned'
    local _,err=state.core:refresh()
    state.page=1;self:npcRebuildList();self:npcPaint()
    status(err or (#state.core.rows==0 and 'Nenhum NPC Star Wars encontrado. Crie ou importe a ficha na Biblioteca da mesa.' or 'NPCs carregados. Selecione um nome para abrir os dados.'))
  end
  function form:npcRebuildList()
    if not state.core then return end
    local rows=Core.filter(state.core.rows,self.npcSearch.text)
    if self.npcEncounterFilter.value=='encounter' then
      local keep={};for _,x in ipairs(state.core:encounter()) do keep[x.id]=true end
      local filtered={};for _,x in ipairs(rows) do if keep[tostring(x.codigoInterno)] then filtered[#filtered+1]=x end end
      rows=filtered
    end
    state.rows=rows
    local pages=math.max(1,math.ceil(#rows/state.pageSize));state.page=math.max(1,math.min(pages,state.page))
    local root=NDB.newMemNodeDatabase();local parent=NDB.createChildNode(root,'items')
    local selected=nil
    for i=(state.page-1)*state.pageSize+1,math.min(#rows,state.page*state.pageSize) do
      local item=rows[i];local node=NDB.createChildNode(parent,'npc_'..tostring(item.codigoInterno))
      node.characterId=tostring(item.codigoInterno);node.name=tostring(item.name or item.nome or 'NPC')
      local e=state.core:entry(item,false)
      node.detail=e and e.inEncounter==true and ('ENCONTRO / INI '..display(e.initiative)) or 'FICHA STAR WARS SAGA'
      if state.core.selected==item then selected=node end
    end
    state.rendering=true;state.listNode=root;self.npcListScope.node=root
    self.npcList.selectedNode=selected;state.rendering=false
    self.npcCount.text=tostring(#rows)..' NPCs';self.npcPageLabel.text=state.page..' / '..pages
    self.npcPrevPage.enabled=state.page>1;self.npcNextPage.enabled=state.page<pages
    self:npcResize()
  end
  function form:npcQueryChanged()
    if state.queryTimer then clearTimeout(state.queryTimer) end
    if not state.core then return end
    state.queryTimer=setTimeout(function()
      state.queryTimer=nil
      if state.core then state.page=1;self:npcRebuildList() end
    end,120)
  end
  function form:npcChangePage(delta)
    if not state.core then return end
    state.page=state.page+delta;self:npcRebuildList()
  end
  function form:npcSelectId(characterId)
    if not state.core then return false end
    local item=nil
    for _,row in ipairs(state.core.rows) do if tostring(row.codigoInterno)==tostring(characterId) then item=row;break end end
    if not item then status('NPC não encontrado. Atualize a lista.');return false end
    if state.loadTimer then clearTimeout(state.loadTimer);state.loadTimer=nil end
    self.npcNodeWatch.node=nil;self.npcDetail.visible=false;self.npcEmpty.visible=true;self.npcEmpty.text='Carregando a ficha do NPC…'
    local core=state.core
    local completed=false
    local result=core:select(item,function(view,err)
      if state.core~=core then return end
      completed=true
      if state.loadTimer then clearTimeout(state.loadTimer);state.loadTimer=nil end
      if not view then self.npcEmpty.text=err or 'Ficha indisponível.';status(err or 'Ficha indisponível.');return end
      self.npcNodeWatch.node=core.node
      state.rendering=true
      local entry=core:entry(item,false)
      self.npcInitiativeInput.text=entry and display(entry.initiative) or display(view.initiative or 0)
      self.npcNotes.text=entry and tostring(entry.notes or '') or ''
      state.rendering=false
      self:npcPaint();status('Dados de '..view.name..' carregados.')
    end)
    if result and not completed then
      state.loadTimer=setTimeout(function()
        state.loadTimer=nil
        if state.core==core then
          core:clear();self.npcEmpty.text='A ficha demorou para carregar. Selecione o NPC novamente.'
          status(self.npcEmpty.text)
        end
      end,30000)
    end
    return result
  end
  function form:npcListSelected()
    if state.rendering then return end
    local node=self.npcList.selectedNode
    if node then self:npcSelectId(node.characterId) end
  end
  function form:npcPaint()
    if not state.core or state.rendering then return end
    local view=state.core:view()
    self.npcDetail.visible=view~=nil;self.npcEmpty.visible=view==nil
    if not view then self.npcEmpty.text='SELECIONE UM NPC\n\nA ficha completa continua na Biblioteca da mesa.';self:npcPaintEncounter();return end
    state.rendering=true
    self.npcName.text=view.name
    self.npcIdentity.text=(view.species~='' and view.species..' / ' or '')..'NÍVEL '..display(view.level)
    self.npcHealth.text=display(view.health)..' / '..display(view.maximum)..' PV   /   TEMP '..display(view.temporary)
    self.npcDefenses.text='REF '..display(view.reflex)..'    FORT '..display(view.fortitude)..'    VON '..display(view.will)..'    LD '..display(view.threshold)
    self.npcResources.text='INI '..display(view.initiative)..'    FORÇA '..display(view.force)..'    DESTINO '..display(view.destiny)
    self.npcHealthInput.text=display(view.health)
    self.npcCondition.value=tostring(view.condition)
    self.npcConditionStatus.text=view.conditionName..(view.state~='' and (' / '..view.state) or '')
    self.npcStatBlock.text=view.statBlock~='' and view.statBlock or 'Abra a ficha completa para consultar ataques, perícias, talentos e equipamentos.'
    local writable,err=state.core:canWrite()
    for _,key in ipairs({'npcSetHealth','npcDamage','npcHeal','npcApplyCondition','npcHealthInput','npcCondition'}) do self[key].enabled=writable end
    self.npcUndo.enabled=writable and state.core.undo~=nil
    self.npcWriteStatus.text=writable and 'Ajustes de PV e condição são salvos na ficha do NPC.' or err
    state.rendering=false;self:npcPaintEncounter()
  end
  function form:npcApply(action)
    if not state.core then return end
    local ok,err
    if action=='set' then ok,err=state.core:setHealth(self.npcHealthInput.text)
    elseif action=='damage' then ok,err=state.core:adjustHealth(self.npcAmount.text,false)
    elseif action=='heal' then ok,err=state.core:adjustHealth(self.npcAmount.text,true)
    elseif action=='condition' then ok,err=state.core:setCondition(self.npcCondition.value)
    elseif action=='undo' then ok,err=state.core:undoLast() end
    if ok then self:npcPaint();status('Ajuste salvo na ficha do NPC.') else status(err or 'Ajuste não realizado.') end
  end
  function form:npcOpenSheet()
    if not state.core then return end
    local ok,promise=state.core:openSheet()
    if not ok then status(tostring(promise));return end
    if promise and promise.thenDo then
      promise:thenDo(function() status('Ficha completa aberta em outra aba.') end,function(err) status('Não foi possível abrir a ficha: '..tostring(err)) end)
    end
  end
  function form:npcEncounter(action)
    if not state.core then return end
    local ok,err
    if action=='add' then ok,err=state.core:addEncounter(self.npcInitiativeInput.text)
    elseif action=='remove' then ok,err=state.core:removeEncounter()
    elseif action=='next' then ok,err=state.core:nextTurn() end
    self:npcPaintEncounter();self:npcRebuildList()
    status(ok and 'Iniciativa atualizada no controle privado do mestre.' or tostring(err))
  end
  function form:npcPaintEncounter()
    if not state.core then return end
    local lines={};local active=tostring(state.core.store.activeId or '')
    for _,row in ipairs(state.core:encounter()) do
      lines[#lines+1]=(active==row.id and '▶ ' or '  ')..row.initiative..'  '..row.name
    end
    self.npcRound.text='RODADA '..tostring(state.core.store.round or 1)
    self.npcEncounterList.text=#lines>0 and table.concat(lines,'\n') or 'Adicione os NPCs que participam deste encontro.'
  end
  function form:npcSaveNotes()
    if not state.core then return end
    local ok,err=state.core:saveNotes(self.npcNotes.text)
    status(ok and 'Anotações salvas no controle privado do mestre.' or err)
  end
  function form:npcDownload() Updater.openDownload(self) end
  function form:npcUpdate() Updater.check(self) end
  return state
end
return M
