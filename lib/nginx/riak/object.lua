local _M = {}

local mt = {}

function _M.new(bucket, key)
    local o = {
        bucket = bucket,
        key = key,
        meta = {}
    }
    setmetatable(o,  { __index = mt })
    return o
end

function _M.get(bucket, key)
    local request = {
        bucket = bucket.name,
        key = key
    }
    local o, err =  bucket.client:GetReq(request)
    if not o then
        return nil, err
    end
    o.key = key
    setmetatable(o,  { __index = mt })
    return o
end

function mt.store(self)
    if not self.content_type then
        return nil, "content_type is required"
    end
    
    if not self.key then
        return nil, "only support named keys for now"
    end
    
    local meta = {}
    for k,v in pairs(self.meta) do
        insert(meta, { key = k, value = v })
    end
    
    local bucket = self.bucket

    local request = {
        bucket = bucket.name,
        key = self.key,
        --vclock = self.vclock,
        content = {
            value = self.value or "",
            content_type = self.content_type,
            charset = self.charset,
            content_encoding = self.content_encoding, 
            usermeta = meta
        }
    }
    return bucket.client:PutReq(request)
end

function mt.delete(self)
    return self.bucket:delete(self.key)
end

return _M
