import sys.net.Host;
import utest.Runner;
import utest.ui.Report;

import cases.*;
import hxmemcache.Client;
#if target.threaded
import hxmemcache.PooledClient;
#end

class Main
{
    static var params : {
        host : Host,
        port : Int,
        ?user : String,
        ?pass : String,
    };

    public static function main( ) : Void
    {
        params = {
            host: new Host('localhost'),
            port: 11211,
        };

        var arg = Sys.args()[0];
        if (arg != null && arg.indexOf("memcached://") == 0)
        {
            var reg = ~/^([^:]+):\/\/(([^:]+):([^@]*?)@)?([^:\/]+)(:([0-9]+))?\/?$/;

            if (!reg.match(arg))
                throw "Configuration requires a valid database attribute, format is : memcached://user:password@host:port";

            var user = reg.matched(3);
            var pass = reg.matched(4);
            var host = reg.matched(5);
            var port = reg.matched(7);

            params = {
                host: new Host(host),
                port: port != null ? Std.parseInt(port) : params.port,
                user: user,
                pass: pass
            };
        }

        var runner = new Runner();

        runner.addCase(new ClientTest());
        runner.addCase(new PrefixedClientTest());
        runner.addCase(new SerdeTest());
        runner.addCase(new ErrorTest());
#if target.threaded
        runner.addCase(new PooledClientTest());
        runner.addCase(new PrefixedPooledClientTest());
#end
        Report.create(runner);
        runner.run();
    }

    public static function makeClient( ?options : ClientOptions )
    {
        if (options == null) options = {};
        if (params.user != null) options.username = params.user;
        if (params.pass != null) options.password = params.pass;
        return new Client(params.host, params.port, options);
    }
    public static function makeCustomizedClient( ?options : ClientOptions )
    {
        if (options == null) options = {};
        if (params.user != null) options.username = params.user;
        if (params.pass != null) options.password = params.pass;
        return new mock.CustomizedClient(params.host, params.port, options);
    }
#if target.threaded
    public static function makePooledClient( ?options : PooledClientOptions )
    {
        if (options == null) options = {};
        if (params.user != null) options.username = params.user;
        if (params.pass != null) options.password = params.pass;
        return new PooledClient(params.host, params.port, options);
    }
#end
}