module libczmq_headers;

private import std.stdio;

private import libzmq_headers;

//  Actual list object
alias long int64_t;

struct node_t {
	node_t* next;
	void* item;
}

struct _zlist {
	node_t* head;
	node_t* tail;
	node_t* cursor;
	size_t size;
}

alias _zlist zlist_t;

//  Create a new list container
extern(C)
	zlist_t* zlist_new();

//  Destroy a list container
extern(C)
	void zlist_destroy(zlist_t** self_p);

//  Return first item in the list, or null
extern(C)
	void* zlist_first(zlist_t* self);

//  Return next item in the list, or null
extern(C)
	void* zlist_next(zlist_t* self);

//  Append an item to the end of the list
extern(C)
	void zlist_append(zlist_t* self, void* item);

//  Push an item to the start of the list
extern(C)
	void zlist_push(zlist_t* self, void* item);

//  Pop the item off the start of the list, if any
extern(C)
	void* zlist_pop(zlist_t* self);

//  Remove the specified item from the list if present
extern(C)
	void zlist_remove(zlist_t* self, void* item);

//  Copy the entire list, return the copy
extern(C)
	zlist_t* zlist_copy(zlist_t* self);

//  Return number of items in the list
extern(C)
	size_t zlist_size(zlist_t* self);

//  Self test of this class
extern(C)
	void zlist_test(int verbose);

struct zmsg_t {
	zlist_t* frames; //  List of frames
};

//  Create a new empty message object
extern(C)
	zmsg_t* zmsg_new();

//  Destroy a message object and all frames it contains
extern(C)
	void zmsg_destroy(zmsg_t** self_p);

//  Read 1 or more frames off the socket, into a new message object
extern(C)
	zmsg_t* zmsg_recv(void* socket);

//  Send a message to the socket, and then destroy it
extern(C)
	void zmsg_send(zmsg_t** self_p, void* socket);

//  Return number of frames in message
extern(C)
	size_t zmsg_size(zmsg_t* self);

//  Push frame to front of message, before first frame
extern(C)
	void zmsg_push(zmsg_t* self, zframe_t* frame);

//  Pop frame off front of message, caller now owns frame
extern(C)
	zframe_t* zmsg_pop(zmsg_t* self);

//  Add frame to end of message, after last frame
extern(C)
	void zmsg_add(zmsg_t* self, zframe_t* frame);

//  Push block of memory as new frame to front of message
extern (C) void
    zmsg_pushmem (zmsg_t *self, const void *src, size_t size);

//  Push block of memory as new frame to end of message
extern (C) void
    zmsg_addmem (zmsg_t *self, const void *src, size_t size);

//  Push string as new frame to front of message
extern (C) void
    zmsg_pushstr (zmsg_t *self, const char *string);

//  Push string as new frame to end of message
extern (C) void
   zmsg_addstr (zmsg_t *self, const char *string);

//  Pop frame off front of message, return as fresh string
extern(C)
	char* zmsg_popstr(zmsg_t* self);

//  Push frame to front of message, before first frame
//  Pushes an empty frame in front of frame
extern(C)
	void zmsg_wrap(zmsg_t* self, zframe_t* frame);

//  Pop frame off front of message, caller now owns frame
//  If next frame is empty, pops and destroys that empty frame.
extern(C)
	zframe_t* zmsg_unwrap(zmsg_t* self);

//  Remove frame from message, at any position, caller owns it
extern(C)
	void zmsg_remove(zmsg_t* self, zframe_t* frame);

//  Return first frame in message, or null
extern(C)
	zframe_t* zmsg_first(zmsg_t* self);

//  Return next frame in message, or null
extern(C)
	zframe_t* zmsg_next(zmsg_t* self);

//  Return last frame in message, or null
extern(C)
	zframe_t* zmsg_last(zmsg_t* self);

//  Save message to an open file
extern(C)
	void zmsg_save(zmsg_t* self, FILE* file);

//  Load a message from an open file
extern(C)
	zmsg_t* zmsg_load(FILE* file);

//  Create copy of message, as new message object
extern(C)
	zmsg_t* zmsg_dup(zmsg_t* self);

//  Print message to stderr, for debugging
extern(C)
	void zmsg_dump(zmsg_t* self);

//  Self test of this class
extern(C)
	int zmsg_test(bool verbose);

struct _zframe_t {
	zmq_msg_t zmsg; //  zmq_msg_t blob for frame
	int more; //  More flag, from last read
};

alias _zframe_t zframe_t;

enum czmq {
	ZFRAME_MORE = 1,
	ZFRAME_REUSE = 2
}

//  Create a new frame with optional size, and optional data
extern (C) zframe_t *
   zframe_new (const void *data, size_t size);

//  Destroy a frame
extern(C)
	void zframe_destroy(zframe_t** self_p);

//  Receive a new frame off the socket
extern(C)
	zframe_t* zframe_recv(void* socket);

//  Send a frame to a socket, destroy frame after sending
extern(C)
	void zframe_send(zframe_t** self_p, void* socket, int flags);

//  Return number of bytes in frame data
extern(C)
	size_t zframe_size(zframe_t* self);

//  Return address of frame data
extern(C)
	byte* zframe_data(zframe_t* self);

//  Create a new frame that duplicates an existing frame
extern(C)
	zframe_t* zframe_dup(zframe_t* self);

//  Return frame data encoded as printable hex string
extern(C)
	char* zframe_strhex(zframe_t* self);

//  Return frame data copied into freshly allocated string
extern(C)
	char* zframe_strdup(zframe_t* self);

//  Return TRUE if frame body is equal to string, excluding terminator
extern(C)
	bool zframe_streq(zframe_t* self, char* string);

//  Return frame 'more' property
extern(C)
	int zframe_more(zframe_t* self);

//  Print contents of frame to stderr
extern(C)
	void zframe_print(zframe_t* self, char* prefix);

//  Set new contents for frame
extern (C) void
   zframe_reset (zframe_t *self, const void *data, size_t size);

//  Self test of this class
extern(C)
	int zframe_test(bool verbose);

struct _zctx_t {
	void* context; //  Our 0MQ context
	zlist_t* sockets; //  Sockets held by this thread
	bool main; //  TRUE if we're the main thread
	int iothreads; //  Number of IO threads, default 1
	int linger; //  Linger timeout, default 0
};

alias _zctx_t zctx_t;

extern(C)
	void* zsocket_new(zctx_t* self, int type);

//  Destroy a socket within our czmq context, replaces zmq_close.
extern(C)
	void zsocket_destroy(zctx_t* self, void* socket);

//  Bind a socket to a formatted endpoint
//  Checks with assertion that the bind was valid
extern (C) void
    zsocket_bind (void *socket, const char *format, ...);

//  Connect a socket to a formatted endpoint
//  Checks with assertion that the connect was valid
extern (C) void
    zsocket_connect (void *socket, const char *format, ...);

//  Returns socket type as printable constant string
extern(C)
	char* zsocket_type_str(void* socket);

//  Self test of this class
extern(C)
	int zsocket_test(bool verbose);

extern(C)
	zctx_t* zctx_new();

//  Destroy context and all sockets in it, replaces zmq_term
extern(C)
	void zctx_destroy(zctx_t** self_p);

//  @end
//  Create new shadow context, returns context object
//  For internal use only.
extern(C)
	zctx_t* zctx_shadow(zctx_t* self);

//  @interface
//  Raise default I/O threads from 1, for crazy heavy applications
extern(C)
	void zctx_set_iothreads(zctx_t* self, int iothreads);

//  Set msecs to flush sockets when closing them
extern(C)
	void zctx_set_linger(zctx_t* self, int linger);

//  Create socket within this context, for czmq use only
extern(C)
	void* zctx__socket_new(zctx_t* self, int type);

//  Destroy socket within this context, for czmq use only
extern(C)
	void zctx__socket_destroy(zctx_t* self, void* socket);

//  Self test of this class
extern(C)
	int zctx_test(bool verbose);

//  Global signal indicator, TRUE when user presses Ctrl-C or the process
//  gets a SIGTERM signal.
int zctx_interrupted;

//  Sleep for a number of milliseconds
extern(C)
	void zclock_sleep(int msecs);

//  Return current system clock as milliseconds
extern(C)
	int64_t zclock_time();

//  Print formatted string to stdout, prefixed by date/time and
//  terminated with a newline.
extern (C) void
    zclock_log (const char *format, ...);

//  Self test of this class
extern(C)
	int zclock_test(bool verbose);
