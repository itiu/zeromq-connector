module zmq_point_to_poin_client;

private import std.c.string;
private import std.stdio;
private import std.outbuffer;

private import libzmq_headers;
private import mq_client;
private import Log;

private import core.stdc.stdio;

alias void listener_result;

Logger log;

static this()
{
	log = new Logger("zmq", "log", null);
}

class zmq_point_to_poin_client: mq_client
{
	int count = 0;

	void* context = null;
	void* soc_rep;

	bool need_resend_msg = false;

	void function(byte* txt, int size, mq_client from_client, ref ubyte[] out_data) message_acceptor;

	void* connect_as_req(string connect_to)
	{
		void* soc = zmq_socket(context, soc_type.ZMQ_REQ);

		int rc = zmq_connect(soc, cast(char*) connect_to);
		if(rc != 0)
		{
			log.trace("error in zmq_connect: %s", zmq_error2string(zmq_errno()));
			return null;
		}

		return soc;
	}

	this(string bind_to)
	{
		context = zmq_init(1);
		soc_rep = zmq_socket(context, soc_type.ZMQ_REP);

		log.trace("libzmq_client: listen from client: %s", bind_to);
		int rc = zmq_bind(soc_rep, cast(char*) (bind_to ~ "\0"));
		if(rc != 0)
		{
			log.trace("error in zmq_bind: %s", zmq_error2string(zmq_errno()));
			throw new Exception("error in zmq_bind: " ~ zmq_error2string(zmq_errno()));
		}
	}

	~this()
	{
		//		log.trace("libzmq_client:destroy\n");

		//		log.trace("libzmq_client:#0\n");
		//		log.trace("libzmq_client:#a\n");
		//		if (soc_rep !is null)
		{
			//		log.trace("libzmq_client:#1\n");
			//		log.trace("libzmq_client:zmq_close, soc_rep=%p\n", soc_rep);
			//		zmq_close(soc_rep);
		}
		//		zmq_close(soc_rep);
		//		log.trace("libzmq_client:zmq_term\n");
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

	int send(void* soc_rep, char* messagebody, int message_size, bool send_more)
	{
		zmq_msg_t msg;

		int rc = zmq_msg_init_size(&msg, message_size);
		if(rc != 0)
		{
			log.trace("error in zmq_msg_init_size: %s", zmq_error2string(zmq_errno()));
			return -1;
		}

		memcpy(zmq_msg_data(&msg), messagebody, message_size);

		int send_param = 0;

		if(send_more)
			send_param = send_recv_opt.ZMQ_SNDMORE;

		rc = zmq_send(soc_rep, &msg, send_param);
		if(rc != 0)
		{
			log.trace("libzmq_client.send:zmq_send: {}\n", zmq_error2string(zmq_errno()));
			return -1;
		}

		need_resend_msg = false; // ответное сообщение было отправлено, снимем флажок о требовании отправки повторного сообщения

		rc = zmq_msg_close(&msg);
		if(rc != 0)
		{
			log.trace("error in zmq_msg_close: %s", zmq_error2string(zmq_errno()));
			return -1;
		}

		return 0;
	}

	string reciev(void* soc)
	{
		string data = null;
		zmq_msg_t msg;
		int rc = zmq_msg_init(&msg);
		if(rc != 0)
		{
			log.trace("error in zmq_msg_init_size: %s", zmq_error2string(zmq_errno()));
			return null;
		}

		rc = zmq_recv(soc, &msg, 0);
		if(rc != 0)
		{
			rc = zmq_msg_close(&msg);
			log.trace("error in zmq_recv: %s", zmq_error2string(zmq_errno()));
			return null;
		} else
		{
			char* res = cast(char*)zmq_msg_data(&msg);
			size_t len = zmq_msg_size(&msg);
			data = cast(string)res[0..len];
		}

		rc = zmq_msg_close(&msg);
		if(rc != 0)
		{
			log.trace("error in zmq_msg_close: %s", zmq_error2string(zmq_errno()));
			return null;
		}

		return data;
	}

	listener_result listener()
	{
		while(true)
		{
			while(true)
			{
				int rc;
				zmq_msg_t msg;

				if(need_resend_msg == true)
				{
					rc = zmq_msg_init_size(&msg, 1);
					if(rc != 0)
					{
						log.trace("error in #1 zmq_msg_init_size: %s", zmq_error2string(zmq_errno()));
						break;
					}

					rc = zmq_send(soc_rep, &msg, 0);
					if(rc != 0)
					{
						log.trace("error in #1 zmq_msg_send: %s", zmq_error2string(zmq_errno()));
						zmq_msg_close(&msg);
						break;
					}

					rc = zmq_msg_close(&msg);
					if(rc != 0)
					{
						log.trace("error in #1 zmq_msg_close: %s", zmq_error2string(zmq_errno()));
						zmq_msg_close(&msg);
						break;
					}
				}

				rc = zmq_msg_init(&msg);
				if(rc != 0)
				{
					log.trace("error in zmq_msg_init_size: %s", zmq_error2string(zmq_errno()));
					zmq_msg_close(&msg);
					break;
				}

				rc = zmq_recv(soc_rep, &msg, 0);
				if(rc != 0)
				{
					log.trace("error in zmq_recv: %s", zmq_error2string(zmq_errno()));
					zmq_msg_close(&msg);
					break;
				} else
				{
					need_resend_msg = true;

					byte* data = cast(byte*) zmq_msg_data(&msg);
					size_t len = zmq_msg_size(&msg);
					char* result = null;
					try
					{
						count++;

						ubyte[] outbuff;

						message_acceptor(data, cast(uint)(len + 1), this, outbuff);

						send(soc_rep, cast(char*) outbuff, cast(uint)outbuff.length, false);
					} catch(Exception ex)
					{
						log.trace("ex! user function callback, %s", ex.msg);
					}
				}

				rc = zmq_msg_close(&msg);
				if(rc != 0)
				{
					log.trace("error in zmq_msg_close: %s", zmq_error2string(zmq_errno()));
				}
			}
		}
	}
}

string fromStringz(char* s)
{
	return cast(immutable) (s ? s[0 .. strlen(s)] : null);
}
