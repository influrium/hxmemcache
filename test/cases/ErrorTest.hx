package cases;

import hxmemcache.*;
import hxmemcache.Client;
import hxmemcache.Exception;

import utest.Test;
import utest.Assert;


class ErrorTest extends Test
{
    var mainClient : Client;

    function makeClient( ?options : ClientOptions ) : Client
    {
        return Main.makeClient(options);
    }

    function setupClass( )
    {
        mainClient = makeClient();
    }

    function setup( )
    {
        mainClient.flushAll();
    }

    function test_key_with_ws( )
    {
        var client = makeClient();
        Assert.raises(function(){
            client.set('key with spaces', 'value', false);
        }, MemcacheIllegalInputError);
    }

    function test_key_with_illegal_carriage_return( )
    {
        var client = makeClient();
        Assert.raises(function(){
            client.set('\r\nflush_all', 'value', false);
        }, MemcacheIllegalInputError);
    }

    function test_key_too_long( )
    {
        var client = makeClient();
        Assert.raises(function(){
            client.set(StringTools.rpad('ke', 'y', 1024), 'value', false);
        }, MemcacheClientError);
    }

    function test_unicode_key_in_set( )
    {
        var client = makeClient();
        Assert.raises(function(){
            client.set('\u0FFF', 'value', false);
        }, MemcacheClientError);
    }

    function test_unicode_key_in_get( )
    {
        var client = makeClient();
        Assert.raises(function(){
            client.get('\u0FFF');
        }, MemcacheClientError);
    }

/*
    function test_unicode_value_in_set( )
    {
        var client = makeClient();
        Assert.raises(function(){
            client.set('key', '\u0FFF', false);
        }, MemcacheClientError);
    }
*/
}