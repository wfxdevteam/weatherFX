--[[
  state manager
  collects all intent before flushing to FFI. decouples weather logic from ac.set* calls.
  modules write to nova.state, then nova.flush() diffs against last frame and only crosses
  the FFI boundary for values that actually changed
]]

local nova = {
  state = {},
  _lastApplied = {},
  _schema = {},
  _transformers = {},
  _flushCount = 0,
}

local function setState()
end

local function setSchema()
  nova._schema = {
    trackHeatFactor = { fn = ac.setTrackHeatFactor, type = 'num' },
  }
end

local function setTransformers()
end

function nova.init()
  setSchema()

  for key, entry in pairs(nova._schema) do
    if entry.type == 'num' then
      nova._lastApplied[key] = math.nan
    end
  end
end

function nova.flush()
  local s = nova.state
  local last = nova._lastApplied
  local count = 0

  for key, value in pairs(s) do
    local entry = nova._schema[key]
    if entry then
      local changed = false

      if entry.type == 'num' then
        changed = value ~= last[key]
      end

      if changed then
        local finalValue = value
        local transformer = nova._transformers[key]
        if transformer then
          finalValue = transformer(finalValue)
        end
        entry.fn(finalValue)
        last[key] = finalValue
        count = count + 1
      end
    end
  end

  nova._flushCount = count
  if count > 0 then
    ac.debug('nova.flush', string.format("%.3f: %d value(s)", os.preciseClock(), count))
  end
end

return nova
