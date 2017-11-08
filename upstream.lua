function redis2()
	local redis_host = "127.0.0.1"
	local redis_port = 6379
	local redis_connection_timeout = 3
        local redis = require "resty.redis"
        local red = redis:new()
        red:set_timeout(redis_connect_timeout)
        local ok, err = red:connect(redis_host, redis_port)
        if not ok then
                ngx.log(ngx.ERR, "Redis connection error while retrieving server_cache: " .. err)
        end 
	
	return red
end

function redis3()
	local redis_host = "192.168.8.155"
	local redis_port = 6379
	local redis_connection_timeout = 3
        local redis = require "resty.redis"
        local red = redis:new()
        red:set_timeout(redis_connect_timeout)
        local ok, err = red:connect('unix:////var/run/redis/redis.sock')
        if not ok then
                ngx.log(ngx.ERR, "Redis connect sock  error : " .. err)
		local ok, err = red:connect(redis_host, redis_port)
		red:set_timeout(redis_connect_timeout)
		if not ok then
			ngx.log(ngx.ERR, "Redis connect tcp error : " .. err)
		end
        end 
	
	return red
end

function set_server(prkey,server_cache,server_locks)
	local redis_key = prkey
	local pr = redis_key
	local red = redis3()
        -- local key, err = red:SRANDMEMBER(redis_key)
        local key, err = red:SMEMBERS(redis_key)
        if err then
                ngx.log(ngx.ERR, "Redis read error while retrieving server_cache: " .. err)
        else
                --server_cache:flush_all()
		--ngx.say("flush_all")
		local resty_lock = require "resty.lock"
		local lock, err = resty_lock:new("server_locks" , { timeout = 1 } )
                if not lock then
                    ngx.log(ngx.ERR, "failed to create lock: " .. err)
                end
		local elapsed, err = lock:lock(pr.."flags")
	        if not elapsed then
	            return fail("failed to acquire the lock: ", err)
	        end	

		server_cache:set(pr.."flags",1)



--		local j , err = tonumber(server_cache:get(pr.."total") + 1)
		local j = tonumber(server_cache:get(pr.."total"))
		if j == nil  or j == 0 then
			j = 1
		end
		for i = 1 , j   do 
			server_cache:delete(pr..i)
		--	ngx.say("delete")
		end
                server_cache:set(pr.."total",#(key))
                for index, valid_ip in ipairs(key) do
                	server_cache:set(pr..index,valid_ip)
                end
		server_cache:set(pr.."last_update_time", ngx.now())
		server_cache:set(pr.."flags",0)
		
		local ok, err = lock:unlock()
                if not ok then
                    ngx.log(ngx.ERR , "failed to unlock: " .. err)
                end
        end

	return true

end

function get_server(prkey,server_cache)
	local server_cache = server_cache
	local redis_key = prkey
	local pr = prkey
	if server_cache:get(pr.."flags") == nil or server_cache:get(pr.."flags") == 1 then
		local red = redis3()
		local key, err = red:SRANDMEMBER(redis_key)
	        if err then
         		ngx.log(ngx.ERR, "Redis read error while retrieving server_cache: " .. err)
        	else
			return key
		end
	else	
		local i , err = math.random(server_cache:get(pr.."total"))	
		if err then
			i = 1
		end
		local host = server_cache:get(pr..i)
		--ngx.say(server_cache:get(pr..i))
		return host
	end
end


function get_server2(prkey)
        local red = redis3()
        local redis_key = prkey
        local key, err = red:SRANDMEMBER(redis_key)
	-- ngx.log(ngx.ERR, "get_server2 : " .. redis_key .. " ,  IP :" .. key  )
        if err then
                ngx.log(ngx.ERR, "Redis read error while retrieving server_cache: " .. err)
        else
                return key
        end

end


local prkey = ngx.var.pr
local cache_ttl = 5
local server_cache = ngx.shared.server_cache
local last_update_time = server_cache:get(prkey.."last_update_time")
--ngx.say(server_cache:get("last_update_time"))
if last_update_time == nil or last_update_time < ( ngx.now() - cache_ttl ) or server_cache:get(prkey.."flags") == nil then
	local ok, err = set_server(prkey,server_cache,server_locks)
	if not ok then
		ngx.log(ngx.ERR, "set server failed : " .. err)
	end
end



local host,err = get_server(prkey,server_cache)
if err then
	ngx.log(ngx.ERR, "get server failed : " .. err)
end

--ngx.say(host)

--local host = server_cache:get(pr..i)
--ngx.say(server_cache:get(pr..i))
--ngx.var.proxy_to = "http://"..host..":8080"
ngx.var.proxy_to = host

