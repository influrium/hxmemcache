package cases;

import hxmemcache.Client;


class PrefixedClientTest extends BaseTest
{
    override function makeClient( ?options : ClientOptions ) : Client
    {
        if (options == null)
            options = {};
        options.key_prefix = 'xyz:';

        return Main.makeClient(options);
    }
}