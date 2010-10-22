date
rm *.a
rm libzmq_client

git log -1 --pretty=format:"module myversion; public static char[] author=cast(char[])\"%an\"; public static char[] date=cast(char[])\"%ad\"; public static char[] hash=cast(char[])\"%h\";">myversion.d

~/dmd/linux/bin/dmd -version=D1 myversion.d src/Log.d src/libzmq_client.d src/libzmq_headers.d src/mom_client.d lib/libzmq.a lib/libstdc++.a lib/libuuid.a -oflibzmq-D1.a -lib
~/dmd2/linux/bin/dmd -version=D2 myversion.d src/Log.d src/libzmq_client.d src/libzmq_headers.d src/mom_client.d lib/libzmq.a lib/libstdc++.a lib/libuuid.a -oflibzmq-D2.a -lib


~/dmd/linux/bin/dmd -version=D1 src/test_recieve.d src/Log.d src/libzmq_client.d src/libzmq_headers.d src/mom_client.d lib/libzmq.a lib/libstdc++.a lib/libuuid.a 
~/dmd/linux/bin/dmd -version=D1 src/test_send.d src/Log.d src/libzmq_client.d src/libzmq_headers.d src/mom_client.d lib/libzmq.a lib/libstdc++.a lib/libuuid.a 
rm *.o
date
