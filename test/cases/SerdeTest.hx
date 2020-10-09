package cases;

import haxe.Json;
import hxmemcache.Serval;
import hxmemcache.serde.HaxeSerde;

import utest.Test;
import utest.Assert;


class SerdeTest extends Test
{
    function test_serialization_deserialization( )
    {
        var client = Main.makeClient();

        var value = {a: 'b', 'c': ['d'], e: {f: 1, g: true, h: 0.001}};
        client.set('key', value);
        var result = client.get('key');
        Assert.same(value, result);
    }

    function test_custom_serialization_deserialization( )
    {
        var client = Main.makeClient({serde: new JsonSerde()});

        var value = {a: 'b', 'c': ['d'], e: {f: 1, g: true, h: 0.001}};
        client.set('key', value);
        var result = client.get('key');
        Assert.same(value, result);
    }
}

class JsonSerde extends HaxeSerde
{
    override function serializeValue(key:String, value:Dynamic):String {
        return Json.stringify(value);
    }

    override function deserializeValue(key:String, value:String, flags:Int) {
        return Json.parse(value);
    }
}