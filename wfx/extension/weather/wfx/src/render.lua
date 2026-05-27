-- render cb subscription system
-- exact same as render.lua from base

local skyListeners = {}
local cloudListeners = {}
local trackListeners = {}

local function updateSubscriptions()
  local mSky, mCloud, mTrack = 0, 0, 0
  for _, e in ipairs(skyListeners) do mSky = bit.bor(mSky, e.mask) end
  for _, e in ipairs(cloudListeners) do mCloud = bit.bor(mCloud, e.mask) end
  for _, e in ipairs(trackListeners) do mTrack = bit.bor(mTrack, e.mask) end
  ac.enableRenderCallback(mSky, mCloud, mTrack, 0)
end

function script.renderSky(passID, frameIndex, uniqueKey)
  for _, e in ipairs(skyListeners) do
    if bit.band(e.mask, passID) ~= 0 then
      e.fn(passID, frameIndex, uniqueKey)
    end
  end
end

function script.renderClouds(passID, frameIndex, uniqueKey)
  for _, e in ipairs(cloudListeners) do
    if bit.band(e.mask, passID) ~= 0 then
      e.fn(passID, frameIndex, uniqueKey)
    end
  end
end

function script.renderTrack(passID, frameIndex, uniqueKey)
  for _, e in ipairs(trackListeners) do
    if bit.band(e.mask, passID) ~= 0 then
      e.fn(passID, frameIndex, uniqueKey)
    end
  end
end

---@param mask render.PassID
---@param fn fun(passID: render.PassID, frameIndex: integer, uniqueKey: integer)
---@param priority integer?
---@return fun() unsubscribe
function RenderSkySubscribe(mask, fn, priority)
  if mask == 0 then return function() end end
  local e = { mask = mask, fn = fn, priority = priority or 0 }
  skyListeners[#skyListeners + 1] = e
  table.sort(skyListeners, function(a, b) return a.priority > b.priority end)
  updateSubscriptions()
  return function()
    table.removeItem(skyListeners, e)
    updateSubscriptions()
  end
end

---@param mask render.PassID
---@param fn fun(passID: render.PassID, frameIndex: integer, uniqueKey: integer)
---@return fun() unsubscribe
function RenderCloudsSubscribe(mask, fn)
  if mask == 0 then return function() end end
  local e = { mask = mask, fn = fn }
  cloudListeners[#cloudListeners + 1] = e
  updateSubscriptions()
  return function()
    table.removeItem(cloudListeners, e)
    updateSubscriptions()
  end
end

---@param mask render.PassID
---@param fn fun(passID: render.PassID, frameIndex: integer, uniqueKey: integer)
---@return fun() unsubscribe
function RenderTrackSubscribe(mask, fn)
  if mask == 0 then return function() end end
  local e = { mask = mask, fn = fn }
  trackListeners[#trackListeners + 1] = e
  updateSubscriptions()
  return function()
    table.removeItem(trackListeners, e)
    updateSubscriptions()
  end
end
