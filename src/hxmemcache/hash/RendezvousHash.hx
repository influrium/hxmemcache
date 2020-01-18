package hxmemcache.hash;

import haxe.Exception;

class RendezvousHash
{
    var nodes : Array<String>;
    var seed : Int;
    var hashFunc : String->Null<Int>->Int;

    public function new( ?nodes : Array<String>, seed : Int = 0, ?hashFunc : String->Null<Int>->Int )
    {
        this.nodes = nodes != null ? nodes : [];
        this.seed = seed;
        this.hashFunc = hashFunc != null ? hashFunc : HashFunc.murmur3_32;
    }

    public function addNode( node : String ) : Void
    {
        if (nodes.indexOf(node) < 0)
            nodes.push(node);
    }
    public function removeNode( node : String ) : Void
    {
        if (!nodes.remove(node))
            throw new Exception('No such node "$node" to remove');
    }
    public function getNode( key : String ) : String
    {
        var high = -1;
        var winner = null;

        for (node in nodes)
        {
            var score = hashFunc('$node-$key', seed);
            if (score > high)
            {
                high = score;
                winner = node;

            }
            else if (score == high)
            {
                high = score;
                winner = winner > node ? winner : node;
            }
        }
        
        return winner;
    }
}