--[[
Copyright 2017 Rackspace

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]
local HostInfo = require('./base').HostInfo
local jsonParse = require('json').parse
local uv = require('uv')

--[[ Info ]]--
local Info = HostInfo:extend()
function Info:initialize()
  HostInfo.initialize(self)
end

function Info:_run(callback)
  self._params = {}
  local params = self._params
  local child, pid
  local stdout = uv.new_pipe(false)
  local count = 2

  local function finish(err)
    if not child:is_closing() then child:close() end
    if not stdout:is_closing() then stdout:close() end
    return callback(err)
  end

  child, pid = uv.spawn("lshw", {
    args = {"-json"},
    stdio = {nil, stdout}
  }, function (code, signal)
    if code ~= 0 then
      return finish("lshw exited with exit code " .. code)
    end
    count = count - 1
    if count == 0 then
      finish()
    end
  end)
  if not child then
    stdout:close()
    if pid:match("^ENOENT:") then
      error "Cannot find `lshw` in system path"
    end
    error(pid)
  end
  local chunks = {}
  stdout:read_start(function (err, chunk)
    assert(not err, err)
    if chunk then
      chunks[#chunks + 1] = chunk
      return
    end
    params.info = jsonParse(table.concat(chunks))
    count = count - 1
    if count == 0 then
      finish()
    end
  end)

end

function Info:getType()
  return 'LSHW'
end

function Info:getPlatforms()
  return {'linux'}
end


return Info
