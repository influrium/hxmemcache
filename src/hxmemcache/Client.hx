package hxmemcache;

import haxe.io.BytesBuffer;
import haxe.ds.StringMap;

import sys.net.Host;

import haxe.Exception;
import hxmemcache.Exception;
import hxmemcache.serde.*;
import hxmemcache.proto.*;

using hxmemcache.Client;

typedef ClientOptions = {
    var ?username : String;
    var ?password : String;
    var ?memcachier_auth : Bool;
    var ?serde : Serde;
    var ?connect_timeout : Float; //Seconds
    var ?timeout : Float; //Seconds
    var ?no_delay : Bool;
    var ?ignore_exc : Bool;
    // var ?ssl_socket : Bool;
    var ?key_prefix : String;
    var ?default_noreply : Bool;
    var ?allow_unicode_keys : Bool;
    var ?encoding : String;
    var ?is_binary : Bool;
};


class Client
{
    static var optionsDefault : ClientOptions = {
        memcachier_auth: false,
        serde: new HaxeSerde(),
        no_delay: false,
        ignore_exc: false,
        // ssl_socket: false,
        key_prefix: '',
        default_noreply: true,
        allow_unicode_keys: false,
        encoding: 'ascii',
        is_binary: false,
    };

    var options : ClientOptions;
    var proto : Proto;

    public function new( host : Host, port : Int, ?options : ClientOptions )
    {
        options = options != null ? Reflect.copy(options) : {};
        for (f in Reflect.fields(optionsDefault))
        {
            var v = Reflect.field(options, f);
            if (v == null)
                Reflect.setField(options, f, Reflect.field(optionsDefault, f));
        }
        this.options = options;

        this.proto = this.options.is_binary ? new Binary(host, port) : new Ascii(host, port);
    }

    public function checkKey( key : String ) : String
    {
        return checkKeyRules(key, options.allow_unicode_keys, options.key_prefix);
    }

    public function connect( )
    {
        close();

        proto.connect(options.connect_timeout, options.timeout, options.no_delay);

        authenticate(options.username, options.password);
    }

    function authenticate( username : String, password : String ) : Void
    {
        if (username == null || password == null)
            return;
        
        if (options.memcachier_auth)
            set(username, password);
        else
            set('authentication', '$username $password');
    }


    /**
     * Close the connection to memcached, if it is open.
     * The next call to a method that requires a connection will re-open it.
     */
    public function close( ) : Void
    {
        proto.close();
    }

    /**
     * If no exception is throwed, always returns True.
     * If an exception is throwed, the set may or may not have occurred.
     * If noreply is True, then a successful return does not guarantee a successful set.
     */
    public function set( key : String, value : Dynamic, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Bool
    {
        noreply = noreply != null ? noreply : options.default_noreply;
        
        return storeCmd('set', [key=>value], expire, noreply, flags).get(key);
    }

    /**
     * Returns am Array of keys that failed to be inserted.
     * If noreply is True, always returns empty list.
     */
    public function setMany( values : StringMap<Dynamic>, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Array<String>
    {
        noreply = noreply != null ? noreply : options.default_noreply;
        
        var result = storeCmd('set', values, expire, noreply, flags);

        return [for(k=>v in result.keyValueIterator()) if(!v) k];
    }
    public function setMulti( values : StringMap<Dynamic>, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Array<String>
        return setMany(values, expire, noreply, flags);

    /**
     * If ``noreply`` is True (or if it is unset and ``options.default_noreply`` is True),
     * the return value is always True.
     * Otherwise the return value is True if the value was stored,
     * and False if it was not (because the key already existed).
     */
    public function add( key : String, value : Dynamic, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Bool
    {
        noreply = noreply != null ? noreply : options.default_noreply;
        
        return storeCmd('add', [key=>value], expire, noreply, flags).get(key);
    }

    /**
     * If ``noreply`` is True (or if it is unset and ``self.default_noreply`` is True),
     * the return value is always True.
     * Otherwise returns True if the value was stored and False if it wasn't
     * (because the key didn't already exist).
     */
    public function replace( key : String, value : Dynamic, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Bool
    {
        noreply = noreply != null ? noreply : options.default_noreply;

        return storeCmd('replace', [key=>value], expire, noreply, flags).get(key);
    }

    /**
     * Returns: True.
     */
    public function append( key : String, value : Dynamic, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Bool
    {
        noreply = noreply != null ? noreply : options.default_noreply;

        return storeCmd('append', [key=>value], expire, noreply, flags).get(key);
    }

    /**
     * Returns: True.
     */
    public function prepend( key : String, value : Dynamic, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Bool
    {
        noreply = noreply != null ? noreply : options.default_noreply;

        return storeCmd('prepend', [key=>value], expire, noreply, flags).get(key);
    }

    /**
     * If ``noreply`` is True (or if it is unset and ``self.default_noreply`` is True),
     * the return value is always True.
     * Otherwise returns None if the key didn't exist,
     * False if it existed but had a different cas value and
     * True if it existed and was changed.
     */
    public function cas( key : String, value : Dynamic, cas : String, expire : Int = 0, noreply : Bool = false, ?flags : Int ) : Null<Bool>
    {
        return storeCmd('cas', [key=>value], expire, noreply, flags, cas).get(key);
    }

    /**
     * The value for the key, or default if the key wasn't found.
     */
    public function get<T>( key : String, ?def : T ) : T
    {
        return fetchCmd('get', [key], false).getOrDefault(key, def);
    }

    /**
     * A StringMap in which the keys are elements of the "keys" argument list
     * and the values are values from the cache.
     * The StringMap may contain all, some or none of the given keys.
     */
    public function getMany( keys : Array<String> ) : StringMap<Dynamic>
    {
        if (keys.length < 1)
            return new StringMap();
        return fetchCmd('get', keys, false);
    }
    public function getMulti( keys : Array<String> ) : StringMap<Dynamic> return getMany(keys);

    /**
     * A tuple of (value, cas) or (default, cas_defaults) if the key was not found.
     */
    public function gets<T>( key : String, ?def : T, ?cas_def : String ) : Casval<T>
    {
        var casdef : Casval<T> = {
            value: def,
            cas: cas_def
        };

        return fetchCmd('gets', [key], true).getOrDefault(key, casdef);
    }

    /**
     * A dict in which the keys are elements of the "keys" argument list
     * and the values are tuples of (value, cas) from the cache.
     * The dict may contain all, some or none of the given keys.
     */
    public function getsMany( keys : Array<String> ) : StringMap<Casval<Dynamic>>
    {
        return cast fetchCmd('gets', keys, true);
    }


    /**
     * If ``noreply`` is True (or if it is unset and ``self.default_noreply`` is True),
     * the return value is always True.
     * Otherwise returns True if the key was deleted, and False if it wasn't found.
     */
    public function delete( key : String, ?noreply : Bool ) : Bool
    {
        noreply = noreply != null ? noreply : options.default_noreply;

        var cmd = 'delete ' + checkKey(key) + (noreply ? ' noreply' : '') + '\r\n';
        var results = miscCmd([cmd], 'delete', noreply);
        return noreply ? true : results[0] == 'DELETED';
    }

    /**
     * Returns: True.
     * If an exception is raised then all, some or none of the keys may have been deleted.
     * Otherwise all the keys have been sent to memcache for deletion and if noreply is False,
     * they have been acknowledged by memcache.
     */
    public function deleteMany( keys : Array<String>, ?noreply : Bool ) : Bool
    {
        if (keys.length < 1)
            return true;
        
        noreply = noreply != null ? noreply : options.default_noreply;

        var cmds = [];
        for (key in keys)
            cmds.push('delete ' + checkKey(key) + (noreply ? ' noreply' : '') + '\r\n');
        
        miscCmd(cmds, 'delete', noreply);
        return true;
    }
    public function deleteMulti( keys : Array<String>, ?noreply : Bool ) : Bool return deleteMany(keys, noreply);

    /**
     * Returns:
     * If noreply is True, always returns None.
     * Otherwise returns the new value of the key, or None if the key wasn't found.
     */
    public function incr( key : String, value : Int, noreply : Bool = false ) : Null<Int>
    {
        var k = checkKey(key);
        var v = checkInt(value, 'value');
        var cmd = 'incr $k $v' + (noreply ? ' noreply' : '') + '\r\n';
        var results = miscCmd([cmd], 'incr', noreply);
        return noreply || results[0] == 'NOT_FOUND' ? null : Std.parseInt(results[0]);
    }

    /**
     * Returns:
     * If noreply is True, always returns None.
     * Otherwise returns the new value of the key, or None if the key wasn't found.
     */
    public function decr( key : String, value : Int, noreply : Bool = false ) : Null<Int>
    {
        var k = checkKey(key);
        var v = checkInt(value, 'value');
        var cmd = 'decr $k $v' + (noreply ? ' noreply' : '') + '\r\n';
        var results = miscCmd([cmd], 'decr', noreply);
        return noreply || results[0] == 'NOT_FOUND' ? null : Std.parseInt(results[0]);
    }

    /**
     * Returns: 
     * True if the expiration time was updated, False if the key wasn't found.
     */
    public function touch( key : String, expire : Int = 0, ?noreply : Bool ) : Bool
    {
        noreply = noreply != null ? noreply : options.default_noreply;

        var k = checkKey(key);
        var e = checkInt(expire, 'expire');
        var cmd = 'touch $k $e' + (noreply ? ' noreply' : '') + '\r\n';
        var results = miscCmd([cmd], 'touch', noreply);
        return noreply ? true : results[0] == 'TOUCHED';
    }

    public function stats( args : Array<String> ) : StringMap<Dynamic>
    {
        var result = fetchCmd('stats', args, false);

        var out = new StringMap();
        for (key=>value in result)
        {
            var conv : String->Dynamic = Stats.STAT_TYPES.get(key);
            out.set(key, conv(value));
        }
        return out;
    }

    /**
     * Returns:
     * If no exception is raised, always returns True.
     * @param memlimit the number of megabytes to set as the new cache memory limit.
     */
    public function cacheMemLimit( memlimit : Int ) : Bool
    {
        var lim = checkInt(memlimit, 'memlimit');
        fetchCmd('cache_memlimit', [lim], false);
        return true;
    }

    public function version( ) : String
    {
        var cmd = 'version\r\n';
        var results = miscCmd([cmd], 'version', false);
        var parts = results[0].split(' ');

        if (parts[0] != 'VERSION')
            throw new MemcacheUnknownError('Received unexpected response: ${results[0]}');
        
        return parts[2];
    }

    public function flush( delay : Int = 0, ?noreply : Bool ) : Bool
    {
        noreply = noreply != null ? noreply : options.default_noreply;

        var delays = checkInt(delay, 'delay');
        var cmd = 'flush_all ' + delays + (noreply ? ' noreply' : '') + '\r\n';
        
        var results = miscCmd([cmd], 'flush_all', noreply);

        return noreply ? true : results[0] == 'OK';
    }
    public function flushAll( delay : Int = 0, ?noreply : Bool ) : Bool return flush(delay, noreply);

    /**
     * The memcached "quit" command. 
     * 
     * This will close the connection with memcached.
     * Calling any other method on this object will re-open the connection,
     * so this object can be re-used after quit.
     */
    public function quit( )
    {
        miscCmd(["quit\r\n"], 'quit', true);
        close();
    }


    static var erPrintableASCII : EReg = ~/^[\x20-\x7E]*$/;
    /**
     * Checks key and add key_prefix.
     */
    static function checkKeyRules( key : String, allow_unicode_keys : Bool, key_prefix : String = '' ) : String
    {
        if (!allow_unicode_keys)
        {
            if (!erPrintableASCII.match(key))
                throw new MemcacheIllegalInputError('Non-ASCII key: $key');
        }

        var k : String = key_prefix + key;
        var parts = k.split(' ');

        if (k.length > 250)
            throw new MemcacheIllegalInputError('Key is too long: $k');
        
        else if (parts.length > 1 || parts[0] != k)
            throw new MemcacheIllegalInputError('Key contains whitespace: $k');
        
        else if (k.indexOf('\x00') > -1)
            throw new MemcacheIllegalInputError('Key contains null: $k');

        return k;
    }

    inline static function getOrDefault<T>( sm : StringMap<Dynamic>, key : String, def : T ) : T
    {
        var v = sm.get(key);
        return v != null ? v : def;
    }
}