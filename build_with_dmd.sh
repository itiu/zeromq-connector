date
rm *.a

git log -1 --pretty=format:"module myversion; public static char[] author=cast(char[])\"%an\"; public static char[] date=cast(char[])\"%ad\"; public static char[] hash=cast(char[])\"%h\";">myversion.d

#~/dmd/linux/bin/dmd -version=D1 myversion.d src/Log.d src/zmq_pp_broker_client.d src/zmq_point_to_poin_client.d src/libzmq_headers.d src/mq_client.d lib/libzmq.a lib/libstdc++.a lib/libuuid.a -oflibzmq-D1.a -lib
~/dmd2/linux/bin/dmd -version=D2 myversion.d src/Log.d src/zmq_pp_broker_client.d src/zmq_point_to_poin_client.d src/libzmq_headers.d src/mq_client.d src/libczmq_headers.d src/tango/util/uuid/*.d  src/tango/core/*.d src/tango/text/convert/*.d src/tango/util/digest/*.d src/tango/math/random/*.d lib/libzmq.a lib/libstdc++.a lib/libczmq.a lib/libuuid.a -oflibzmq-D2.a -lib


#~/dmd/linux/bin/dmd -version=D1 src/test_recieve.d src/Log.d src/zmq_point_to_poin_client.d src/libzmq_headers.d src/mq_client.d lib/libzmq.a lib/libstdc++.a lib/libuuid.a 
#~/dmd/linux/bin/dmd -version=D1 src/test_send.d src/Log.d src/zmq_point_to_poin_client.d src/libzmq_headers.d src/mq_client.d lib/libzmq.a lib/libstdc++.a lib/libuuid.a 
rm *.o
date
