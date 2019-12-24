package hxmemcache;

typedef Casval<T> = {
    var value : T;
    var cas : String;
}