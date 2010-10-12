date
rm *.a
rm libzmq_client

git log -1 --pretty=format:"module myversion; public final static char[] author=\"%an\"; public final static char[] hash=\"%h\";">myversion.d

dmd myversion.d src/Log.d src/libzmq_client.d src/libzmq_headers.d src/mom_client.d lib/libzmq.a lib/libstdc++.a lib/libuuid.a -oflibzmq.a -lib
dmd src/test_recieve.d src/Log.d src/libzmq_client.d src/libzmq_headers.d src/mom_client.d lib/libzmq.a lib/libstdc++.a lib/libuuid.a 
dmd src/test_send.d src/Log.d src/libzmq_client.d src/libzmq_headers.d src/mom_client.d lib/libzmq.a lib/libstdc++.a lib/libuuid.a 
rm *.o
date
