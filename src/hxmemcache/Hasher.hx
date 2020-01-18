package hxmemcache;

typedef Hasher = {
    function addNode( node : String ) : Void;
    function removeNode( node : String ) : Void;
    function getNode( key : String ) : String;
}