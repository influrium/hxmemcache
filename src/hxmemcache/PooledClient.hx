package hxmemcache;

import haxe.Exception;
import hxmemcache.ObjectPool;
import hxmemcache.serde.HaxeSerde;
import hxmemcache.Client;
import sys.net.Host;
import sys.thread.Mutex;
import haxe.ds.StringMap;


typedef PooledClientOptions = ClientOptions & {
    /**
     * maximum pool size to use
     * (going above this amount triggers a runtime error),
     * by default this is 2147483648L when not provided (or none).
     */
    var ?max_pool_size : Int;

    /**
     * a callback/type that takes no arguments
     * that will be called to create a lock or sempahore
     * that can protect the pool from concurrent access
     * (for example a eventlet lock or semaphore could be used instead)
     */
    var ?lock_generator : Void->Mutex;
}

/**
 * A thread-safe pool of clients (with the same client api).
 */
class PooledClient extends Client
{
    static var optionsDefault : PooledClientOptions = {

    };

    var poptions : PooledClientOptions;

    var clientPool : ObjectPool<Client>;

    public function new( host : Host, port : Int, ?options : PooledClientOptions )
    {
        super(host, port, options);

        var opts = options != null ? options : {};
        for (f in Reflect.fields(optionsDefault))
        {
            var v = Reflect.field(opts, f);
            if (v == null)
                Reflect.setField(opts, f, Reflect.field(optionsDefault, f));
        }
        this.poptions = opts;
        this.clientPool = new ObjectPool(createClient, afterRemove, poptions.max_pool_size, poptions.lock_generator);
    }

    function createClient( ) : Client
    {
        var opts = Reflect.copy(options);
        // We need to know when it fails *always*
        // so that we can remove/destroy it from the pool...
        opts.ignore_exc = false;

        return new Client(host, port, opts);
    }
    function afterRemove( client : Client ) : Void
    {
        client.close();
    }

    override public function close( ) : Void
    {
        clientPool.clear();
    }

    override public function set( key : String, value : Dynamic, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Bool
    {
        return clientPool.get_and_release(client -> client.set(key, value, expire, noreply, flags), true);
    }

    override public function setMany( values : StringMap<Dynamic>, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Array<String>
    {
        return clientPool.get_and_release(client -> client.setMany(values, expire, noreply, flags), true);
    }
    override public function setMulti( values : StringMap<Dynamic>, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Array<String>
        return setMany(values, expire, noreply, flags);

    override public function add( key : String, value : Dynamic, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Bool
    {
        return clientPool.get_and_release(client -> client.add(key, value, expire, noreply, flags), true);
    }

    override public function replace( key : String, value : Dynamic, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Bool
    {
        return clientPool.get_and_release(client -> client.replace(key, value, expire, noreply, flags), true);
    }

    override public function append( key : String, value : Dynamic, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Bool
    {
        return clientPool.get_and_release(client -> client.append(key, value, expire, noreply, flags), true);
    }

    override public function prepend( key : String, value : Dynamic, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Bool
    {
        return clientPool.get_and_release(client -> client.prepend(key, value, expire, noreply, flags), true);
    }

    override public function cas( key : String, value : Dynamic, cas : String, expire : Int = 0, noreply : Bool = false, ?flags : Int ) : Null<Bool>
    {
        return clientPool.get_and_release(client -> client.cas(key, value, cas, expire, noreply, flags), true);
    }

    override public function get<T>( key : String, ?def : T ) : T
    {
        var client = clientPool.get();
        var out = null;
        try
        {
            out = client.get(key, def);
            clientPool.release(client);
        }
        catch (e : Dynamic)
        {
            if (!options.ignore_exc)
            {
                clientPool.destroy(client);
                throw Exception.wrapWithStack(e);
            }
        }
        return out;
    }

    override public function getMany( keys : Array<String> ) : StringMap<Dynamic>
    {
        var client = clientPool.get();
        var out = new StringMap();
        try
        {
            out = client.getMany(keys);
            clientPool.release(client);
        }
        catch (e : Dynamic)
        {
            if (!options.ignore_exc)
            {
                clientPool.destroy(client);
                throw Exception.wrapWithStack(e);
            }
        }
        return out;
    }
    override public function getMulti( keys : Array<String> ) : StringMap<Dynamic> return getMany(keys);

    override public function gets<T>( key : String, ?def : T, ?cas_def : String ) : Casval<T>
    {
        var client = clientPool.get();
        var out = {
            value: null,
            cas: null
        };
        try
        {
            out = client.gets(key, def, cas_def);
            clientPool.release(client);
        }
        catch (e : Dynamic)
        {
            if (!options.ignore_exc)
            {
                clientPool.destroy(client);
                throw Exception.wrapWithStack(e);
            }
        }
        return out;
    }

    override public function getsMany( keys : Array<String> ) : StringMap<Casval<Dynamic>>
    {
        var client = clientPool.get();
        var out = new StringMap();
        try
        {
            out = client.getsMany(keys);
            clientPool.release(client);
        }
        catch (e : Dynamic)
        {
            if (!options.ignore_exc)
            {
                clientPool.destroy(client);
                throw Exception.wrapWithStack(e);
            }
        }
        return out;
    }

    override public function delete( key : String, ?noreply : Bool ) : Bool
    {
        return clientPool.get_and_release(client -> client.delete(key, noreply), true);
    }

    override public function deleteMany( keys : Array<String>, ?noreply : Bool ) : Bool
    {
        return clientPool.get_and_release(client -> client.deleteMany(keys, noreply), true);
    }
    override public function deleteMulti( keys : Array<String>, ?noreply : Bool ) : Bool return deleteMany(keys, noreply);

    override public function incr( key : String, value : Int, noreply : Bool = false ) : Null<Int>
    {
        return clientPool.get_and_release(client -> client.incr(key, value, noreply), true);
    }

    override public function decr( key : String, value : Int, noreply : Bool = false ) : Null<Int>
    {
        return clientPool.get_and_release(client -> client.decr(key, value, noreply), true);
    }

    override public function touch( key : String, expire : Int = 0, ?noreply : Bool ) : Bool
    {
        return clientPool.get_and_release(client -> client.touch(key, expire, noreply), true);
    }

    override public function stats( args : Array<String> ) : StringMap<Dynamic>
    {
        var client = clientPool.get();
        var out = new StringMap();
        try
        {
            out = client.stats(args);
            clientPool.release(client);
        }
        catch (e : Dynamic)
        {
            if (!options.ignore_exc)
            {
                clientPool.destroy(client);
                throw Exception.wrapWithStack(e);
            }
        }
        return out;
    }

    override public function cacheMemLimit( memlimit : Int ) : Bool
    {
        var client = clientPool.get();
        try
        {
            client.cacheMemLimit(memlimit);
            clientPool.release(client);
        }
        catch (e : Dynamic)
        {
            if (!options.ignore_exc)
            {
                clientPool.destroy(client);
                throw Exception.wrapWithStack(e);
            }
        }
        return true;
    }

    override public function version( ) : String
    {
        return clientPool.get_and_release(client -> client.version(), true);
    }

    override public function flush( delay : Int = 0, ?noreply : Bool ) : Bool
    {
        return clientPool.get_and_release(client -> client.flush(delay, noreply), true);
    }
    override public function flushAll( delay : Int = 0, ?noreply : Bool ) : Bool return flush(delay, noreply);

    override public function quit( ) : Void
    {
        var client = clientPool.get();
        try
        {
            client.quit();
        }
        catch (e : Dynamic)
        {

        }
        clientPool.destroy(client);
    }

}