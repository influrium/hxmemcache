package cases;

import hxmemcache.Client;

class PrefixedPooledClientTest extends PrefixedClientTest
{
    override function makeClient( ?options : ClientOptions )
    {
        if (options == null)
            options = {};
        options.key_prefix = 'xyz:';

        return Main.makePooledClient(cast options);
    }
}