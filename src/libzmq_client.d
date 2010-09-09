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

	bool isSend = false;

	void function(byte* txt, ulong size, mom_client from_client) message_acceptor;

	this(char* bind_to)
	{
		context = zmq_init(1);
		soc_rep = zmq_socket(context, soc_type.ZMQ_REP);

		Stdout.format("libzmq_client: listen: {}", fromStringz(bind_to)).newline;
		int rc = zmq_bind(soc_rep, bind_to);
		if(rc != 0)
		{
			Stdout.format("error in zmq_bind: {}", fromStringz(zmq_strerror(zmq_errno()))).newline;
			return;
		}

	}

	~this()
	{
		Stdout.format("libzmq_client:destroy").newline;
		zmq_close(soc_rep);
		//		zmq_close(soc_rep);
		zmq_term(context);
	}

	void set_callback(void function(byte* txt, ulong size, mom_client from_client) _message_acceptor)
	{
		message_acceptor = _message_acceptor;
	}

	int send(char* routingkey, char* messagebody, bool send_more)
	{
		zmq_msg_t msg;

		//		Stdout.format("#send").newline;
		int message_size = strlen(messagebody);

		int rc = zmq_msg_init_size(&msg, message_size);
		if(rc != 0)
		{
			Stdout.format("error in zmq_msg_init_size: {}", fromStringz(zmq_strerror(zmq_errno()))).newline;
			return -1;
		}

		memcpy(zmq_msg_data(&msg), messagebody, message_size);

		int send_param = 0;

		if(send_more)
			send_param = send_recv_opt.ZMQ_SNDMORE;

		rc = zmq_send(soc_rep, &msg, send_param);
		if(rc != 0)
		{
			Stdout.format("(error in zmq_send: {}", fromStringz(zmq_strerror(zmq_errno()))).newline;
			return -1;
		}
		isSend = true;

		//		Stdout.format("#send is ok").newline;
		return 0;
	}

	char* get_message()
	{
		return null;
	}

	void listener()
	{
		Stdout.format("start listener").newline;

		while(true)
		{
			zmq_msg_t msg;

			//			Stdout.format("init message").newline;
			int rc = zmq_msg_init(&msg);
			if(rc != 0)
			{
				Stdout.format("error in zmq_msg_init_size: {}", fromStringz(zmq_strerror(zmq_errno()))).newline;
				return;
			}

			//			Stdout.format("wait message").newline;

			if(isSend == false)
			{
				rc = zmq_msg_init_size(&msg, 1);
				if(rc != 0)
				{
					Stdout.format("error in zmq_msg_init_size: {}", fromStringz(zmq_strerror(zmq_errno()))).newline;
					return;
				}

				rc = zmq_send(soc_rep, &msg, 0);
			}

			rc = zmq_recv(soc_rep, &msg, 0);
			if(rc != 0)
			{
				Stdout.format("error in zmq_recv: {}", fromStringz(zmq_strerror(zmq_errno()))).newline;
				return;
			}
			else
			{
				isSend = false;

				byte* data = cast(byte*) zmq_msg_data(&msg);
				int len = strlen(cast(char*) data);
				char* result = null;
				try
				{
					//					Stdout.format("call message acceptor").newline;
					message_acceptor(data, len, this);
					//					Stdout.format("ok").newline;
				} catch(Exception ex)
				{
					//					Stdout.format("exception").newline;
					//					send("", "");
				}
			}
		}
	}

}
