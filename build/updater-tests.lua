local queue={};local installs=0;local stopped={};local details={moduleId='MestreRPG.StarWarsSagaEdition',version='7.3.5'}
local installAllowed=true
_CACHE['internet.lua']={download=function(url,done,failed,progress,cache)
 local id=#queue+1;queue[id]={url=url,done=done,failed=failed,progress=progress,cache=cache};return id
end,stopDownload=function(id)stopped[id]=true end}
_CACHE['plugins.lua']={getInstalledPlugins=function()return {{moduleId='MestreRPG.StarWarsSagaEdition',version='7.3.4'}} end,
 getRPKDetails=function()return details end,installPlugin=function(_,ignore)assert(ignore==true);installs=installs+1;return installAllowed,'Permissão de instalação negada.' end}
local M=require('swse_updater.lua');local passed=0
local function test(fn)fn();passed=passed+1 end
local function stream(s)
 local c={size=#s,remainingBytes=#s,position=0,closed=false}
 function c:read(buf,n)local first=self.position+1;for i=1,n do buf[i]=s:byte(first+i-1) end;self.position=self.position+n;self.remainingBytes=self.size-self.position;return n end
 function c:close()self.closed=true end
 return c
end
local sheetWrites=0
local function form()
 return {sheet=setmetatable({},{__newindex=function()sheetWrites=sheetWrites+1 end}),swseUpdateStatus={},swseUpdateButton={}}
end
local function manifest(v,url,id)
 return stream('SWSE-UPDATE-1\nmodule='..(id or M.moduleId)..'\nversion='..v..'\nrpk='..(url or 'https://raw.githubusercontent.com/'..M.repository..'/main/releases/STARWARS_SAGA_'..v..'.rpk')..'\n')
end
local function response(v,f)
 f=f or form();assert(M.check(f));local q=queue[#queue];q.done(manifest(v));return f
end
test(function()assert(M.compare('7.3.10','7.3.9')==1 and M.compare('7.4.0','7.3.99')==1 and M.compare('7.3.4','7.3.4')==0 and M.compare('invalid','7.3.4')==nil)end)
test(function()local f=response('7.3.4');assert(f.swseUpdateStatus.text:find('mais recente',1,true) and installs==0)end)
test(function()local f=response('7.2.0');assert(f.swseUpdateStatus.text:find('mais recente',1,true) and installs==0)end)
test(function()
 local f=form();M.check(f);queue[#queue].done(manifest('7.3.5','https://github.com/other/repo/releases/download/a/other.rpk'))
 assert(f.swseUpdateStatus.text:find('não pertence',1,true) and installs==0)
end)
test(function()
 local f=form();M.check(f);queue[#queue].done(manifest('7.3.5',nil,'Another.Plugin'))
 assert(f.swseUpdateStatus.text:find('identificação inválida',1,true) and installs==0)
end)
test(function()
 local f=response('7.3.5');local q=queue[#queue];assert(q.cache=='alwaysDownload' and q.url:find('7.3.5.rpk',1,true))
 q.progress(50,100);assert(f.swseUpdateStatus.text:find('50%',1,true))
 local package=stream('RPK_FIXTURE');q.done(package)
 assert(package.closed and installs==1 and f.swseUpdateButton.enabled==true and f.swseUpdateStatus.text:find('instalada',1,true))
end)
test(function()
 details={moduleId='Different.Plugin',version='7.3.5'};local f=response('7.3.5');local package=stream('BAD');queue[#queue].done(package)
 assert(package.closed and installs==1 and f.swseUpdateStatus.text:find('RPK inválido',1,true))
 details={moduleId=M.moduleId,version='7.3.5'}
end)
test(function()
 installAllowed=false;local f=response('7.3.5');queue[#queue].done(stream('RPK_FIXTURE'))
 assert(f.swseUpdateStatus.text:find('Permissão de instalação negada',1,true))
 installAllowed=true
end)
test(function()
 local f=form();assert(M.check(f));local q=queue[#queue];local b=form();assert(M.check(b)==false)
 M.cancel(f);local late=manifest('7.3.5');local n=installs;q.done(late)
 assert(late.closed and installs==n and f.swseUpdateButton.enabled)
end)
test(function()
 local f=form();M.check(f);local q=queue[#queue];runTimers(60100);local late=manifest('7.3.5');local n=installs;q.done(late)
 assert(late.closed and installs==n and f.swseUpdateStatus.text:find('demorou demais',1,true))
end)
test(function()
 local f=form();M.check(f);queue[#queue].failed('HTTP 404');assert(f.swseUpdateStatus.text:find('404',1,true) and f.swseUpdateButton.enabled)
 assert(sheetWrites==0 and timerCount()==0)
end)
return passed
