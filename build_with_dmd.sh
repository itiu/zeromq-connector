date
rm *.a
rm libzmq_client
dmd src/*.d  lib/libzmq.a lib/libstdc++.a lib/libuuid.a
# -oflibzmq.a -lib
rm *.o
date