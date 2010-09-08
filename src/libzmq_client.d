module libzmq_client;

private import tango.io.Stdout;
private import mom_client;
private import Log;
private import tango.core.Thread;
private import libzmq_headers;
private import tango.stdc.stringz;
private import tango.stdc.string;
private import tango.stdc.stdlib;

class libzmq_client: mom_client
{
	void* context = null;
	//	void* soc_rep;
	void* soc_rep;

	char* function(byte* txt, ulong size, mom_client from_client) message_acceptor;

	this(char* bind_to)
	{
		Stdout.format("#new #1").newline;
		context = zmq_init(1);
		soc_rep = zmq_socket(context, soc_type.ZMQ_REP);

		Stdout.format("#2 listen: {}", fromStringz(bind_to)).newline;
		int rc = zmq_bind(soc_rep, bind_to);
		if(rc != 0)
		{
			Stdout.format("error in zmq_bind: {}", fromStringz(zmq_strerror(zmq_errno()))).newline;
			return;
		}

	}

	~this()
	{
		Stdout.format("#~").newline;
		zmq_close(soc_rep);
		//		zmq_close(soc_rep);
		zmq_term(context);
		Stdout.format("#~..").newline;
	}

	void set_callback(char* function(byte* txt, ulong size, mom_client from_client) _message_acceptor)
	{
		message_acceptor = _message_acceptor;
	}

	int send(char* routingkey, char* messagebody)
	{
		zmq_msg_t msg;
		//		Stdout.format("#new .. res_req={}", res_rep).newline;
		int message_size = strlen(messagebody);

		int rc = zmq_msg_init_size(&msg, message_size);
		if(rc != 0)
		{
			Stdout.format("error in zmq_msg_init_size: {}", fromStringz(zmq_strerror(zmq_errno()))).newline;
			return -1;
		}

		memcpy(zmq_msg_data(&msg), messagebody, message_size);

		rc = zmq_send(soc_rep, &msg, 0);
		if(rc != 0)
		{
			Stdout.format("(error in zmq_send: {}", fromStringz(zmq_strerror(zmq_errno()))).newline;
			return -1;
		}
		return 0;
	}

	char* get_message()
	{
		return null;
	}

	void listener()
	{
		while(true)
		{
			zmq_msg_t msg;
			Stdout.format("start listener").newline;

			int rc = zmq_msg_init_size(&msg, 30);
			if(rc != 0)
			{
				Stdout.format("error in zmq_msg_init_size: {}", fromStringz(zmq_strerror(zmq_errno()))).newline;
				return;
			}

			Stdout.format("wait message").newline;
			rc = zmq_recv(soc_rep, &msg, 0);
			if(rc != 0)
			{
				Stdout.format("error in zmq_recv: {}", fromStringz(zmq_strerror(zmq_errno()))).newline;
				return;
			} else
			{
				byte* data = cast(byte*) zmq_msg_data(&msg);
				char* result = null;
				try
				{
				message_acceptor(data, strlen(cast(char*) data), this);
				}
				catch (Exception ex)
				{
					
				}
			    send ("", result);
			}
		}
	}

}

