package hxmemcache;

typedef Serde = {
    function serialize( key : String, value : Dynamic ) : Serval;
    function deserialize( key : String, value : String, flags : Int ) : Dynamic;
};
