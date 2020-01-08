package hxmemcache.proto;

import haxe.ds.StringMap;
import haxe.Exception;
import hxmemcache.Exception;


class Ascii extends Proto
{
    function storeCmd( name : String, values : StringMap<Dynamic>, expire : Int, noreply : Bool, ?flags : Int, ?cas : String ) : StringMap<Bool>
    {
        var cmds : Array<String> = [];
        var keys : Array<String> = [];

        var extra = '';
        if (cas != null) extra += ' ' + checkCas(cas);
        if (noreply) extra += ' noreply';

        var expires = checkInt(expire, "expire");
        for (key=>value in values)
        {
            // must be able to reliably map responses back to the original order
            keys.push(key);

            key = checkKey(key);
            var serval = options.serde.serialize(key, value);

            // If 'flags' was explicitly provided, it overrides the value returned by the serializer.
            if (flags != null)
                serval.flags = flags;
            
            cmds.push(name + ' ' + key + ' '
                + Std.string(serval.flags) + ' '
                + expires + ' '
                + Std.string(serval.value.length) + ' '
                + extra + '\r\n'
                + serval.value + '\r\n'
            );
        }

        if (socket == null)
            connect();
        
        try
        {
            // trace(cmds.join(''));
            socket.output.writeString(cmds.join(''));
            if (noreply)
                return [for(k in keys) k => true];
            
            var results : StringMap<Bool> = new StringMap();
            for (key in keys)
            {
                var line = socket.input.readLine();
                // trace(line);
                throwErrors(line, name);

                if (name == 'cas') switch (line)
                {
                    case 'STORED':      results.set(key, true);
                    case 'EXISTS':      results.set(key, false);
                    // case 'NOT_FOUND':   results.set(key, null);
                    case _: throw new MemcacheUnknownError(line.substr(0, 32));
                }
                else switch (line)
                {
                    case 'STORED':      results.set(key, true);
                    case 'NOT_STORED':  results.set(key, false);
                    case _: throw new MemcacheUnknownError(line.substr(0, 32));
                }
            }

            return results;
        }
        catch (e : haxe.Exception)
        {
            close();
            throw e;
        }
        catch (e : Dynamic)
        {
            close();
            throw Exception.wrapWithStack(e);
        }

        return null;
    }

    function fetchCmd( name : String, keys : Array<String>, expectCas : Bool ) : StringMap<Dynamic>
    {
        var prefixedKeys = [];
        var remappedKeys = new StringMap();
        for(k in keys)
        {
            var pk = checkKey(k);
            prefixedKeys.push(pk);
            remappedKeys.set(pk, k);
        }

        // It is important for all keys to be listed in their original order.
        var cmd = name + ' ' + prefixedKeys.join(' ') + '\r\n';

        try
        {
            if (socket == null)
                connect();
            
            // trace(cmd);
            socket.output.writeString(cmd);

            var result = new StringMap();
            while (true)
            {
                var line = socket.input.readLine();
                // trace(line);
                throwErrors(line, name);

                if (line == 'END' || line == 'OK')
                    return result;
                
                else if (line.substr(0, 'VALUE'.length) == 'VALUE')
                {
                    var kv = extractValue(expectCas, line, remappedKeys, prefixedKeys);
                    result.set(kv.key, kv.value);
                }
                else if (name == 'stats' && line.substr(0, 'STAT'.length) == 'STAT')
                {
                    var kv = line.split(' ');
                    result.set(kv[1], kv[2]);
                }
                else if (name == 'stats' && line.substr(0, 'ITEM'.length) == 'ITEM')
                {
                    // For 'stats cachedump' commands
                    var kv = line.split(' ');
                    kv.shift();
                    result.set(kv.shift(), kv.join(' '));
                }
                else
                    throw new MemcacheUnknownError(line.substr(0, 32));
            }
        }
        catch (e : haxe.Exception)
        {
            close();
            if (!options.ignore_exc)
                throw e;
        }
        catch (e : Dynamic)
        {
            close();
            if (!options.ignore_exc)
                throw Exception.wrapWithStack(e);
        }

        return new StringMap();
    }

    function miscCmd( cmds : Array<String>, cmd_name : String, noreply : Bool ) : Array<String>
    {
        if (socket == null)
            connect();
        
        try
        {
            socket.output.writeString(cmds.join(''));

            if (noreply)
                return [];
            
            var results = [];
            for (cmd in cmds)
            {
                var line = socket.input.readLine();
                throwErrors(line, cmd_name);
                results.push(line);
            }
            return results;
        }
        catch (e : haxe.Exception)
        {
            close();
            throw e;
        }
        catch (e : Dynamic)
        {
            close();
            throw Exception.wrapWithStack(e);
        }

        return null;
    }


    /**
     * Check that a value is a valid input for 'cas' -- either an int or a string containing only 0-9 
     * The value will be (re)encoded so that we can accept strings or bytes.
     */
    function checkCas( cas : String ) : String
    {
        if (!caser.match(cas))
            throw new MemcacheIllegalInputError('cas must only contain values in 0-9, got bad value: $cas');
        
        return cas;
    }
    static var caser : EReg = ~/^\d+$/;

    /**
     * Check that a value is an integer and encode it as a binary string
     */
    function checkInt( i : Int, name : String ) : String
    {
        return Std.string(i);
    }

    inline function throwErrors( line : String, name : String ) : Void
    {
        if (line.substr(0, 'ERROR'.length) == 'ERROR')
            throw new MemcacheUnknownCommandError('$name: $line');

        if (line.substr(0, 'CLIENT_ERROR'.length) == 'CLIENT_ERROR')
        {
            // var error = line.substr(line.indexOf(' ') + 1);
            throw new MemcacheClientError('$name: $line');
        }

        if (line.substr(0, 'SERVER_ERROR'.length) == 'SERVER_ERROR')
        {
            // var error = line.substr(line.indexOf(' ') + 1);
            throw new MemcacheServerError('$name: $line');
        }
    }

    function extractValue( expectCas : Bool, line : String, remappedKeys : StringMap<String>, prefixedKeys : Array<String> ) : { key : String, value : Dynamic }
    {
        var key : String = '';
        var flags : Int = 0;
        var size : Int = 0;
        var cas : String = '';

        var parts : Array<String> = line.split(' ');
        try
        {
            if (expectCas)
                cas = parts.pop();
            size = Std.parseInt(parts.pop());
            flags = Std.parseInt(parts.pop());
            key = parts.pop();
        }
        catch (e : Dynamic)
        {
            throw new Exception('Unable to parse line: $line - $e', e);
        }

        var value = socket.input.readString(size + 2); // + \r\n
        var origKey = remappedKeys.get(key);
        var origValue = options.serde.deserialize(origKey, value.substr(0, size), flags);

        return {
            key: origKey,
            value: expectCas ? {value: origValue, cas: cas} : origValue
        };
    }
}