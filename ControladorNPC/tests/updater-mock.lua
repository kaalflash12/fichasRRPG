
__clock=0; __nextTimer=0; __timers={}; __messages={}; __writes=0; __reads=0; __walks=0; __created=0
function setTimeout(fn,delay) __nextTimer=__nextTimer+1; __timers[__nextTimer]={fn=fn,at=__clock+(delay or 0)}; return __nextTimer end
function clearTimeout(id) __timers[id]=nil end
function runTimers(ms)
  local untilTime=__clock+ms; local steps=0
  while true do
    local best=nil; local at=nil
    for k,t in pairs(__timers) do if t.at<=untilTime and (at==nil or t.at<at) then best=k; at=t.at end end
    if not best then break end
    local f=__timers[best].fn; __timers[best]=nil; __clock=at; f(); steps=steps+1
    if steps>20000 then error('timer runaway') end
  end
  __clock=untilTime
end
function timerCount() local n=0; for _ in pairs(__timers) do n=n+1 end; return n end
local methods={}
function methods:getChildren() __walks=__walks+1; return self._children end
function methods:addEventListener(event,fn) self._nextListener=self._nextListener+1; self._listeners[self._nextListener]={event=event,fn=fn}; return self._nextListener end
function methods:removeEventListener(id) self._listeners[id]=nil end
function methods:setTheme(mode) self.theme=mode end
function methods:destroy() self.visible=false; self._dead=true end
function fireEvent(c,event,...) for _,x in pairs(c._listeners) do if x.event==event then x.fn(...) end end end
function newControl(t,name)
 __created=__created+1
  local state={class={tagName=t},name=name or '',visible=true,left=0,top=0,width=400,height=200,opacity=1,strokeSize=1,grid={role='none'},fontColor='#D8F8FF',color='#0B1118'}
  local c={_state=state,_children={},_listeners={},_nextListener=0}
  setmetatable(c,{__index=function(o,k) __reads=__reads+1; return methods[k] or o._state[k] end,
    __newindex=function(o,k,v)
      if k=='frameStyle' and o._state.class.tagName=='form' then error('Unknown property: FrameStyle') end
      if k=='parent' and v~=nil and o._state.parent~=v then v._children[#v._children+1]=o end
      o._state[k]=v; __writes=__writes+1
    end})
  return c
end
GUI={newRectangle=function() return newControl('rectangle') end,newImage=function() return newControl('image') end,newLabel=function() return newControl('label') end}
NDB={}
function NDB.getChildNodes(n) return type(n)=='table' and (n.__items or {}) or {} end
function NDB.isNodeObject(n) return type(n)=='table' end
function NDB.createChildNode(parent,name)
  assert(type(name)=="string" and name~="","Invalid node name")
  local n={__items={},__parent=parent,__name=name or "node"..tostring(#(parent.__items or {})+1)}; parent.__items=parent.__items or {}; parent.__items[#parent.__items+1]=n
  parent[n.__name]=n; return n
end
function NDB.deleteNode(n)
  local p=n.__parent; if not p then return end; for i,x in ipairs(p.__items or {}) do if x==n then table.remove(p.__items,i); break end end
end
function NDB.getParent(n) return n and n.__parent end
function NDB.getRoot(n) while n and n.__parent do n=n.__parent end; return n end
function showMessage(s) __messages[#__messages+1]=s end
Dialogs={showMessage=showMessage,showErrorMessage=showMessage,confirmYesNo=function(_,fn) fn(true) end}
Firecast={getMesaDe=function() return nil end}
_CACHE={['gui.lua']=GUI,['ndb.lua']=NDB,['rrpg.lua']=Firecast,['firecast.lua']=Firecast,['dialogs.lua']=Dialogs}
function require(name)
  if _CACHE[name]~=nil then return _CACHE[name] end
  local fn,err=loadfile(TEST_ROOT..'/'..name,'t',_ENV); if not fn then error(err) end
  local result=fn(); _CACHE[name]=result or true; return _CACHE[name]
end

function NDB.getNodeName(n) return n and n.__name or "root" end
