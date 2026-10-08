local queue,commands,opened={}, {}, {}
local installed='1.0.0';local hasUpdater=true;local details={moduleId='MestreRPG.SWSE.NPCController',version='1.0.1'}
local catalogNodes={};local roomAvailable=true;local browserFails=false;local packageCalls=0
_CACHE['internet.lua']={download=function(url,done,failed,progress,cache)
 local id=#queue+1;queue[id]={url=url,done=done,failed=failed,progress=progress,cache=cache};return id
end,stopDownload=function(id)queue[id].stopped=true end}
_CACHE['plugins.lua']={getInstalledPlugins=function()
 local list={{moduleId='MestreRPG.SWSE.NPCController',version=installed}}
 if hasUpdater then list[#list+1]={moduleId='Ambesek.Auto.Updater',version='1.3.1'} end
 return list
end,getRPKDetails=function()packageCalls=packageCalls+1;return details end,
installPlugin=function()error('The sheet must use the public Auto Updater command')end}
GUI.openInBrowser=function(url)if browserFails then error('browser blocked')end;opened[#opened+1]=url end
NDB.newMemNodeDatabase=function()return {}end
NDB.importXML=function(root,text)assert(text=='CATALOG_FIXTURE','bad XML fixture');root.__items=catalogNodes end
Firecast.getRoomOf=function()
 if roomAvailable then return {chat={enviarMensagem=function(_,command)commands[#commands+1]=command end}}end
end
local M=require('npc_updater.lua');local passed=0
local function test(name,fn)local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));passed=passed+1 end
local function stream(s)
 local c={size=#s,remainingBytes=#s,position=0,closed=false}
 function c:read(buf,n)local first=self.position+1;for i=1,n do buf[i]=s:byte(first+i-1)end;self.position=self.position+n;self.remainingBytes=self.size-self.position;return n end
 function c:close()self.closed=true end
 return c
end
local sheetWrites=0
local function form()return {sheet=setmetatable({},{__newindex=function()sheetWrites=sheetWrites+1 end}),swseUpdateStatus={},swseUpdateButton={}}end
local function manifest(v,url,id)
 return stream('SWSE-UPDATE-1\nmodule='..(id or M.moduleId)..'\nversion='..v..'\nrpk='..(url or 'https://raw.githubusercontent.com/'..M.repository..'/main/releases/CONTROLADOR_NPC_STARWARS_'..v..'.rpk')..'\n')
end
local function start(v,f)f=f or form();assert(M.check(f));queue[#queue].done(manifest(v or '1.0.1'));return f end
local function registered(url)catalogNodes={{id=M.moduleId,url=url or M.latestRPKURL,version='1.0.0'}}end
local function catalog(f)queue[#queue].done(stream('CATALOG_FIXTURE'));return f end
local function package(f)queue[#queue].done(stream('RPK_FIXTURE'));return f end
test('numeric version ordering',function()assert(M.compare('7.3.10','7.3.9')==1 and M.compare('7.4.0','7.3.99')==1 and M.compare('invalid','1.0.0')==nil)end)
test('download uses the stable GitHub alias',function()local f=form();assert(M.openDownload(f));assert(opened[#opened]==M.latestRPKURL and f.swseUpdateStatus.text:find('navegador',1,true))end)
test('download does not report installation',function()local f=form();M.openDownload(f);assert(not f.swseUpdateStatus.text:find('instalada',1,true))end)
test('browser failure is visible',function()browserFails=true;local f=form();assert(not M.openDownload(f));assert(f.swseUpdateStatus.text:find('browser blocked',1,true));browserFails=false end)
test('current version needs no catalog or command',function()local count=#queue;local f=start('1.0.0');assert(#queue==count+1 and f.swseUpdateStatus.text:find('mais recente',1,true) and #commands==0)end)
test('old version never downgrades',function()local f=start('0.9.0');assert(f.swseUpdateStatus.text:find('mais recente',1,true))end)
test('foreign GitHub repository is rejected',function()local f=form();M.check(f);queue[#queue].done(manifest('1.0.1','https://github.com/other/repo/releases/download/x/a.rpk'));assert(f.swseUpdateStatus.text:find('não pertence',1,true))end)
test('foreign module manifest is rejected',function()local f=form();M.check(f);queue[#queue].done(manifest('1.0.1',nil,'Other.Plugin'));assert(f.swseUpdateStatus.text:find('identificação inválida',1,true))end)
test('duplicate manifest fields are rejected',function()local data=M.parseManifest('SWSE-UPDATE-1\nmodule='..M.moduleId..'\nmodule='..M.moduleId..'\nversion=1.0.1\nrpk='..M.latestRPKURL);assert(data==nil)end)
test('CRLF manifest is accepted',function()local s='SWSE-UPDATE-1\r\nmodule='..M.moduleId..'\r\nversion=1.0.1\r\nrpk='..M.latestRPKURL..'\r\n';assert(M.parseManifest(s))end)
test('missing Auto Updater is explained',function()hasUpdater=false;local f=start();assert(f.swseUpdateStatus.text:find('Instale o Auto Updater',1,true));hasUpdater=true end)
test('missing catalog entry never triggers a command',function()catalogNodes={};local n=#commands;local f=catalog(start());assert(f.swseUpdateStatus.text:find('ainda não está no catálogo',1,true) and #commands==n)end)
test('catalog error releases the button',function()local f=start();queue[#queue].failed('HTTP 503');assert(f.swseUpdateButton.enabled and f.swseUpdateStatus.text:find('503',1,true))end)
test('malformed catalog is rejected',function()local f=start();queue[#queue].done(stream('BROKEN'));assert(f.swseUpdateButton.enabled and f.swseUpdateStatus.text:find('bad XML fixture',1,true))end)
test('foreign catalog URL is rejected',function()registered('https://github.com/other/repo/a.rpk');local f=catalog(start());assert(f.swseUpdateStatus.text:find('outro pacote',1,true))end)
test('duplicate catalog module is rejected',function()registered();catalogNodes[2]=catalogNodes[1];local f=catalog(start());assert(f.swseUpdateStatus.text:find('duplicado',1,true))end)
test('disconnected sheet never sends a command',function()registered();roomAvailable=false;local n=#commands;local f=catalog(start());assert(f.swseUpdateStatus.text:find('mesa conectada',1,true) and #commands==n);roomAvailable=true end)
test('foreign RPK identity is rejected',function()registered();details={moduleId='Other.Plugin',version='1.0.1'};local n=#commands;local f=package(catalog(start()));assert(f.swseUpdateStatus.text:find('pacote é inválido',1,true) and #commands==n);details={moduleId=M.moduleId,version='1.0.1'}end)
test('outdated official package is rejected',function()registered();details={moduleId=M.moduleId,version='1.0.0'};local n=#commands;local f=package(catalog(start()));assert(f.swseUpdateStatus.text:find('ainda não tem',1,true) and #commands==n);details={moduleId=M.moduleId,version='1.0.1'}end)
test('invalid package version is rejected',function()registered();details={moduleId=M.moduleId,version='invalid'};local f=package(catalog(start()));assert(f.swseUpdateStatus.text:find('pacote é inválido',1,true));details={moduleId=M.moduleId,version='1.0.1'}end)
test('only the public command is sent after validation',function()registered();local f=package(catalog(start()));assert(commands[#commands]=='/autoupdater '..M.moduleId);assert(f.swseUpdateStatus.text:find('Aguardando confirmação',1,true));assert(not f.swseUpdateStatus.text:find('instalada',1,true));M.cancel(f)end)
test('installation requires a native version change',function()registered();local f=package(catalog(start()));runTimers(1000);assert(not f.swseUpdateStatus.text:find('instalada',1,true));installed='1.0.1';runTimers(1000);assert(f.swseUpdateStatus.text:find('1.0.1 instalada',1,true) and f.swseUpdateButton.enabled);installed='1.0.0' end)
test('unconfirmed native installation times out truthfully',function()registered();local f=package(catalog(start()));runTimers(60100);assert(f.swseUpdateStatus.text:find('ainda não confirmou',1,true) and not f.swseUpdateStatus.text:find('instalada',1,true) and f.swseUpdateButton.enabled)end)
test('cancelling after delegation preserves the pending outcome',function()registered();local f=package(catalog(start()));M.cancel(f);assert(f.swseUpdateStatus.text:find('pode continuar',1,true) and f.swseUpdateButton.enabled)end)
test('cancellation closes a late manifest',function()local f=form();M.check(f);local q=queue[#queue];M.cancel(f);local late=manifest('1.0.1');q.done(late);assert(late.closed and f.swseUpdateButton.enabled)end)
test('only one update runs at a time',function()local a=form();local b=form();assert(M.check(a));assert(not M.check(b));M.cancel(a)end)
test('network timeout closes late content',function()local f=form();M.check(f);local q=queue[#queue];runTimers(60100);local late=manifest('1.0.1');q.done(late);assert(late.closed and f.swseUpdateStatus.text:find('demorou demais',1,true))end)
test('manifest HTTP failure restores the button',function()local f=form();M.check(f);queue[#queue].failed('HTTP 404');assert(f.swseUpdateButton.enabled and f.swseUpdateStatus.text:find('404',1,true))end)
test('oversized manifest is rejected',function()local f=form();M.check(f);queue[#queue].done(stream(string.rep('X',8193)));assert(f.swseUpdateButton.enabled and f.swseUpdateStatus.text:find('muito grande',1,true))end)
test('oversized catalog is rejected',function()local f=start();local c=stream('x');c.size=2*1024*1024+1;queue[#queue].done(c);assert(f.swseUpdateButton.enabled and f.swseUpdateStatus.text:find('muito grande',1,true))end)
test('download remains independent during a native check',function()local f=form();M.check(f);local n=#opened;assert(M.openDownload(f) and #opened==n+1);M.cancel(f)end)
test('no character fields are written and all timers end',function()assert(sheetWrites==0 and timerCount()==0 and packageCalls>0)end)
test('dock without a sheet can check its own channel',function()local f={swseUpdateStatus={},swseUpdateButton={}};assert(M.check(f));queue[#queue].done(manifest('1.0.0'));assert(f.swseUpdateStatus.text:find('mais recente',1,true))end)
test('module and channel are independent',function()assert(M.moduleId=='MestreRPG.SWSE.NPCController' and M.manifestURL:find('/ControladorNPC/update.txt',1,true) and M.latestRPKURL:find('CONTROLADOR_NPC_STARWARS.rpk',1,true))end)
return passed
