module zmq_point_to_poin_client;

private import Log;
private import libzmq_headers;
private import mq_client;
private import std.c.string;

private import std.outbuffer;

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

class zmq_point_to_poin_client: mq_client
{
	int count = 0;

	void* context = null;
	void* soc_rep;

	bool isSend = false;

	void function(byte* txt, int size, mq_client from_client, ref ubyte[] out_data) message_acceptor;

	this(char* bind_to)
	{
		context = zmq_init(1);
		soc_rep = zmq_socket(context, soc_type.ZMQ_REP);

			printf("libzmq_client: listen from client: %s\n", bind_to);
			int rc = zmq_bind(soc_rep, bind_to);
			if(rc != 0)
			{
				printf("error in zmq_bind: %s\n", zmq_strerror(zmq_errno()));
				throw new Exception ("error in zmq_bind: " ~ fromStringz (zmq_strerror(zmq_errno())));
			}
/*
			printf("libzmq_client: listen from router: %s\n", bind_to);
			int rc = zmq_connect(soc_rep, bind_to);
			if(rc != 0)
			{
				printf("error in zmq_connect: %s\n", zmq_strerror(zmq_errno()));
				return;
			}
*/			
	}

	~this()
	{
		//		printf("libzmq_client:destroy\n");

		//		printf("libzmq_client:#0\n");
		//		printf("libzmq_client:#a\n");
		//		if (soc_rep !is null)
		{
			//		printf("libzmq_client:#1\n");
			//		printf("libzmq_client:zmq_close, soc_rep=%p\n", soc_rep);
			//		zmq_close(soc_rep);
		}
		//		zmq_close(soc_rep);
		//		printf("libzmq_client:zmq_term\n");
		//		zmq_term(context);
	}

	void get_count(out int cnt)
	{
		cnt = count;
	}

	void set_callback(void function(byte* txt, int size, mq_client from_client, ref ubyte[] out_data) _message_acceptor)
	{
		message_acceptor = _message_acceptor;
	}

	int send(char* messagebody, int message_size, bool send_more)
	{                          
		zmq_msg_t msg;

		//		Stdout.format("#send").newline;
//		int message_size = strlen(messagebody);

		int rc = zmq_msg_init_size(&msg, message_size);
		if(rc != 0)
		{
			printf("error in zmq_msg_init_size: %s\n", zmq_strerror(zmq_errno()));
			return -1;
		}

		memcpy(zmq_msg_data(&msg), messagebody, message_size);

		int send_param = 0;

		if(send_more)
			send_param = send_recv_opt.ZMQ_SNDMORE;

		rc = zmq_send(soc_rep, &msg, send_param);
		if(rc != 0)
		{
			printf("libzmq_client.send:zmq_send: {}\n", zmq_strerror(zmq_errno()));
			return -1;
		}
		isSend = true;

		rc = zmq_msg_close(&msg);
		if(rc != 0)
		{
			printf("error in zmq_msg_close: %s\n", zmq_strerror(zmq_errno()));
			return -1;
		}

		//		Stdout.format("#send is ok").newline;
		return 0;
	}

	listener_result listener()
	{

		while(true)
		{
			int rc;
			zmq_msg_t msg;

			if(isSend == false)
			{
				rc = zmq_msg_init_size(&msg, 1);
				if(rc != 0)
				{
					printf("error in zmq_msg_init_size: %s\n", zmq_strerror(zmq_errno()));
					version(D2)
					{
						return;
					}
					version(D1)
					{
						return -1;
					}
				}

				rc = zmq_send(soc_rep, &msg, 0);

				rc = zmq_msg_close(&msg);
				if(rc != 0)
				{
					printf("error in zmq_msg_close: %s\n", zmq_strerror(zmq_errno()));
					version(D2)
					{
						return;
					}
					version(D1)
					{
						return -1;
					}
				}
			}

			rc = zmq_msg_init(&msg);
			if(rc != 0)
			{
				printf("error in zmq_msg_init_size: %s\n", zmq_strerror(zmq_errno()));

				version(D2)
				{
					return;
				}
				version(D1)
				{
					return -1;
				}
			}

			rc = zmq_recv(soc_rep, &msg, 0);
			if(rc != 0)
			{
				printf("error in zmq_recv: %s\n", zmq_strerror(zmq_errno()));
				version(D2)
				{
					return;
				}
				version(D1)
				{
					return -1;
				}
			} else
			{
				isSend = false;

				byte* data = cast(byte*) zmq_msg_data(&msg);
				size_t len = zmq_msg_size(&msg);
				char* result = null;
				try
				{
					count++;
					
					ubyte[] outbuff;
					
					message_acceptor(data, len + 1, this, outbuff);
					
					send(cast (char*)outbuff, outbuff.length, false);					
				} catch(Exception ex)
				{
					//					Stdout.format("exception").newline;
					//					send("", "");
				}
			}

			rc = zmq_msg_close(&msg);
			if(rc != 0)
			{
				printf("error in zmq_msg_close: %s\n", zmq_strerror(zmq_errno()));

				version(D2)
				{
					return;
				}
				version(D1)
				{
					return -1;
				}
			}

		}
	}
}

string fromStringz(char* s)
{
        return cast(immutable) (s ? s[0 .. strlen(s)] : null);
}
        
        