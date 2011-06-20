module zmq_pp_broker_client;

private import std.c.string;
private import std.stdio;
private import core.stdc.stdlib;
private import core.thread;

private import tango.util.uuid.NamespaceGenV5;
private import tango.util.digest.Sha1;
private import tango.util.uuid.RandomGen;
private import tango.math.random.Twister;

private import Log;
private import libzmq_headers;
private import mq_client;

private import libczmq_headers;

private import std.outbuffer;

static int PPP_HEARTBEAT_LIVENESS = 3; //  		3-5 is reasonable
static int PPP_HEARTBEAT_INTERVAL = 1000; //  	msecs
static int PPP_INTERVAL_INIT = 1000; //  		Initial reconnect
static int PPP_INTERVAL_MAX = 32000; //  		After exponential backoff
static string PPP_HEARTBEAT = "H";
static string PPP_READY = "R";

version(D1)
{
	private import std.c.stdlib;

	alias int listener_result;
}

version(D2)
{
	private import core.stdc.stdio;

	alias void listener_result;
}

class zmq_pp_broker_client: mq_client
{
	char[] identity;
	zctx_t* ctx;
	void* worker;

	size_t liveness;
	size_t interval;

	int64_t heartbeat_at;
	char* bind_to;

	void function(byte* txt, int size, mq_client from_client, ref ubyte[] out_data) message_acceptor;

	int count = 0;
	bool isSend = false;

	this(string _bind_to)
	{
		bind_to = cast(char*)(_bind_to ~ "\0");
		printf("worker\n");

		printf("create soc\n");
		ctx = zctx_new();
		worker = s_worker_socket(ctx, bind_to);

		//  If liveness hits zero, queue is considered disconnected
		liveness = PPP_HEARTBEAT_LIVENESS;
		interval = PPP_INTERVAL_INIT;

		//  Send out heartbeats at regular intervals
		heartbeat_at = zclock_time() + PPP_HEARTBEAT_INTERVAL;
	}

	~this()
	{
		zctx_destroy(&ctx);
		printf("zmq_pp_broker_client destroy\n");
	}

	// set callback function for listener ()
	void set_callback(void function(byte* txt, int size, mq_client from_client, ref ubyte[] out_data) _message_acceptor)
	{
		message_acceptor = _message_acceptor;
	}

	void get_count(out int cnt)
	{
		cnt = count;
	}

	// in thread listens to the queue and calls _message_acceptor
	listener_result listener()
	{
		while(1)
		{

			if(zctx_interrupted)
				break;

			zmq_pollitem_t items[] = new zmq_pollitem_t[1];

			//        printf("create soc\n");

			items[0].socket = worker;
			items[0].fd = 0;
			items[0].events = io_multiplexing.ZMQ_POLLIN;
			items[0].revents = 0;

			int rc = zmq_poll(cast(zmq_pollitem_t*) items, 1, PPP_HEARTBEAT_INTERVAL * 1000);
			if(rc == -1)
				break; //  Interrupted

			//        printf("items [0].revents = %d\n", items [0].revents);
			if(items[0].revents & io_multiplexing.ZMQ_POLLIN)
			{
				//  Get message
				//  - 3-part envelope + content -> request
				//  - 1-part "HEARTBEAT" -> heartbeat            
				zmsg_t* msg = zmsg_recv(worker);

				//	    printf("message size=%d\n", zmsg_size (msg));

				if(!msg)
					break; //  Interrupted

				if(zmsg_size(msg) == 3)
				{
					// printf("I: normal reply:");

					zframe_t* frame = zmsg_last(msg);
					byte* msg_body = zframe_data(frame);
					int size = zframe_size(frame);

					isSend = false;
					// обработка принятого сообщения и отправка ответа

//					printf("zmq_pp_broker_client #1\n");
					count++;

					ubyte[] outbuff;

					message_acceptor(msg_body, size, this, outbuff);

//					printf("zmq_pp_broker_client #2\n");

					//					if (isSend == false)
					//					{
					//						возможно потребуется обработка такой ситуации
					//					}

					//					zclock_sleep(50);
					zframe_reset(frame, cast(char*) outbuff, outbuff.length);

					zmsg_send(&msg, worker);
					//		zstr_send (worker, "safsfsd");

					liveness = PPP_HEARTBEAT_LIVENESS;

					//				Thread.getThis().sleep(100_000);

					if(zctx_interrupted)
						break;

				} else if(zmsg_size(msg) == 1)
				{
					zframe_t* frame = zmsg_first(msg);
					char* msg_body = cast(char*) zframe_data(frame);
					//                 printf ("msg_body1 =%s\n", msg_body);
					if(strncmp(msg_body, cast(char*) PPP_HEARTBEAT, PPP_HEARTBEAT.length) == 0)
					{
						liveness = PPP_HEARTBEAT_LIVENESS;
					} else
					{
						printf("E: ( %s invalid message)\n", cast(char*) identity);
						zmsg_dump(msg);
					}
					//? zmsg_destroy (&msg);
				}
				interval = PPP_INTERVAL_INIT;
			} else if(--liveness == 0)
			{
				printf("W: heartbeat failure, can't reach queue\n");
				printf("W: reconnecting in %zd msec...\n", interval);
				Thread.getThis().sleep(interval * 1000);

				if(interval < PPP_INTERVAL_MAX)
				{
					interval *= 2;
				}

				zsocket_destroy(ctx, worker);
				worker = s_worker_socket(ctx, bind_to);
				liveness = PPP_HEARTBEAT_LIVENESS;
			}

			//  Send heartbeat to queue if it's time
			if(zclock_time() > heartbeat_at)
			{
				heartbeat_at = zclock_time() + PPP_HEARTBEAT_INTERVAL;
				//          printf ("I: worker heartbeat\n");
				zframe_t* frame = zframe_new(cast(char*) PPP_HEARTBEAT, PPP_HEARTBEAT.length);
				zframe_send(&frame, worker, 0);
			}

			if(zctx_interrupted)
				break;
		}

		version(D1)
		{
			return 0;
		}

		version(D2)
		{
			return;
		}
	}

	//	 Set simple random printable identity on socket	
	private static char[] s_set_id(void* socket)
	{
		Twister rnd;
		rnd.seed;
		UuidGen rndUuid = new RandomGen!(Twister)(rnd);
		Uuid generated = rndUuid.next;
		char[] id = generated.toString;

		zmq_setsockopt(socket, soc_opt.ZMQ_IDENTITY, id.ptr, id.length);

		return id;
	}

	private void* s_worker_socket(zctx_t* ctx, char* point)
	{
		void* _worker = zsocket_new(ctx, soc_type.ZMQ_DEALER);
		//zmq_socket(context, soc_type.ZMQ_XREQ);

		//  Set random identity to make tracing easier
		identity = s_set_id(_worker);

		printf("connect\n");
		int rc = zmq_connect(_worker, point);
		if(rc != 0)
		{
			printf("error in zmq_connect: %s\n", zmq_strerror(zmq_errno()));
			return null;
		}

		//  Configure socket to not wait at close time
		int linger = 0;
		zmq_setsockopt(_worker, soc_opt.ZMQ_LINGER, &linger, linger.sizeof);

		//  Tell queue we're ready for work
		printf("I: ( %s worker ready) \n", cast(char*) identity);
		zframe_t* frame = zframe_new(cast(char*) PPP_READY, PPP_READY.length);
		zframe_send(&frame, _worker, 0);

		return _worker;
	}

	int send(void* soc_rep, char* messagebody, int message_size, bool send_more)
	{
		return -1;
	}
	
	void* connect_as_req (string connect_to)
	{
		return null;
	}
	
	char* reciev (void* soc)
	{
		return null;
	}
	
}