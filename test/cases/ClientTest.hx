package cases;

import haxe.ds.StringMap;

import utest.Test;
import utest.Assert;

import hxmemcache.*;
import hxmemcache.Client;
import hxmemcache.Exception;


class ClientTest extends BaseTest
{
    function test_append_stored( )
    {
        var client = makeClient();
        client.set('key', 'value');
        var result = client.append('key', 'value', false);
        Assert.isTrue(result);

        var client = makeClient({encoding: 'utf-8'});
        // client.set('key', 'value');
        var result = client.append('key', 'value', false);
        Assert.isTrue(result);
    }

    function test_prepend_stored( )
    {
        var client = makeClient();
        client.set('key', 'value');

        var result = client.prepend('key', 'value', false);
        Assert.isTrue(result);

        var client = makeClient({encoding: 'utf-8'});
        // client.set('key', 'value');
        var result = client.prepend('key', 'value', false);
        Assert.isTrue(result);
    }

    function test_cas_malformed( )
    {
        var client = makeClient();

        Assert.raises(function(){
            client.cas('key', 'value', 'nonintegerstring', false);
        }, MemcacheIllegalInputError);

        Assert.raises(function(){
            // even a space makes it a noninteger string
            client.cas('key', 'value', '123 ', false);
        }, MemcacheIllegalInputError);

        Assert.raises(function(){
            // non-ASCII digit
            client.cas('key', 'value', '⁰', false);
        }, MemcacheIllegalInputError);
    }
}