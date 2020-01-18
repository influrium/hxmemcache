package cases;

import utest.Assert;

import hxmemcache.Client;
import hxmemcache.Exception;


class HashClientTest extends BaseTest
{
    override function makeClient( ?options : ClientOptions )
    {
        if (options == null)
            options = {};
        
        return Main.makeHashClient(3, cast options);
    }
}