package hxmemcache.serde;

import haxe.io.Bytes;
import haxe.Unserializer;
import haxe.Serializer;
import hxmemcache.Serde;

enum abstract HaxeSerdeFlag(Int) from Int to Int
{
    var FLAG_INT    = 0;
    var FLAG_FLOAT  = 1 << 0;
    var FLAG_BOOL   = 1 << 1;
    var FLAG_BYTES  = 1 << 2;
    var FLAG_STRING = 1 << 3;
    var FLAG_SERIAL = 1 << 4;
}

class HaxeSerde
{
    public function new( )
    {
        
    }

    public function serialize( key : String, value : Dynamic ) : Serval
    {
        return switch(Type.typeof(value))
        {
            case TInt:   { value: Std.string(value), flags: FLAG_INT };
            case TFloat: { value: Std.string(value), flags: FLAG_FLOAT };
            case TBool:  { value: (value : Bool) ? '1' : '0', flags: FLAG_BOOL };
            case TClass(Bytes): { value: (value : Bytes).toHex(), flags: FLAG_BYTES };
            case TClass(String): { value: value, flags: FLAG_STRING };
            case _: { value: serializeValue(key, value), flags: FLAG_SERIAL };
        }
    }

    public function deserialize( key : String, value : String, flags : Int ) : Dynamic 
    {
        var flag : HaxeSerdeFlag = flags;
        return switch(flag)
        {
            case FLAG_INT: Std.parseInt(value);
            case FLAG_FLOAT: Std.parseInt(value);
            case FLAG_BOOL: value == '1';
            case FLAG_BYTES: Bytes.ofHex(value);
            case FLAG_STRING: value;
            case FLAG_SERIAL: deserializeValue(key, value, flags);
        }
    }

    function serializeValue( key : String, value : Dynamic ) return Serializer.run(value);
    function deserializeValue( key : String, value : String, flags : Int ) return Unserializer.run(value);

}