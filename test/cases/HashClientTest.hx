package cases;

import utest.Assert;

import hxmemcache.Client;
import hxmemcache.Exception;


class HashClientTest extends BaseTest
{
    override function makeClient( ?values : Array<String>, ?options : ClientOptions )
    {
        if (options == null)
            options = {};
        
        return Main.makeHashClient(3, cast options);
    }
}