package mock;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.Encoding;
import sys.net.Host;

private class SocketOutput extends haxe.io.Output
{
	var values : Array<String>;

	public function new( )
	{
		this.values = [];
	}

	override function writeString( s : String, ?encoding : Encoding ) : Void
	{
		values.push(s);
	}
}

class Socket extends sys.net.Socket
{
	public function new( values : Array<String> )
	{
		super();

		this.output = new SocketOutput();
		this.input = new BytesInput(Bytes.ofString(values.join('')));
	}

	/**
		Closes the socket : make sure to properly close all your sockets or you will crash when you run out of file descriptors.
	**/
	override public function close( ) : Void
	{

	}

	/**
		Read the whole data available on the socket.

		*Note*: this is **not** meant to be used together with `setBlocking(false)`,
		as it will always throw `haxe.io.Error.Blocked`. `input` methods should be used directly instead.
	**/
	override public function read( ) : String
	{
		return "";
	}

	/**
		Write the whole data to the socket output.

		*Note*: this is **not** meant to be used together with `setBlocking(false)`, as
		`haxe.io.Error.Blocked` may be thrown mid-write with no indication of how many bytes have been written.
		`output.writeBytes()` should be used instead as it returns this information.
	**/
	override public function write( content : String ) : Void
	{

	}

	/**
		Connect to the given server host/port. Throw an exception in case we couldn't successfully connect.
	**/
	override public function connect( host : Host, port : Int ) : Void
	{

	}

	/**
		Allow the socket to listen for incoming questions. The parameter tells how many pending connections we can have until they get refused. Use `accept()` to accept incoming connections.
	**/
	override public function listen( connections : Int ) : Void
	{

	}

	/**
		Shutdown the socket, either for reading or writing.
	**/
	override public function shutdown( read : Bool, write : Bool ) : Void
	{

	}

	/**
		Bind the socket to the given host/port so it can afterwards listen for connections there.
	**/
	override public function bind( host : Host, port : Int ) : Void
	{

	}

	/**
		Accept a new connected client. This will return a connected socket on which you can read/write some data.
	**/
	override public function accept( ) : Socket
	{
		return null;
	}

	/**
		Return the information about the other side of a connected socket.
	**/
	override public function peer( ) : {host:Host, port:Int}
	{
		return null;
	}

	/**
		Return the information about our side of a connected socket.
	**/
	override public function host( ) : {host:Host, port:Int}
	{
		return null;
	}

	/**
		Gives a timeout (in seconds) after which blocking socket operations (such as reading and writing) will abort and throw an exception.
	**/
	override public function setTimeout( timeout : Float ) : Void
	{

	}

	/**
		Block until some data is available for read on the socket.
	**/
	override public function waitForRead( ) : Void
	{

	}

	/**
		Change the blocking mode of the socket. A blocking socket is the default behavior. A non-blocking socket will abort blocking operations immediately by throwing a haxe.io.Error.Blocked value.
	**/
	override public function setBlocking( b : Bool ) : Void
	{

	}

	/**
		Allows the socket to immediately send the data when written to its output : this will cause less ping but might increase the number of packets / data size, especially when doing a lot of small writes.
	**/
	override public function setFastSend( b : Bool ) : Void
	{
		
	}
}