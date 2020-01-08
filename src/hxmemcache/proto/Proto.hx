package hxmemcache.proto;

import sys.net.Socket;
import sys.net.Host;
import haxe.ds.StringMap;
import haxe.Exception;


class Proto
{
    var host : Host;
    var port : Int;

    var socket : Socket;

    public function new( host : Host, port : Int )
    {
        this.host = host;
        this.port = port;

        this.socket = null;
    }

    public function connect( ?connect_timeout : Float, ?timeout : Float, no_delay : Bool = false ) : Void
    {
        // var socket = options.ssl_socket ? new sys.ssl.Socket() : new Socket();
        var socket = new Socket();

        try
        {
            if (connect_timeout != null) socket.setTimeout(connect_timeout);
            socket.connect(host, port);
            if (timeout != null) socket.setTimeout(timeout);
            socket.setFastSend(no_delay);
        }
        catch (e : Dynamic)
        {
            socket.close();
            throw Exception.wrapWithStack(e);
        }

        this.socket = socket;
    }

    public function close( ) : Void
    {
        if (socket == null)
            return;
        
        try socket.close() catch (e : Dynamic){}

        socket = null;
    }

    public function set( key : String, value : Dynamic, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Bool { throw new Exception('Not implemented'); return null; }
    public function setMany( values : StringMap<Dynamic>, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Array<String> { throw new Exception('Not implemented'); return null; }
    public function add( key : String, value : Dynamic, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Bool
    public function replace( key : String, value : Dynamic, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Bool

    public function append( key : String, value : Dynamic, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Bool
    public function prepend( key : String, value : Dynamic, expire : Int = 0, ?noreply : Bool, ?flags : Int ) : Bool


    
}