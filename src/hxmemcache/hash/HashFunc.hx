package hxmemcache.hash;

class HashFunc
{
    /**
     * MurmurHash3 was written by Austin Appleby, and is placed in the public domain.
     * The author hereby disclaims copyright to this source code.
     */
    public static function murmur3_32( data : String, seed : Int = 0 ) : Int
    {
        var c1 = 0xcc9e2d51;
        var c2 = 0x1b873593;
    
        var length = data.length;
        var h1 = seed;
        var roundedEnd = (length & 0xfffffffc); //round down to 4 byte block

        var i = 0;
        while (i < roundedEnd)
        {
            // little endian load order
            var k1 =  ((data.charCodeAt(i    ) & 0xff)      )
                    | ((data.charCodeAt(i + 1) & 0xff) <<  8)
                    | ((data.charCodeAt(i + 2) & 0xff) << 16)
                    | ((data.charCodeAt(i + 3)       ) << 24)
            ;

            k1 *= c1;
            k1 = (k1 << 15) | ((k1 & 0xffffffff) >> 17); // ROTL32(k1,15)
            k1 *= c2;
    
            h1 ^= k1;
            h1 = (h1 << 13) | ((h1 & 0xffffffff) >> 19); // ROTL32(h1,13)
            h1 = h1 * 5 + 0xe6546b64;

            i += 4;
        }

        // tail
        var k1 = 0;

        var val = length & 0x03;
        if (val == 3)
            k1 = (data.charCodeAt(roundedEnd + 2) & 0xff) << 16;
    
        // fallthrough
        if (val == 2 || val == 3)
            k1 |= (data.charCodeAt(roundedEnd + 1) & 0xff) << 8;
    
        // fallthrough
        if (val == 1 || val == 2 || val == 3)
        {
            k1 |= data.charCodeAt(roundedEnd) & 0xff;
            k1 *= c1;
            k1 = (k1 << 15) | ((k1 & 0xffffffff) >> 17); // ROTL32(k1,15)
            k1 *= c2;
            h1 ^= k1;
        }
    
        // finalization
        h1 ^= length;
    
        // fmix(h1)
        h1 ^= ((h1 & 0xffffffff) >> 16);
        h1 *= 0x85ebca6b;
        h1 ^= ((h1 & 0xffffffff) >> 13);
        h1 *= 0xc2b2ae35;
        h1 ^= ((h1 & 0xffffffff) >> 16);
        
        return h1 & 0xffffffff;
    }
}