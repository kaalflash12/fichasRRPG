local nodes={}
local function node(parent,name)
  local n={};nodes[n]={parent=parent,name=name,children={}}
  if parent then nodes[parent].children[#nodes[parent].children+1]=n;parent[name]=n end
  return n
end
local N={}
function N.newMemNodeDatabase() return node(nil,'root') end
function N.createChildNode(parent,name) assert(name and parent[name]==nil);return node(parent,name) end
function N.getChildNodes(n) return nodes[n].children end
function N.testPermission() return true end
function N.exportXML(n)
  local a={};for k,v in pairs(n) do if type(v)~='table' then a[#a+1]=k..'='..tostring(v) end end
  table.sort(a);return table.concat(a,';')
end
local cache={['ndb.lua']=N,['gui.lua']={}}
function require(name)
  if cache[name]~=nil then return cache[name] end
  local file=assert(loadfile(TEST_ROOT..'/'..name,'t',_ENV))
  local result=file();cache[name]=result;return result
end
