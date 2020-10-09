package mock;

import sys.net.Host;
import haxe.Exception;
import hxmemcache.Client;


class Client extends hxmemcache.Client
{
	var values : Array<String>;

	public function new( values : Array<String>,  host : Host, port : Int, ?options : ClientOptions )
	{
		this.values = values;

		super(host, port, options);
	}

	override function connect( )
	{
		close();

		var socket = new Socket(values);

		/* 
		 * Useless
		try
		{
			if (options.connect_timeout != null) socket.setTimeout(options.connect_timeout);
			socket.connect(host, port);
			if (options.timeout != null) socket.setTimeout(options.timeout);
			socket.setFastSend(options.no_delay);
		}
		catch (e : Dynamic)
		{
			socket.close();
			throw Exception.wrapWithStack(e);
		}
		*/

		this.socket = socket;

		authenticate(options.username, options.password);
	}
}