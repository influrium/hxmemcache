package cases;

import haxe.ds.StringMap;

import utest.Test;
import utest.Assert;

import hxmemcache.*;
import hxmemcache.Client;
import hxmemcache.Exception;


class BaseTest extends Test
{
    var mainClient : Client;

    function makeClient( ?values : Array<String>, ?options : ClientOptions ) : Client
    {
        return Main.makeClient(values, options);
    }

    function makeCustomizedClient( ?values : Array<String>, ?options : ClientOptions ) : Client
    {
        return Main.makeCustomizedClient(options);
    }

    function setupClass( )
    {
        mainClient = makeClient();
    }

    function setup( )
    {
        mainClient.flushAll();
    }



    function test_set_success( )
    {
        var client = makeClient(['STORED\r\n']);
        var result = client.set('key', 'value', false);
        Assert.isTrue(result);

        // unit test for encoding passed in __init__()
        var client = makeClient(['STORED\r\n'], {encoding: 'utf-8'});
        var result = client.set('key', 'value', false);
        Assert.isTrue(result);

        // unit test for set operation with parameter flags
        var client = makeClient(['STORED\r\n'], {encoding: 'utf-8'});
        var result = client.set('key', 'value', false, 0x00000030);
        Assert.isTrue(result);
    }

    function test_set_unicode_key( )
    {
        var client = makeClient(['STORED\r\n']);
        Assert.raises(function(){
            client.set('\u1f18e', 'value', false);
        }, MemcacheIllegalInputError);
    }

    function test_set_unicode_key_ok( )
    {
        var client = makeClient(['STORED\r\n'], {allow_unicode_keys: true});
        var result = client.set('\u1f18e', 'value', false);
        Assert.isTrue(result);
    }

    function test_set_unicode_key_ok_snowman( )
    {
        var client = makeClient(['STORED\r\n'], {allow_unicode_keys: true});
        var result = client.set('my☃', 'value', false);
        Assert.isTrue(result);
    }

    function test_set_unicode_char_in_middle_of_key( )
    {
        var client = makeClient(['STORED\r\n']);
        Assert.raises(function(){
            client.set('helloworld_\u00b1901520_%c3', 'value', false);
        }, MemcacheIllegalInputError);
    }

    function test_set_unicode_char_in_middle_of_key_snowman( )
    {
        var client = makeClient(['STORED\r\n']);
        Assert.raises(function(){
            client.set('my☃', 'value', false);
        }, MemcacheIllegalInputError);
    }

    function test_set_unicode_char_in_middle_of_key_ok( )
    {
        var client = makeClient(['STORED\r\n'], {allow_unicode_keys: true});
        var result = client.set('helloworld_\u00b1901520_%c3', 'value', false);
        Assert.isTrue(result);
    }

/*
    // no checks to test yet
    function test_set_unicode_value( )
    {
        var client = makeClient();
        Assert.raises(function(){
            client.set('key', '\u1f18e', false);
        }, MemcacheIllegalInputError);
    }
*/

    function test_set_noreply( )
    {
        var client = makeClient();
        var result = client.set('key', 'value', true);
        Assert.isTrue(result);

        // unit test for encoding passed in __init__()
        var client = makeClient({encoding: 'utf-8'});
        var result = client.set('key', 'value', true);
        Assert.isTrue(result);
    }

    function test_set_many_success( )
    {
        var client = makeClient();
        var result = client.setMany(['key' => 'value'], false);
        Assert.same([], result);

        // unit test for encoding passed in __init__()
        var client = makeClient({encoding: 'utf-8'});
        var result = client.setMany(['key' => 'value'], false);
        Assert.same([], result);
    }

    function test_set_multi_success( )
    {
        var client = makeClient();
        var result = client.setMulti(['key' => 'value'], false);
        Assert.same([], result);

        // unit test for encoding passed in __init__()
        var client = makeClient({encoding: 'utf-8'});
        var result = client.setMulti(['key' => 'value'], false);
        Assert.same([], result);
    }

    function test_add_stored( )
    {
        var client = makeClient(['STORED\r', '\n']);
        var result = client.add('key', 'value', false);
        Assert.isTrue(result);

        client.flush();

        // unit test for encoding passed in __init__()
        var client = makeClient(['STORED\r', '\n'], {encoding: 'utf-8'});
        var result = client.add('key', 'value', false);
        Assert.isTrue(result);
    }

    function test_add_not_stored( )
    {
        var client = makeClient();
        client.add('key', 'value', false);
        var result = client.add('key', 'value', false);
        Assert.isFalse(result);

        // unit test for encoding passed in __init__()
        var client = makeClient({encoding: 'utf-8'});
        client.add('key', 'value', false);
        var result = client.add('key', 'value', false);
        Assert.isFalse(result);
    }


    function test_get_not_found( )
    {
        var client = makeClient();
        var result = client.get('key');
        Assert.isNull(result);

        // Unit test for customized client (override _extract_value)
        var client = makeCustomizedClient();
        var result = client.get('key');
        Assert.isNull(result);
    }

    function test_get_not_found_default( )
    {
        var client = makeClient();
        var result = client.get('key', 'foobar');
        Assert.equals('foobar', result);

        // Unit test for customized client (override _extract_value)
        var client = makeCustomizedClient();
        var result = client.get('key', 'foobar');
        Assert.equals('foobar', result);
    }

    function test_get_found( )
    {
        var client = makeClient();
        client.set('key', 'value', false);
        var result = client.get('key');
        Assert.equals('value', result);

        // Unit test for customized client (override _extract_value)
        var client = makeCustomizedClient();
        client.set('key', 'value', false);
        var result = client.get('key');
        Assert.equals('value', result);
    }

    function test_get_many_none_found( )
    {
        var client = makeClient();
        var result = client.getMany(['key1', 'key2']);
        Assert.same(new StringMap(), result);
    }

    function test_get_multi_none_found( )
    {
        var client = makeClient();
        var result = client.getMulti(['key1', 'key2']);
        Assert.same(new StringMap(), result);
    }

    function test_get_many_some_found( )
    {
        var client = makeClient();
        client.set('key1', 'value1', false);
        var result = client.getMany(['key1', 'key2']);
        Assert.same(['key1' => 'value1'], result);
    }

    function test_get_many_all_found( )
    {
        var client = makeClient();
        client.set('key1', 'value1', false);
        client.set('key2', 'value2', false);
        var result = client.getMany(['key1', 'key2']);
        Assert.same(['key1' => 'value1', 'key2' => 'value2'], result);
    }

    function test_get_unicode_key( )
    {
        var client = makeClient();
        Assert.raises(function(){
            client.get('\u1f18e');
        }, MemcacheIllegalInputError);
    }


    function test_delete_not_found( )
    {
        var client = makeClient();
        var result = client.delete('key', false);
        Assert.isFalse(result);
    }

    function test_delete_found( )
    {
        var client = makeClient();
        client.add('key', 'value', false);
        var result = client.delete('key', false);
        Assert.isTrue(result);
    }

    function test_delete_noreply( )
    {
        var client = makeClient();
        var result = client.delete('key', true);
        Assert.isTrue(result);
    }

    function test_delete_many_no_keys( )
    {
        var client = makeClient();
        var result = client.deleteMany([], false);
        Assert.isTrue(result);
    }

    function test_delete_many_none_found( )
    {
        var client = makeClient();
        var result = client.deleteMany(['key'], false);
        Assert.isTrue(result);
    }

    function test_delete_many_found( )
    {
        var client = makeClient();
        client.add('key', 'value', false);
        var result = client.deleteMany(['key'], false);
        Assert.isTrue(result);
    }

    function test_delete_many_some_found( )
    {
        var client = makeClient();
        client.add('key', 'value', false);
        var result = client.deleteMany(['key', 'key2'], false);
        Assert.isTrue(result);
    }

    function test_delete_multi_some_found( )
    {
        var client = makeClient();
        client.add('key', 'value', false);
        var result = client.deleteMulti(['key', 'key2'], false);
        Assert.isTrue(result);
    }


    function test_incr_not_found( )
    {
        var client = makeClient();
        var result = client.incr('key', 1, false);
        Assert.isNull(result);
    }

    function test_incr_found( )
    {
        var client = makeClient();
        client.set('key', 0, false);
        var result = client.incr('key', 1, false);
        Assert.equals(1, result);
    }

    function test_incr_noreply( )
    {
        var client = makeClient();
        client.set('key', 0, false);
        
        var client = makeClient();
        var result = client.incr('key', 1, true);
        Assert.isNull(result);
    }

    function test_decr_not_found( )
    {
        var client = makeClient();
        var result = client.decr('key', 1, false);
        Assert.isNull(result);
    }

    function test_decr_found( )
    {
        var client = makeClient();
        client.set('key', 2, false);
        var result = client.decr('key', 1, false);
        Assert.equals(1, result);
    }

}