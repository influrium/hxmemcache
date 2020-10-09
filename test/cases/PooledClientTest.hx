package cases;

import utest.Assert;

import hxmemcache.Client;
import hxmemcache.PooledClient;
import hxmemcache.Exception;


class PooledClientTest extends BaseTest
{
    override function makeClient( ?values : Array<String>, ?options : ClientOptions )
    {
        if (options == null)
            options = {};
        
        return Main.makePooledClient(cast options);
    }
}