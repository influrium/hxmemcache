package hxmemcache;

import haxe.Exception;
import sys.thread.Mutex;

/**
 * A pool of objects that release/creates/destroys as needed.
 */
class ObjectPool<T>
{
    var usedObjs : List<T>;
    var freeObjs : List<T>;

    var creator : Void->T;
    var lock : Mutex;
    var after_remove : T->Void;
    var max_size : Int;

    public function new( creator : Void->T, ?after_remove : T->Void, ?max_size : Int, ?lock_generator : Void->Mutex )
    {
        this.usedObjs = new List();
        this.freeObjs = new List();
        this.creator = creator;

        this.lock = lock_generator != null ? lock_generator() : new Mutex();
        this.after_remove = after_remove;
        this.max_size = max_size != null && max_size > 0 ? max_size : 2 ^ 31;
    }

    public function get_and_release<A>( cb : T->A, ?destroy_on_fail : Bool = false ) : A
    {
        var obj = get();
        try
        {
            var out = cb(obj);
            release(obj);
            return out;
        }
        catch( e : Exception )
        {
            if (destroy_on_fail)
                release(obj);
            else
                destroy(obj);

            throw e;
        }

        return null;
    }

    public function get( ) : T
    {
        lock.acquire();
        var freeLen = freeObjs.length;
        if (freeObjs.length < 1)
        {
            var usedLen = usedObjs.length;
            if (usedLen >= max_size)
            {
                lock.release();
                throw new Exception('Too many objects, $usedLen >= $max_size');
            }
        }
        var obj = freeLen < 1 ? creator() : freeObjs.pop();
        usedObjs.add(obj);
        lock.release();
        return obj;
    }

    public function destroy( obj : T ) : Void
    {
        lock.acquire();
        var was_dropped = usedObjs.remove(obj);
        if (was_dropped && after_remove != null)
            after_remove(obj);
        lock.release();
    }

    public function release( obj : T ) : Void
    {
        lock.acquire();
        usedObjs.remove(obj);
        freeObjs.add(obj);
        lock.release();
    }

    public function clear( )
    {
        lock.acquire();
        var needs_destroy = after_remove != null ? Lambda.concat(usedObjs, freeObjs) : [];
        freeObjs = new List();
        usedObjs = new List();
        lock.release();

        if (needs_destroy.length > 0) for (obj in needs_destroy)
            after_remove(obj);
    }
}