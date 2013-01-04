local _M = {}

local mt = { 
    __index = _M 
}

function _M.new(bucket, key)
    local o = {
        bucket = bucket,
        key = key,
        meta = {}
    }
    return setmetatable(o,  mt)
end

-- horrible name - load from a "raw" riak response
function _M.load(bucket, key, response)
    local content = response.content
    if "table" == type(content) then
        content = content[1]
    else
        return nil, "bad content"
    end

    local object = {
        key = key,
        bucket = bucket,
        --vclock = response.vclock,
        value = content.value,
        charset = content.charset,
        content_encoding =  content.content_encoding,
        content_type = content.content_type,
        last_mod = content.last_mod
    }
              
    local meta = {}
    if content.usermeta then 
        for _,m in ipairs(content.usermeta) do
            meta[m.key] = m.value
        end
    end
    object.meta = meta
    return setmetatable(object,  mt)
end

function _M.store(self)
    return self.bucket.client:store_object(self)
end

function _M.reload(object)
    return self.bucket.client:reload_object(self)
end

function _M.delete(self)
    local key = self.key
    if not key then
        return nil
    end
    return self.bucket:delete_object(key)
end

return _M
