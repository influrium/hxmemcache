package hxmemcache;

import haxe.Exception;
import haxe.Timer;
import haxe.ds.StringMap;
import sys.net.Host;
import hxmemcache.hash.*;
import hxmemcache.Client;
import hxmemcache.Exception;

#if target.threaded
import hxmemcache.PooledClient;
#end


typedef HashClientOptions = #if target.threaded PooledClientOptions #else ClientOptions #end & {
    var ?hasher : Hasher;
    var ?retry_attempts : Int;
    var ?retry_timeout : Int;
    var ?dead_timeout : Int;
    var ?use_pooling : Bool;
};

typedef FailedServer = Server & {
    var failed_time : Float;
    var attempts : Int;
};
typedef DeadServer = Server & {
    var deadTime : Float;
};


/**
 * A client for communicating with a cluster of memcached servers
 */
class HashClient extends Client
{
    static var optionsDefault : HashClientOptions = {
        hasher: new RendezvousHash(),
        retry_attempts: 2,
        retry_timeout: 1,
        dead_timeout: 60,
        use_pooling: false,
    };

    var hoptions : HashClientOptions;

    var hasher : Hasher;
    var clients : StringMap<Client>;
    var failedServers : StringMap<FailedServer>;
    var deadServers : Array<DeadServer>;
    var lastDeadCheckTime : Float;

    public function new( servers : Array<Server>, options : HashClientOptions )
    {
        super(null, 0, null);

        var opts = options != null ? options : {};
        for (f in Reflect.fields(optionsDefault))
        {
            var v = Reflect.field(opts, f);
            if (v == null)
                Reflect.setField(opts, f, Reflect.field(optionsDefault, f));
        }
        this.hoptions = opts;
        
        this.hasher = hoptions.hasher;
        this.clients = new StringMap();
        this.failedServers = new StringMap();
        this.deadServers = [];
        this.lastDeadCheckTime = Timer.stamp();

        for (server in servers)
            addServer(server);
    }

    public function addServer( server : Server ) : Void
    {
        var serkey = '${server.host}:${server.port}';
#if target.threaded
        var client = hoptions.use_pooling ? new PooledClient(server.host, server.port, hoptions) : new Client(server.host, server.port, hoptions);
#else
        var client = new Client(server.host, server.port, hoptions);
#end

        clients.set(serkey, client);
        hasher.addNode(serkey);
    }

    public function removeServer( server : Server ) : Void
    {
        var serkey = '${server.host}:${server.port}';
        
        failedServers.remove(serkey);
        deadServers.push({
            host: host,
            port: port,
            deadTime: Timer.stamp()
        });
        hasher.removeNode(serkey);
    }

    function getClient( key : String ) : Client
    {
        checkKey(key);
        checkDead();
        var serkey = hasher.getNode(key);
        // We've ran out of servers to try
        if (serkey == null && !hoptions.ignore_exc)
                throw new MemcacheError('All servers seem to be down right now');

        return clients.get(serkey);
    }

    function checkDead( ) : Void
    {
        if (deadServers.length < 1)
            return;
        
        var curtime = Timer.stamp();
        if ((curtime - lastDeadCheckTime) < hoptions.dead_timeout)
            return;
        
        // we have dead clients and we have reached the timeout retry
        for (ds in deadServers)
            if ((curtime - ds.deadTime) > hoptions.dead_timeout)
            {
#if debug
                trace('bringing server back into rotation: ${ds.host}:${ds.port}');
#end
                addServer(ds);
                lastDeadCheckTime = Timer.stamp();
            }
    }

    function runCmd<A>( key : String, cmd : Client->A, ?def : A ) : Null<A>
    {
        var client = getClient(key);
        if (client == null)
            throw new MemcacheError('No available servers');
        
        return execCmd(client, cmd, def);
    }

    function execCmd<A>( client : Client, cmd : Client->A, ?def : A ) : Null<A>
    {
        var serkey = '${client.host}:${client.port}';
        
        var exc : Exception = null;
        try
        {
            var fs = failedServers.get(serkey);
            // This server is currently failing, lets check if it is in retry or marked as dead
            if (fs != null)
            {
                if (fs.attempts < hoptions.retry_attempts)
                {
                    if ((Timer.stamp() - fs.failed_time) > hoptions.retry_timeout)
                    {
#if debug
                        trace('retrying failed server: $serkey');
#end
                        var result = cmd(client);

                        // we were successful, lets remove it from the failed clients
                        failedServers.remove(serkey);

                        return result;
                    }
                }
                else
                {
                    // We've reached our max retry attempts, we need to mark the sever as dead
#if debug
                    trace('marking server as dead: $serkey');
#end
                    removeServer(client.server);
                }

                return def;
            }

            return cmd(client);
        }
        catch (e: haxe.io.Eof)
        {
            // Reading from the server fail, we should enter retry mode
            markFailedServer(client.server);
            
            exc = new Exception("Reading from the server fail, we should enter retry mode", e);
        }
        catch (e: haxe.io.Error)
        {
            // Connecting to the server fail, we should enter retry mode
            markFailedServer(client.server);
            
            exc = new Exception("Connecting to the server fail, we should enter retry mode", e);
        }
        catch (e: Exception)
        {
            exc = e;
        }

        // any exceptions we need to handle gracefully as well
        if (!hoptions.ignore_exc)
            throw exc;
        
        return def;
    }

    function markFailedServer( server : Server ) : Void
    {
        var serkey = '${server.host}:${server.port}';

        if (!failedServers.exists(serkey))
        {
            failedServers.set(serkey, {
                host: server.host,
                port: server.port,
                attempts: 0,
                failed_time: Timer.stamp()
            });

            if (hoptions.retry_attempts < 1)
            {
#if debug
                trace('marking server as dead: ${server.host}:${server.port}');
#end
                removeServer(server);
            }
        }
        else
        {
            var fs = failedServers.get(serkey);
            fs.attempts++;
            fs.failed_time = Timer.stamp();
        }
    }


    override public function checkKey( key : String ) : String
    {
        return Client.checkKeyRules(key, hoptions.allow_unicode_keys, hoptions.key_prefix);
    }

    override public function close( ) : Void
    {
        for (client in clients)
            client.close();
    }

    override public function set( key : String, value : Dynamic, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Bool
    {
        return runCmd(key, client -> client.set(key, value, expire, noreply, flags), false);
    }

    override public function setMany( values : StringMap<Dynamic>, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Array<String>
    {
        var failed = [];
        var batches : StringMap<StringMap<Dynamic>> = new StringMap();
        for (key=>value in values.keyValueIterator())
        {
            var client = getClient(key);
            if (client == null)
            {
                failed.push(key);
                continue;
            }
            var server = client.server;
            var serkey = '${server.host}:${server.port}';
            if (!batches.exists(serkey))
                batches.set(serkey, new StringMap());
            batches.get(serkey).set(key, value);
        }

        for (serkey=>values in batches.keyValueIterator())
        {
            var client = clients.get(serkey);
            var result = execCmd(client, client -> client.setMany(values, expire, noreply, flags));
            for (key in result)
                failed.push(key);
        }

        return failed;
    }
    override public function setMulti( values : StringMap<Dynamic>, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Array<String>
    {
        return setMany(values, expire, noreply, flags);
    }

    override public function add( key : String, value : Dynamic, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Bool
    {
        return runCmd(key, client -> client.add(key, value, expire, noreply, flags), false);
    }

    override public function replace( key : String, value : Dynamic, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Bool
    {
        return runCmd(key, client -> client.replace(key, value, expire, noreply, flags), false);
    }

    override public function append( key : String, value : Dynamic, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Bool
    {
        return runCmd(key, client -> client.append(key, value, expire, noreply, flags), false);
    }

    override public function prepend( key : String, value : Dynamic, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Bool
    {
        return runCmd(key, client -> client.prepend(key, value, expire, noreply, flags), false);
    }

    override public function cas( key : String, value : Dynamic, cas : String, expire : Int = 0, noreply : Bool = false, ?flags : Int ) : Null<Bool>
    {
        return runCmd(key, client -> client.cas(key, value, cas, expire, noreply, flags), false);
    }

    override public function get<T>( key : String, ?def : T ) : T
    {
        return runCmd(key, client -> client.get(key, def), def);
    }

    override public function getMany( keys : Array<String> ) : StringMap<Dynamic>
    {
        var out : StringMap<Dynamic>= new StringMap();
        var batches : StringMap<Array<String>> = new StringMap();
        for (key in keys)
        {
            var client = getClient(key);
            if (client == null)
            {
                // out.set(key, false);
                continue;
            }
            var server = client.server;
            var serkey = '${server.host}:${server.port}';
            if (!batches.exists(serkey))
                batches.set(serkey, []);
            batches.get(serkey).push(key);
        }

        for (serkey=>keys in batches.keyValueIterator())
        {
            var client = clients.get(serkey);
            var result = execCmd(client, client -> client.getMany(keys));
            for (key=>value in result.keyValueIterator())
                out.set(key, value);
        }

        return out;
    }
    override public function getMulti( keys : Array<String> ) : StringMap<Dynamic> return getMany(keys);

    override public function gets<T>( key : String, ?def : T, ?cas_def : String ) : Casval<T>
    {
        return runCmd(key, client -> client.gets(key, def, cas_def));
    }

    override public function getsMany( keys : Array<String> ) : StringMap<Casval<Dynamic>>
    {
        var out : StringMap<Casval<Dynamic>> = new StringMap();
        var batches : StringMap<Array<String>> = new StringMap();
        for (key in keys)
        {
            var client = getClient(key);
            if (client == null)
            {
                // out.set(key, false);
                continue;
            }
            var server = client.server;
            var serkey = '${server.host}:${server.port}';
            if (!batches.exists(serkey))
                batches.set(serkey, []);
            batches.get(serkey).push(key);
        }

        for (serkey=>keys in batches.keyValueIterator())
        {
            var client = clients.get(serkey);
            var result = execCmd(client, client -> client.getsMany(keys));
            for (key=>value in result.keyValueIterator())
                out.set(key, value);
        }

        return out;
    }

    override public function delete( key : String, ?noreply : Bool ) : Bool
    {
        return runCmd(key, client -> client.delete(key, noreply));
    }

    override public function deleteMany( keys : Array<String>, ?noreply : Bool ) : Bool
    {
        for (key in keys)
            delete(key, noreply);
        return true;
    }
    override public function deleteMulti( keys : Array<String>, ?noreply : Bool ) : Bool return deleteMany(keys, noreply);

    override public function incr( key : String, value : Int, noreply : Bool = false ) : Null<Int>
    {
        return runCmd(key, client -> client.incr(key, value, noreply));
    }

    override public function decr( key : String, value : Int, noreply : Bool = false ) : Null<Int>
    {
        return runCmd(key, client -> client.decr(key, value, noreply));
    }

    override public function touch( key : String, expire : Int = 0, ?noreply : Bool ) : Bool
    {
        return runCmd(key, client -> client.touch(key, expire, noreply));
    }

    override public function stats( args : Array<String> ) : StringMap<Dynamic>
    {
        return new StringMap();
    }

    override public function cacheMemLimit( memlimit : Int ) : Bool
    {
        for (client in clients)
            execCmd(client, client -> client.cacheMemLimit(memlimit));
        return true;
    }

    override public function version( ) : String
    {
        var vs = [];
        for (client in clients)
            vs.push('${client.host}:${client.port} - ' + execCmd(client, client -> client.version(), ''));
        return vs.join('\n');
    }

    override public function flush( delay : Int = 0, ?noreply : Bool ) : Bool
    {
        for (client in clients)
            execCmd(client, client -> client.flush(delay, noreply));
        return true;
    }
    override public function flushAll( delay : Int = 0, ?noreply : Bool ) : Bool
    {
        return flush(delay, noreply);
    }

    override public function quit( ) : Void
    {
        for (client in clients)
        {
            execCmd(client, function(client) {client.quit(); return null;});
            removeServer(client.server);
        }
    }
}
