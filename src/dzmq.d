module dzmq;

private import libzmq_headers;
private import std.c.stdlib;
private import std.c.string;
//private import std.c.stdio;
//private import std.stdarg;
private import core.vararg;
private import std.datetime;
private import std.stdio;

const int ZSOCKET_DYNFROM = 0xc000;
const int ZSOCKET_DYNTO = 0xffff;

alias long int64_t;

version(Win32)
{
	import core.sys.windows.windows;
}

enum
{
	ZFRAME_MORE = 1,
	ZFRAME_REUSE = 2
}

version(Posix)
{
	private import core.sys.posix.sys.time;
}

struct node_t
{
	node_t* next = null;
	void* item = null;
};

//////////////////////////////////////////////////////////////////////////////////////////////////////////

//  Actual list object

struct zlist_t
{
	node_t* head = null;
	node_t* tail = null;
	node_t* cursor = null;
	size_t size = 0;
};

//--------------------------------------------------------------------------
//List constructor

zlist_t* zlist_new()
{
	zlist_t* self = cast(zlist_t*) malloc(zlist_t.sizeof);
	count_zlist_malloc ++;
//	zlist_t* self = new zlist_t;
	self.head = null;
	self.tail = null;
	self.cursor = null;
	self.size = 0;
	
	return self;
}

//  --------------------------------------------------------------------------
//Insert item at the beginning of the list

void zlist_push(zlist_t* self, void* item)
{
	node_t* node;
	node = cast(node_t*) malloc(node_t.sizeof);
	count_node_malloc ++;
	
//	node = new node_t;
	node.item = item;
	node.next = self.head;
	self.head = node;
	if(self.tail == null)
		self.tail = node;
	self.size++;
	self.cursor = null;
}

//--------------------------------------------------------------------------
//Remove item from the beginning of the list, returns NULL if none

void* zlist_pop(zlist_t* self)
{
	node_t* node = self.head;
	void* item = null;
	if(node)
	{
		item = node.item;
		self.head = node.next;
		if(self.tail == node)
			self.tail = null;
		free(node);
		count_node_malloc--;
		self.size--;
	}
	self.cursor = null;
	return item;
}

//--------------------------------------------------------------------------
//List destructor

void zlist_destroy(zlist_t** self_p)
{
	assert(self_p);
	if(*self_p)
	{
		zlist_t* self = *self_p;
		node_t* node;
		node_t* next;
		for(node = (*self_p).head; node != null; node = next)
		{
			next = node.next;
			free(node);
		count_node_malloc --;
			
		}
		free(self);
		count_zlist_malloc --;
		
		*self_p = null;
	}
}

//--------------------------------------------------------------------------
//Add item to the end of the list

void zlist_append(zlist_t* self, void* item)
{
	node_t* node;
	node = cast(node_t*) malloc(node_t.sizeof);
	count_node_malloc ++;
	
//	node = new node_t;
	node.item = item;
	if(self.tail)
		self.tail.next = node;
	else
		self.head = node;
	self.tail = node;
	node.next = null;
	self.size++;
	self.cursor = null;
}

//--------------------------------------------------------------------------
//Return the item at the head of list. If the list is empty, returns NULL.
//Leaves cursor pointing at the head item, or NULL if the list is empty.

void* zlist_first(zlist_t* self)
{
	assert(self);
	self.cursor = self.head;
	if(self.cursor)
		return self.cursor.item;
	else
		return null;
}

//--------------------------------------------------------------------------
//Return the next item. If the list is empty, returns NULL. To move to
//the start of the list call zlist_first(). Advances the cursor.

void* zlist_next(zlist_t* self)
{
	assert(self);
	if(self.cursor)
		self.cursor = self.cursor.next;
	else
		self.cursor = self.head;
	if(self.cursor)
		return self.cursor.item;
	else
		return null;
}

//--------------------------------------------------------------------------
//Remove the item from the list, if present. Safe to call on items that
//are not in the list.

void zlist_remove(zlist_t* self, void* item)
{
	node_t* node;
	node_t* prev = null;

	//  First off, we need to find the list node.
	for(node = self.head; node != null; node = node.next)
	{
		if(node.item == item)
			break;
		prev = node;
	}
	if(node)
	{
		if(prev)
			prev.next = node.next;
		else
			self.head = node.next;

		if(node.next == null)
			self.tail = prev;

		free(node);
		count_node_malloc--;
		
		self.size--;
		self.cursor = null;
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////

struct zmsg_t
{
	zlist_t* frames = null; //  List of frames
	size_t content_size = 0; //  Total content size
};

struct zctx_t
{
	void* context = null; //  Our 0MQ context
	zlist_t* sockets = null; //  Sockets held by this thread
	bool main = false; //  TRUE if we're the main thread
	int iothreads = 0; //  Number of IO threads, default 1
	int linger = 0; //  Linger timeout, default 0
};

///////////////////////////////////////////////////////////////////////////////////////////////////////////

struct zframe_t
{
	zmq_msg_t zmsg; //  zmq_msg_t blob for frame
	int more = 0; //  More flag, from last read
};

//  --------------------------------------------------------------------------
//  Set new contents for frame

void zframe_reset (zframe_t *self, void *data, size_t size)
{
    assert (self);
    assert (data);
    zmq_msg_close (&self.zmsg);
    zmq_msg_init_size (&self.zmsg, size);
    memcpy (zmq_msg_data (&self.zmsg), data, size);
}

//--------------------------------------------------------------------------
//Return size of frame.
size_t zframe_size(zframe_t* self)
{
	assert(self);
	return zmq_msg_size(&self.zmsg);
}

//--------------------------------------------------------------------------
//Destructor
void zframe_destroy(zframe_t** self_p)
{
	assert(self_p);
	if(*self_p)
	{
		zframe_t* self = *self_p;
		zmq_msg_close(&self.zmsg);
		free(self);
		count_zframe_malloc --;
		
		*self_p = null;
	}
}

//--------------------------------------------------------------------------
//Return pointer to frame data.
byte* zframe_data(zframe_t* self)
{
	assert(self);
	return cast(byte*) zmq_msg_data(&self.zmsg);
}

//--------------------------------------------------------------------------
//Create a new frame that duplicates an existing frame
string zframe_strdup(zframe_t* self)
{
	size_t size = zframe_size(self);
	char[] str = new char[size + 1];
	memcpy(cast(char*)str, zframe_data(self), size);
	str[size] = 0;
	return cast(immutable)str;
}

//--------------------------------------------------------------------------
//Receive frame from socket, returns zframe_t object or NULL if the recv
//was interrupted. Does a blocking recv, if you want to not block then use
//zframe_recv_nowait().

zframe_t* zframe_recv(void* socket)
{
	assert(socket);
	zframe_t* self = zframe_new(null, 0);
	if(zmq_recv(socket, &self.zmsg, 0) < 0)
	{
		zframe_destroy(&self);
		return null; //  Interrupted or terminated
	}
	self.more = zsockopt_rcvmore(socket);
	return self;
}

//--------------------------------------------------------------------------
//Return frame MORE indicator (1 or 0), set when reading frame from socket

int zframe_more(zframe_t* self)
{
	assert(self);
	return self.more;
}

//--------------------------------------------------------------------------
//Constructor; if size is >0, allocates frame with that size, and if data
//is not null, copies data into frame.

zframe_t* zframe_new(void* data, size_t size)
{
	zframe_t* self;

	self = cast(zframe_t*) malloc(zframe_t.sizeof);
	count_zframe_malloc ++;
	
	self.more = 0;
//	self = new zframe_t;
	if(size)
	{
		zmq_msg_init_size(&self.zmsg, size);
		if(data)
			memcpy(zmq_msg_data(&self.zmsg), data, size);
	} else
		zmq_msg_init(&self.zmsg);

	return self;
}

//--------------------------------------------------------------------------
//Send frame to socket, destroy after sending unless ZFRAME_REUSE is set.

void zframe_send(zframe_t** self_p, void* socket, int flags)
{
	assert(socket);
	assert(self_p);
	if(*self_p)
	{
		zframe_t* self = *self_p;
		if(flags & dzmq.ZFRAME_REUSE)
		{
			zmq_msg_t copy;
			zmq_msg_init(&copy);
			zmq_msg_copy(&copy, &self.zmsg);
			zmq_send(socket, &copy, (flags & dzmq.ZFRAME_MORE) ? send_recv_opt.ZMQ_SNDMORE : 0);
			zmq_msg_close(&copy);
		} else
		{
			zmq_send(socket, &self.zmsg, (flags & dzmq.ZFRAME_MORE) ? send_recv_opt.ZMQ_SNDMORE : 0);
			zframe_destroy(self_p);
		}
	}
}

//--------------------------------------------------------------------------
//Print contents of frame to stderr, prefix is ignored if null.

void zframe_print(zframe_t* self, string prefix)
{
	assert(self);
	if(prefix)
		printf("%s", prefix);
	byte* data = zframe_data(self);
	size_t size = zframe_size(self);

	int is_bin = 0;
	uint char_nbr;
	for(char_nbr = 0; char_nbr < size; char_nbr++)
		if(data[char_nbr] < 9 || data[char_nbr] > 127)
			is_bin = 1;

	printf("[%03d] ", cast(int) size);
	size_t max_size = is_bin ? 35 : 70;
	string elipsis = "";
	if(size > max_size)
	{
		size = max_size;
		elipsis = "...";
	}
	for(char_nbr = 0; char_nbr < size; char_nbr++)
	{
		if(is_bin)
			printf("%02X", cast(char) data[char_nbr]);
		else
			printf("%c", data[char_nbr]);
	}
	printf("%s\n", elipsis);
}

/////////////////////////////////////////////////////////////////////////////////////////////////

ulong zclock_time()
{
	SysTime now = Clock.currTime();		
	return now.stdTime;
}

zctx_t* zctx_new()
{
	zctx_t* self;

	self = cast(zctx_t*) malloc(zctx_t.sizeof);
	count_zctx_malloc ++;
	
//	self = new zctx_t;
	self.sockets = zlist_new();
	self.iothreads = 1;
	self.main = true;
	self.context = null;

	/*    
	 #if defined (__UNIX__)
	 //  Install signal handler for SIGINT and SIGTERM
	 struct sigaction action;
	 action.sa_handler = s_signal_handler;
	 action.sa_flags = 0;
	 sigemptyset (&action.sa_mask);
	 sigaction (SIGINT, &action, NULL);
	 sigaction (SIGTERM, &action, NULL);
	 #endif
	 */
	return self;
}

//--------------------------------------------------------------------------
//Create a new socket within our czmq context, replaces zmq_socket.
//If the socket is a SUB socket, automatically subscribes to everything.
//Use this to get automatic management of the socket at shutdown.

void* zsocket_new(zctx_t* ctx, int type)
{
	void* socket = zctx__socket_new(ctx, type);
	//	if(type == soc_type.ZMQ_SUB)
	//		zsockopt_set_subscribe(socket, "");
	return socket;
}

//--------------------------------------------------------------------------
//Create socket within this context, for CZMQ use only

void* zctx__socket_new(zctx_t* self, int type)
{
//	void* context = zmq_init(1);
//	void* soc_worker = zmq_socket(context, soc_type.ZMQ_DEALER);
	
	assert(self);
	//  Initialize context now if necessary
	if(self.context == null)
		self.context = zmq_init(self.iothreads);
	assert(self.context);
	//  Create and register socket
	void* socket = zmq_socket(self.context, type);
	if(socket)
	{
		assert(socket);
		zlist_push(self.sockets, socket);
	}
	return socket;
}


//--------------------------------------------------------------------------
//Bind a socket to a formatted endpoint. If the port is specified as
//'*', binds to any free port from ZSOCKET_DYNFROM to ZSOCKET_DYNTO
//and returns the actual port number used. Otherwise asserts that the
//bind succeeded with the specified port number. Always returns the
//port number if successful.

int zsocket_bind(void* socket, string format, ...)
{
	//  Ephemeral port needs 4 additional characters
	char endpoint[256 + 4];
	va_list argptr;
	va_start(argptr, format);
	int endpoint_size = vsnprintf(cast(char*) endpoint, 256, cast(char*) format, argptr);
	va_end(argptr);

	//  Port must be at end of endpoint
	int rc = 0;
	if(endpoint[endpoint_size - 2] == ':' && endpoint[endpoint_size - 1] == '*')
	{
		rc = -1; //  Unless successful
		int port;
		for(port = ZSOCKET_DYNFROM; port < ZSOCKET_DYNTO; port++)
		{
			sprintf(cast(char*) endpoint + endpoint_size - 1, "%d", port);
			if(zmq_bind(socket, cast(char*) endpoint) == 0)
			{
				rc = port;
				break;
			}
		}
	} else
	{
		rc = zmq_bind(socket, cast(char*) endpoint);
		assert(rc == 0);
		//  Return actual port used for binding
		rc = atoi(strrchr(cast(char*) endpoint, ':') + 1);
	}
	return rc;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////
//--------------------------------------------------------------------------
//Constructor

zmsg_t* zmsg_new()
{
	zmsg_t* self;

	self = cast(zmsg_t*) malloc(zmsg_t.sizeof);
	count_zmsg_malloc ++;
	
	self.content_size = 0;
//	self = new zmsg_t;
	self.frames = zlist_new();
	return self;
}


//--------------------------------------------------------------------------
//Destructor

void zmsg_destroy(zmsg_t** self_p)
{
	count_zmsg_destroy ++;
	
	assert(self_p);
	if(*self_p)
	{
		zmsg_t* self = *self_p;
		while(self.frames.size > 0)
		{
			zframe_t* frame = cast(zframe_t*) zlist_pop(self.frames);
			zframe_destroy(&frame);
		}
		zlist_destroy(&self.frames);
		free(self);
		count_zmsg_malloc --;
		
		*self_p = null;
	}
}


//  --------------------------------------------------------------------------
//  Create copy of message, as new message object

zmsg_t *zmsg_dup (zmsg_t *self)
{
    assert (self);
    zmsg_t *copy = zmsg_new ();
    zframe_t *frame = zmsg_first (self);
    while (frame) {
        zmsg_addmem (copy, zframe_data (frame), zframe_size (frame));
        frame = zmsg_next (self);
    }
    return copy;
}

//  --------------------------------------------------------------------------
//  Add block of memory to the end of the message, as a new frame.

void zmsg_addmem (zmsg_t *self, void *src, size_t size)
{
    assert (self);
    zframe_t *frame = zframe_new (src, size);
    self.content_size += size;
    zlist_append (self.frames, frame);
}


//--------------------------------------------------------------------------
//Receive message from socket, returns zmsg_t object or NULL if the recv
//was interrupted. Does a blocking recv, if you want to not block then use
//the zloop class or zmq_poll to check for socket input before receiving.

zmsg_t* zmsg_recv(void* socket)
{
	count_zmsg_recv ++;
	assert(socket);
	zmsg_t* self = zmsg_new();
	
	while(1)
	{
		zframe_t* frame = zframe_recv(socket);
		if(!frame)
		{
			zmsg_destroy(&self);
			break; //  Interrupted or terminated
		}
		zmsg_add(self, frame);
		if(!zframe_more(frame))
			break; //  Last message frame
	}
	return self;
}

//--------------------------------------------------------------------------
//Add frame to the end of the message, i.e. after all other frames.
//Message takes ownership of frame, will destroy it when message is sent.

void zmsg_add(zmsg_t* self, zframe_t* frame)
{
	assert(self);
	assert(frame);
	self.content_size += zframe_size(frame);
	zlist_append(self.frames, frame);
}



//--------------------------------------------------------------------------
//Pop frame off front of message, caller now owns frame
//If next frame is empty, pops and destroys that empty frame.

zframe_t* zmsg_unwrap(zmsg_t* self)
{
	assert(self);
	zframe_t* frame = zmsg_pop(self);
	zframe_t* empty = zmsg_first(self);
	if(zframe_size(empty) == 0)
	{
		empty = zmsg_pop(self);
		zframe_destroy(&empty);
	}
	return frame;
}

//--------------------------------------------------------------------------
//Remove first frame from message, if any. Returns frame, or NULL. Caller
//now owns frame and must destroy it when finished with it.

zframe_t* zmsg_pop(zmsg_t* self)
{
	assert(self);
	zframe_t* frame = cast(zframe_t*) zlist_pop(self.frames);
	if(frame)
		self.content_size -= zframe_size(frame);
	return frame;
}

//--------------------------------------------------------------------------
//Set cursor to first frame in message. Returns frame, or NULL.

zframe_t* zmsg_first(zmsg_t* self)
{
	assert(self);
	return cast(zframe_t*) zlist_first(self.frames);
}

//--------------------------------------------------------------------------
//Return size of message, i.e. number of frames (0 or more).

size_t zmsg_size(zmsg_t* self)
{
	assert(self);
	return self.frames.size;
}

//--------------------------------------------------------------------------
//Dump message to stderr, for debugging and tracing
//Prints first 10 frames, for larger messages

void zmsg_dump(zmsg_t* self)
{
	writeln ("--------------------------------------");
	if(!self)
	{
		writeln("NULL");
		return;
	}
	zframe_t* frame = zmsg_first(self);
	int frame_nbr = 0;
	while(frame && frame_nbr++ < 10)
	{
		zframe_print(frame, "");
		frame = zmsg_next(self);
	}
}

//--------------------------------------------------------------------------
//Send message to socket, destroy after sending. If the message has no
//frames, sends nothing but destroys the message anyhow. Safe to call
//if zmsg is null.

void zmsg_send(zmsg_t** self_p, void* socket)
{
	count_zmsg_send ++;
	assert(self_p);
	assert(socket);
	zmsg_t* self = *self_p;

	if(self)
	{
		zframe_t* frame = cast(zframe_t*) zlist_pop(self.frames);
		while(frame)
		{
			zframe_send(&frame, socket, self.frames.size ? dzmq.ZFRAME_MORE : 0);
			frame = cast(zframe_t*) zlist_pop(self.frames);
		}
		zmsg_destroy(self_p);
	}
}

//--------------------------------------------------------------------------
//Return the next frame. If there are no more frames, returns NULL. To move
//to the first frame call zmsg_first(). Advances the cursor.

zframe_t* zmsg_next(zmsg_t* self)
{
	assert(self);
	return cast(zframe_t*) zlist_next(self.frames);
}


//--------------------------------------------------------------------------
//Push frame to the front of the message, i.e. before all other frames.
//Message takes ownership of frame, will destroy it when message is sent.

void zmsg_push(zmsg_t* self, zframe_t* frame)
{
	assert(self);
	assert(frame);
	self.content_size += zframe_size(frame);
	zlist_push(self.frames, cast(void*) frame);
}

//  --------------------------------------------------------------------------
//  Return the last frame. If there are no frames, returns NULL.

zframe_t *zmsg_last (zmsg_t *self)
{
    assert (self);
    zframe_t *frame = cast(zframe_t *) zlist_first (self.frames);
    while (frame) {
        zframe_t *next = cast(zframe_t *) zlist_next (self.frames);
        if (!next)
            break;
        frame = next;
    }
    return frame;
}

/////////////////////////////////////////////////////////////////////////////////////////////////

//--------------------------------------------------------------------------
//Destructor

void zctx_destroy(zctx_t** self_p)
{
	assert(self_p);
	if(*self_p)
	{
		zctx_t* self = *self_p;
		while(self.sockets.size)
			zctx__socket_destroy(self, zlist_first(self.sockets));
		zlist_destroy(&self.sockets);
		if(self.main && self.context)
			zmq_term(self.context);
		free(self);
		count_zctx_malloc --;
		
		*self_p = null;
	}
}

//--------------------------------------------------------------------------
//Destroy socket within this context, for CZMQ use only

void zctx__socket_destroy(zctx_t* self, void* socket)
{
	assert(self);
	assert(socket);
	zsockopt_set_linger(socket, self.linger);
	zmq_close(socket);
	zlist_remove(self.sockets, socket);
}

//--------------------------------------------------------------------------
//Set socket ZMQ_LINGER value

void zsockopt_set_linger(void* socket, int linger)
{
	int rc = zmq_setsockopt(socket, soc_opt.ZMQ_LINGER, &linger, int.sizeof);
	assert(rc == 0); // || errno == ETERM);
}


//  --------------------------------------------------------------------------
//  Destroy the socket. You must use this for any socket created via the
//  zsocket_new method.

void zsocket_destroy (zctx_t *ctx, void *socket)
{
    zctx__socket_destroy (ctx, socket);
}

//--------------------------------------------------------------------------
//Return socket ZMQ_RCVMORE value
int zsockopt_rcvmore(void* socket)
{
	int64_t rcvmore;
	size_t type_size = int64_t.sizeof;
	zmq_getsockopt(socket, soc_opt.ZMQ_RCVMORE, &rcvmore, &type_size);
	return cast(int) rcvmore;
}

static void print_data_from_frame (string txt, zframe_t* address)
{
	if (address !is null)
	{
		int size = cast(uint)zframe_size(address);

		if (size > 0)
		{
			char[] addr = new char[size + 1];
			strncpy (cast(char*)addr, cast(char*)zframe_data(address), size);

			printf ("%s %s\n", cast(char*)txt, cast (char*)addr);
		}
	}
}	

long count_zctx_malloc = 0;
long count_zframe_malloc = 0;
long count_zlist_malloc = 0;
long count_zmsg_malloc = 0;
long count_node_malloc = 0;
long count_zmsg_recv = 0;
long count_zmsg_send = 0;
long count_zmsg_destroy = 0;


