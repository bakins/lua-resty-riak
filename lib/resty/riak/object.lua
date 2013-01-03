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
