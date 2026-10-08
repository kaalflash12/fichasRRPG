-- Two user-triggered paths: the catalog Auto Updater and the RPGmeister download button.
local Internet=require('internet.lua')
local Plugins=require('plugins.lua')
local NDB=require('ndb.lua')
local Firecast=require('firecast.lua')
local GUI=require('gui.lua')
local M={version='1.0.0',moduleId='MestreRPG.SWSE.NPCController',
  repository='kaalflash12/fichasRRPG',
  manifestURL='https://raw.githubusercontent.com/kaalflash12/fichasRRPG/main/ControladorNPC/update.txt',
  latestRPKURL='https://raw.githubusercontent.com/kaalflash12/fichasRRPG/main/releases/CONTROLADOR_NPC_STARWARS.rpk',
  catalogURL='https://sdk3.firecast.app/Plugins/plugins.xml',
  autoUpdaterId='Ambesek.Auto.Updater'}
local busy=nil
local function version(v)
  local a,b,c=tostring(v or ''):match('^(%d+)%.(%d+)%.(%d+)$')
  if not a then return nil end
  return {tonumber(a),tonumber(b),tonumber(c)}
end
function M.compare(a,b)
  a=version(a);b=version(b)
  if not a or not b then return nil end
  for i=1,3 do if a[i]~=b[i] then return a[i]>b[i] and 1 or -1 end end
  return 0
end
local function installedPlugins()
  local ok,list=pcall(Plugins.getInstalledPlugins)
  return ok and type(list)=='table' and list or {}
end
local function installedVersion()
  local current=M.version
  for _,p in ipairs(installedPlugins()) do
    if p.moduleId==M.moduleId and M.compare(p.version,current)==1 then current=p.version end
  end
  return current
end
local function status(form,text)
  if not form then return end
  pcall(function()
    form._swseUpdateMessage=text
    if form.swseUpdateStatus then form.swseUpdateStatus.text=text end
  end)
end
function M.openDownload(form)
  local ok,result=pcall(GUI.openInBrowser,M.latestRPKURL)
  if not ok or result==false then
    status(form,'Não foi possível abrir o download do RPK. '..tostring(result or ''))
    return false
  end
  status(form,'Download aberto no navegador. Abra o RPK baixado para instalar no Firecast.')
  return true
end
function M.parseManifest(text)
  if type(text)~='string' or #text>8192 then return nil,'Manifesto inválido.' end
  text=text:gsub('\r\n','\n')
  if text:match('^([^\n]+)')~='SWSE-UPDATE-1' then return nil,'Canal GitHub ainda não publicado ou resposta inválida.' end
  local data={}
  for line in text:gmatch('[^\n]+') do
    local k,v=line:match('^(%a+)=([^%c]+)$')
    if k then if data[k]~=nil then return nil,'Campo duplicado no manifesto.' end;data[k]=v end
  end
  if data.module~=M.moduleId or not version(data.version) then return nil,'Versão ou identificação inválida.' end
  local raw='https://raw.githubusercontent.com/'..M.repository..'/'
  local release='https://github.com/'..M.repository..'/releases/download/'
  local u=data.rpk or ''
  if not (u:sub(1,#raw)==raw or u:sub(1,#release)==release) or not u:match('%.rpk$')
      or u:find('..',1,true) or u:find('[%s?#]') then return nil,'O RPK não pertence ao canal configurado.' end
  return data
end
local function close(stream) if stream then pcall(function() stream:close() end) end end
local function readText(stream,limit)
  stream.position=0
  if tonumber(stream.size or stream.remainingBytes or 0)>limit then error('Resposta muito grande.') end
  local parts={};local total=0
  while stream.remainingBytes>0 do
    local buffer={};local got=stream:read(buffer,math.min(1024,stream.remainingBytes))
    if not got or got<=0 then error('Resposta incompleta.') end
    total=total+got;if total>limit then error('Resposta muito grande.') end
    parts[#parts+1]=string.char(table.unpack(buffer,1,got))
  end
  return table.concat(parts)
end
function M.catalogEntry(stream,data)
  local root=NDB.newMemNodeDatabase()
  NDB.importXML(root,readText(stream,2*1024*1024))
  local found=nil
  for _,node in ipairs(NDB.getChildNodes(root)) do
    if tostring(node.id or ''):lower()==M.moduleId:lower() then
      if found then error('Cadastro duplicado no catálogo do Firecast.') end
      found={url=node.url,version=node.version}
    end
  end
  if not found then return nil end
  local official='https://sdk3.firecast.app/Plugins/Sheets/StarWarsNPCController/output/CONTROLADOR_NPC_STARWARS.rpk?raw=true'
  if found.url~=M.latestRPKURL and found.url~=data.rpk and found.url~=official then
    error('O cadastro do Firecast aponta para outro pacote.')
  end
  return found
end
local function live(state) return busy==state and state.form.sheet==state.sheet end
local function stopResources(state)
  if state.timer then pcall(clearTimeout,state.timer);state.timer=nil end
  if state.poll then pcall(clearTimeout,state.poll);state.poll=nil end
  if state.download then pcall(Internet.stopDownload,state.download);state.download=nil end
end
local function finish(state,text)
  if busy~=state then return end
  busy=nil;stopResources(state);status(state.form,text)
  pcall(function() if state.form.swseUpdateButton then state.form.swseUpdateButton.enabled=true end end)
end
function M.cancel(form)
  if busy and busy.form==form then
    finish(busy,busy.delegated and 'Verificação encerrada. O Auto Updater pode continuar a instalação.' or 'Atualização cancelada.')
  end
end
local function timeout(state)
  if state.timer then clearTimeout(state.timer) end
  state.timer=setTimeout(function()
    finish(state,state.delegated and 'O Auto Updater ainda não confirmou a instalação. Consulte o Firecast ou use BAIXAR RPK.' or 'A conexão demorou demais. Tente novamente ou use BAIXAR RPK.')
  end,60000)
end
local function request(state,url,done,progress)
  local token={};state.request=token
  local function failed(message)
    if busy==state then finish(state,'Não foi possível atualizar pelo Firecast: '..tostring(message or 'falha de conexão')) end
  end
  local function received(stream)
    if state.request==token then state.download=nil end
    if not live(state) then close(stream);finish(state,'Atualização cancelada.');return end
    local ok,err=pcall(done,stream)
    close(stream)
    if not ok then failed(err) end
  end
  local good,id=pcall(Internet.download,url,received,failed,progress,'alwaysDownload')
  if not good then failed(id) elseif live(state) and state.request==token then state.download=id end
end
function M.check(form)
  if not form then return false end
  if busy then status(form,'Já há uma atualização em andamento.');return false end
  local state={form=form,sheet=form.sheet,current=installedVersion()};busy=state
  pcall(function() if form.swseUpdateButton then form.swseUpdateButton.enabled=false end end)
  status(form,'Consultando a versão publicada no GitHub…');timeout(state)
  request(state,M.manifestURL,function(stream)
    local data,err=M.parseManifest(readText(stream,8192))
    if not data then error(err) end
    if M.compare(data.version,state.current)~=1 then finish(state,'Você já tem a versão mais recente ('..state.current..').');return end
    local hasUpdater=false
    for _,p in ipairs(installedPlugins()) do if p.moduleId==M.autoUpdaterId then hasUpdater=true;break end end
    if not hasUpdater then finish(state,'Instale o Auto Updater do Firecast para usar a atualização nativa. BAIXAR RPK continua disponível.');return end
    timeout(state);status(form,'Verificando o cadastro no Auto Updater…')
    request(state,M.catalogURL,function(catalog)
      local entry=M.catalogEntry(catalog,data)
      if not entry then finish(state,'Atualização nativa pendente: este controlador ainda não está no catálogo do Firecast. Use BAIXAR RPK.');return end
      local room=Firecast.getRoomOf(state.form) or Firecast.getRoomOf(state.sheet)
      local chat=room and room.chat
      if not chat or type(chat.enviarMensagem)~='function' then finish(state,'Abra esta ficha em uma mesa conectada para usar o Auto Updater. BAIXAR RPK continua disponível.');return end
      timeout(state);status(form,'Validando o RPK do canal nativo…')
      local function progress(downloaded,total)
        if not live(state) then return false end
        if tonumber(total) and total>0 then
          local percent=math.max(0,math.min(100,math.floor((tonumber(downloaded) or 0)*100/total)))
          if percent~=state.percent then state.percent=percent;status(form,'Validando RPK: '..percent..'%') end
        end
        return true
      end
      request(state,entry.url,function(package)
        local info=Plugins.getRPKDetails(package)
        if type(info)~='table' or info.moduleId~=M.moduleId or not M.compare(info.version,data.version)
            or M.compare(info.version,data.version)<0 then
          finish(state,'O catálogo nativo ainda não tem o RPK publicado ou o pacote é inválido. Use BAIXAR RPK.');return
        end
        if M.compare(info.version,installedVersion())~=1 then finish(state,'A versão mais recente já está instalada.');return end
        state.target=info.version;state.delegated=true;timeout(state)
        -- Use the public command only for this registered catalog entry.
        chat:enviarMensagem('/autoupdater '..M.moduleId)
        status(form,'Atualização solicitada ao Auto Updater. Aguardando confirmação…')
        local function verify()
          state.poll=nil
          if not live(state) then finish(state,'Verificação encerrada. O Auto Updater pode continuar a instalação.');return end
          local current=installedVersion()
          if M.compare(current,state.target)>=0 then finish(state,'Versão '..current..' instalada. Reabra esta ficha para carregar a atualização.');return end
          state.poll=setTimeout(verify,1000)
        end
        state.poll=setTimeout(verify,1000)
      end,progress)
    end)
  end)
  return true
end
return M
