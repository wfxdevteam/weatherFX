--[[
  state manager
  collects all intent before flushing to FFI. decouples weather logic from ac.set* calls.
  modules write to nova.state, then nova.flush() diffs against last frame and only crosses
  the FFI boundary for values that actually changed
]]

local nova = {
  state = {},
  _lastApplied = {},
  _modules = {},
  --[[
  _schema = {},
  _transformers = {},
  ]]
  _flushCount = 0
}

--[[
called by other modules to register ffi endpoints
]]
function nova.registerModule(moduleName, schema)
  nova._modules[moduleName] = schema
end

--[[

local function setState()
end

local function setSchema()
  nova._schema = {
    trackHeatFactor = { fn = ac.setTrackHeatFactor, type = 'num' },
  }
end

local function setTransformers()
end

]]

--[[
initialize nested state tables with prealloc memory
]]
function nova.init()
  for modName, schema in pairs(nova._modules) do
    nova.state[modName] = {}
    nova._lastApplied[modName] = {}

    for key, def in pairs(schema) do
      if def.type == 'num' then
        nova.state[modName][key] = def.default or 0
        -- force update on first flush
        nova._lastApplied[modName][key] = math.nan
      elseif def.type == 'bool' then
        nova.state[modName][key] = def.default or false
        nova._lastApplied[modName][key] = not nova.state[modName][key]
      elseif def.type == 'rgb' then
        -- prealloc so we can mutate later
        local d = def.default or { 0, 0, 0 }
        nova.state[modName][key] = rgb(d[1], d[2], d[3])
        nova._lastApplied[modName][key] = rgb(-1, -1, -1)
      elseif def.type == 'vec3' then
        -- prealloc so we can mutate later
        local d = def.default or { 0, 0, 0 }
        nova.state[modName][key] = vec3(d[1], d[2], d[3])
        nova._lastApplied[modName][key] = vec3(-math.huge, -math.huge, -math.huge)
      end
    end
  end
end

--[[
diff current state against last applied, and flush to ffi if changed
]]
function nova.flush()
  local count = 0

  for modName, schema in pairs(nova._modules) do
    local modState = nova.state[modName]
    local modLast = nova._lastApplied[modName]

    if modState and modLast then
      for key, def in pairs(schema) do
        local changed = false
        local val = modState[key]
        local last = modLast[key]

        if def.type == 'num' or def.type == 'bool' then
          if val ~= last then
            changed = true
            modLast[key] = val
          end
        elseif def.type == 'rgb' then
          if val.r ~= last.r or val.g ~= last.g or val.b ~= last.b then
            changed = true
            -- mutate existing
            last:set(val)
          end
        elseif def.type == 'vec3' then
          if val.x ~= last.x or val.y ~= last.y or val.z ~= last.z then
            changed = true
            -- mutate existing
            last:set(val)
          end
        end

        -- if change detected, push across ffi boundary
        if changed then
          local finalVal = val
          if def.transformer then
            finalVal = def.transformer(val)
          end
          def.fn(finalVal)
          count = count + 1
        end
      end
    end
  end

  nova._flushCount = count
  if count > 0 then
    --[[monitor how many ffi calls happen per frame]]
    ac.debug('Nova FFI calls/frame', count)
  end
end

return nova
